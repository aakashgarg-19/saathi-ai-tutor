"""Turn chapter content (Markdown or PDF) into concept-tagged, embedded chunks.

Every chunk remembers which concept (section heading) it came from. That tag is what later
lets us attribute a student's doubt to a concept for free, without an extra LLM call.
"""

import io
import re
from dataclasses import dataclass

from pypdf import PdfReader
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai import get_embedder
from app.models import Chapter, ChapterStatus, Chunk

MAX_CHARS = 700


@dataclass
class Section:
    concept: str
    text: str
    page: int | None = None


@dataclass
class ParsedChapter:
    title: str
    sections: list[Section]


def parse_markdown(md: str) -> ParsedChapter:
    """`# Title`, then one `## Concept` heading per section."""
    title, sections = "Untitled chapter", []
    concept, buf = "Introduction", []

    def flush():
        if text := "\n".join(buf).strip():
            sections.append(Section(concept, text))

    for line in md.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
        elif line.startswith("## "):
            flush()
            concept, buf = line[3:].strip(), []
        else:
            buf.append(line)
    flush()
    return ParsedChapter(title, sections)


def _looks_like_heading(line: str) -> bool:
    words = line.split()
    return (
        1 <= len(words) <= 8
        and not line.endswith((".", ",", ";", ":", "?"))
        and line[0].isupper()
        and not re.match(r"^(fig|table|activity)\b", line, re.I)
    )


def parse_pdf(data: bytes, title: str) -> ParsedChapter:
    """Best-effort heading detection; falls back to one concept per page."""
    sections: list[Section] = []
    concept: str | None = None
    for page_no, page in enumerate(PdfReader(io.BytesIO(data)).pages, start=1):
        buf: list[str] = []
        for raw in (page.extract_text() or "").splitlines():
            line = raw.strip()
            if not line:
                continue
            if _looks_like_heading(line):
                if buf:
                    sections.append(Section(concept or f"Page {page_no}", " ".join(buf), page_no))
                concept, buf = line, []
            else:
                buf.append(line)
        if buf:
            sections.append(Section(concept or f"Page {page_no}", " ".join(buf), page_no))
    return ParsedChapter(title, sections)


def split_text(text: str, max_chars: int = MAX_CHARS) -> list[str]:
    """Sentence-aware windows with one sentence of overlap between neighbours."""
    sentences = [s for s in re.split(r"(?<=[.!?।])\s+", " ".join(text.split())) if s]
    chunks: list[str] = []
    current: list[str] = []
    for sentence in sentences:
        if current and len(" ".join(current)) + len(sentence) > max_chars:
            chunks.append(" ".join(current))
            current = current[-1:]
        current.append(sentence)
    if current:
        chunks.append(" ".join(current))
    return chunks


async def ingest(session: AsyncSession, chapter: Chapter, parsed: ParsedChapter) -> None:
    pieces = [(section, text) for section in parsed.sections for text in split_text(section.text)]
    try:
        vectors = await get_embedder().embed(
            [f"{section.concept}: {text}" for section, text in pieces], is_query=False
        )
    except Exception:
        chapter.status = ChapterStatus.failed
        await session.commit()
        raise

    session.add_all(
        Chunk(
            chapter_id=chapter.id,
            concept=section.concept,
            text=text,
            page=section.page,
            position=i,
            embedding=vector,
        )
        for i, ((section, text), vector) in enumerate(zip(pieces, vectors, strict=True))
    )
    chapter.concepts = list(dict.fromkeys(s.concept for s in parsed.sections))
    chapter.status = ChapterStatus.ready
    await session.commit()
