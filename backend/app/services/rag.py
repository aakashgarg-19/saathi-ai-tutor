"""Curriculum-grounded doubt answering.

Flow: idempotency check -> answer cache -> vector retrieval (scoped to one chapter) ->
grounded prompt -> streamed LLM answer -> persist + notify teacher dashboards.
"""

import hashlib
import re
from collections.abc import AsyncIterator
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai import get_embedder, get_llm
from app.config import get_settings
from app.models import Chapter, Chunk, ClassroomMember, Doubt, User
from app.schemas import AskIn, SourceOut
from app.services.realtime import hub

LANGUAGE_NAMES = {"en": "English", "hi": "Hindi"}
MAX_CONCEPTS_PER_DOUBT = 2

SYSTEM_PROMPT = """You are Saathi, a patient tutor for Indian school students (Classes 6-10).
Rules:
- Answer ONLY from the textbook excerpts provided. If they do not contain the answer, say so \
kindly in one sentence and suggest asking the teacher. Never invent facts.
- Use simple words a 12-year-old understands. 3 to 6 short sentences.
- Where it helps, add one everyday Indian example (kitchen, farm, cricket, monsoon...).
- Cite the excerpts you used inline, like [S1] or [S2].
- Reply in the requested answer language. When answering in Hindi, write in Devanagari and \
keep key scientific terms in English in brackets, e.g. प्रकाश संश्लेषण (photosynthesis).
- Plain text only; **bold** for key terms is fine, no headings or tables."""


@dataclass
class Retrieved:
    chunk: Chunk
    distance: float

    @property
    def excerpt(self) -> str:
        return self.chunk.text if len(self.chunk.text) <= 240 else self.chunk.text[:237] + "..."


def normalise_question(question: str) -> str:
    return " ".join(re.findall(r"[\wऀ-ॿ]+", question.lower()))


def cache_key(chapter_id: int, language: str, question: str) -> str:
    raw = f"{chapter_id}|{language}|{normalise_question(question)}"
    return hashlib.sha256(raw.encode()).hexdigest()


async def retrieve(session: AsyncSession, chapter_id: int, question: str) -> list[Retrieved]:
    settings = get_settings()
    embedder = get_embedder()
    max_distance = settings.retrieval_max_distance or embedder.default_max_distance
    [query_vec] = await embedder.embed([question], is_query=True)
    distance = Chunk.embedding.cosine_distance(query_vec).label("distance")
    rows = await session.execute(
        select(Chunk, distance)
        .where(Chunk.chapter_id == chapter_id)
        .order_by(distance)
        .limit(settings.retrieval_top_k)
    )
    return [Retrieved(chunk, d) for chunk, d in rows if d <= max_distance]


def build_prompt(question: str, language: str, retrieved: list[Retrieved]) -> str:
    context = (
        "\n".join(
            f"[S{i}] ({r.chunk.concept})\n{r.chunk.text}" for i, r in enumerate(retrieved, start=1)
        )
        or "(no relevant excerpts found)"
    )
    return (
        f"Answer language: {LANGUAGE_NAMES[language]}\n\n"
        f"Textbook excerpts:\n{context}\n---\n"
        f"Student's question: {question}"
    )


def to_sources(retrieved: list[Retrieved]) -> list[SourceOut]:
    return [
        SourceOut(
            ref=f"S{i}",
            chunk_id=r.chunk.id,
            concept=r.chunk.concept,
            excerpt=r.excerpt,
            page=r.chunk.page,
        )
        for i, r in enumerate(retrieved, start=1)
    ]


async def sources_for(session: AsyncSession, chunk_ids: list[int]) -> list[SourceOut]:
    if not chunk_ids:
        return []
    chunks = {c.id: c for c in await session.scalars(select(Chunk).where(Chunk.id.in_(chunk_ids)))}
    return to_sources([Retrieved(chunks[cid], 0) for cid in chunk_ids if cid in chunks])


async def _notify_classrooms(session: AsyncSession, student: User, doubt: Doubt) -> None:
    classroom_ids = await session.scalars(
        select(ClassroomMember.classroom_id).where(ClassroomMember.student_id == student.id)
    )
    await hub.publish(
        list(classroom_ids),
        {
            "type": "doubt_created",
            "student_name": student.name,
            "question": doubt.question,
            "concepts": doubt.concepts,
            "created_at": doubt.created_at.isoformat(),
        },
    )


async def answer_doubt(
    session: AsyncSession, student: User, chapter: Chapter, req: AskIn
) -> AsyncIterator[tuple[str, dict]]:
    """Yield ("sources", ...), then ("token", ...)*, then ("done", ...) events."""
    if req.client_id:
        existing = await session.scalar(
            select(Doubt).where(Doubt.student_id == student.id, Doubt.client_id == req.client_id)
        )
        if existing:
            sources = await sources_for(session, existing.source_chunk_ids)
            yield "sources", {"sources": [s.model_dump() for s in sources]}
            yield "token", {"text": existing.answer}
            yield (
                "done",
                {
                    "doubt_id": existing.id,
                    "concepts": existing.concepts,
                    "from_cache": existing.from_cache,
                },
            )
            return

    key = cache_key(chapter.id, req.language, req.question)
    cached = await session.scalar(
        select(Doubt)
        .where(Doubt.cache_key == key, Doubt.answer != "", Doubt.helpful.is_not(False))
        .order_by(Doubt.created_at.desc())
        .limit(1)
    )

    if cached:
        answer, concepts, chunk_ids = cached.answer, cached.concepts, cached.source_chunk_ids
        sources = await sources_for(session, chunk_ids)
        yield "sources", {"sources": [s.model_dump() for s in sources]}
        yield "token", {"text": answer}
    else:
        retrieved = await retrieve(session, chapter.id, req.question)
        sources = to_sources(retrieved)
        yield "sources", {"sources": [s.model_dump() for s in sources]}
        parts: list[str] = []
        async for delta in get_llm().stream(
            SYSTEM_PROMPT, build_prompt(req.question, req.language, retrieved)
        ):
            parts.append(delta)
            yield "token", {"text": delta}
        answer = "".join(parts).strip()
        # Concept attribution comes from the retrieved chunks' section tags: zero extra cost.
        concepts = list(dict.fromkeys(r.chunk.concept for r in retrieved))[:MAX_CONCEPTS_PER_DOUBT]
        chunk_ids = [r.chunk.id for r in retrieved]

    doubt = Doubt(
        student_id=student.id,
        chapter_id=chapter.id,
        question=req.question.strip(),
        language=req.language,
        answer=answer,
        concepts=concepts,
        source_chunk_ids=chunk_ids,
        client_id=req.client_id,
        cache_key=key,
        from_cache=cached is not None,
    )
    session.add(doubt)
    await session.commit()
    await _notify_classrooms(session, student, doubt)
    yield "done", {"doubt_id": doubt.id, "concepts": concepts, "from_cache": doubt.from_cache}
