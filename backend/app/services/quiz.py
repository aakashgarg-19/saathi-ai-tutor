"""Generate remedial quizzes that target what this class is actually confused about."""

import json
import logging
from datetime import UTC, datetime, timedelta

from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai import AIError, get_llm
from app.models import Chapter, Chunk, Classroom, Quiz
from app.schemas import QuizGenerateIn, QuizQuestion
from app.services.analytics import top_concepts
from app.services.rag import LANGUAGE_NAMES

log = logging.getLogger(__name__)

MAX_CONTEXT_CHUNKS = 8

SYSTEM_PROMPT = """You write multiple-choice practice questions for Indian school students.
Use ONLY facts from the textbook excerpts. Each question has exactly 4 options with exactly one \
correct answer; distractors should reflect common student misconceptions. Keep language simple.
Return JSON: {"title": str, "questions": [{"question": str, "options": [str, str, str, str], \
"answer_index": 0-3, "concept": str (copy the excerpt's concept label), "explanation": str}]}"""


async def generate_quiz(
    session: AsyncSession, classroom: Classroom, chapter: Chapter, req: QuizGenerateIn
) -> Quiz:
    focus = req.concepts
    if not focus:
        since = datetime.now(UTC) - timedelta(days=14)
        stats = await top_concepts(session, classroom.id, since, chapter_id=chapter.id, limit=3)
        focus = [s.concept for s in stats] or chapter.concepts

    chunks = list(
        await session.scalars(
            select(Chunk)
            .where(Chunk.chapter_id == chapter.id, Chunk.concept.in_(focus))
            .order_by(Chunk.position)
            .limit(MAX_CONTEXT_CHUNKS)
        )
    )
    if not chunks:
        chunks = list(
            await session.scalars(
                select(Chunk)
                .where(Chunk.chapter_id == chapter.id)
                .order_by(Chunk.position)
                .limit(MAX_CONTEXT_CHUNKS)
            )
        )

    context = "\n".join(f"[S{i}] ({c.concept})\n{c.text}" for i, c in enumerate(chunks, start=1))
    prompt = (
        f"Chapter: {chapter.title} (Class {chapter.grade} {chapter.subject})\n"
        f"Language: {LANGUAGE_NAMES[req.language]}\n"
        f"Focus concepts: {', '.join(focus)}\n"
        f"Number of questions: {req.num_questions}\n\n"
        f"Textbook excerpts:\n{context}\n---"
    )
    raw = await get_llm().complete_json(SYSTEM_PROMPT, prompt, task="quiz")
    # Models sometimes return the bare question array instead of the requested object.
    if isinstance(raw, list):
        raw = {"questions": raw}
    if not isinstance(raw, dict):
        raise AIError("AI returned an unexpected quiz format. Please retry.", retryable=True)

    questions: list[QuizQuestion] = []
    for item in raw.get("questions", [])[: req.num_questions]:
        try:
            questions.append(QuizQuestion.model_validate(item))
        except ValidationError:
            log.warning("Dropping malformed quiz item: %s", json.dumps(item)[:200])
    if not questions:
        raise AIError("Could not generate valid questions for this chapter. Please retry.")

    quiz = Quiz(
        classroom_id=classroom.id,
        chapter_id=chapter.id,
        title=str(raw.get("title") or f"{chapter.title}: practice"),
        language=req.language,
        questions=[q.model_dump() for q in questions],
    )
    session.add(quiz)
    await session.commit()
    return quiz
