import logging

from fastapi import APIRouter, BackgroundTasks, Form, HTTPException, UploadFile, status
from sqlalchemy import select

from app.db import SessionLocal
from app.deps import CurrentUser, Session, Teacher
from app.models import Chapter, ChapterStatus
from app.schemas import ChapterOut
from app.services.ingestion import ParsedChapter, ingest, parse_markdown, parse_pdf

log = logging.getLogger(__name__)
router = APIRouter(prefix="/chapters", tags=["chapters"])

MAX_UPLOAD_BYTES = 15 * 1024 * 1024


@router.get("", response_model=list[ChapterOut])
async def list_chapters(user: CurrentUser, session: Session, grade: int | None = None):
    query = select(Chapter).order_by(Chapter.grade, Chapter.subject, Chapter.id)
    if grade:
        query = query.where(Chapter.grade == grade)
    return list(await session.scalars(query))


@router.get("/{chapter_id}", response_model=ChapterOut)
async def get_chapter(chapter_id: int, user: CurrentUser, session: Session):
    chapter = await session.get(Chapter, chapter_id)
    if chapter is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Chapter not found")
    return chapter


async def _ingest_in_background(chapter_id: int, parsed: ParsedChapter) -> None:
    async with SessionLocal() as session:
        chapter = await session.get(Chapter, chapter_id)
        try:
            await ingest(session, chapter, parsed)
        except Exception:
            log.exception("Ingestion failed for chapter %s", chapter_id)


@router.post("", response_model=ChapterOut, status_code=status.HTTP_202_ACCEPTED)
async def upload_chapter(
    teacher: Teacher,
    session: Session,
    background: BackgroundTasks,
    file: UploadFile,
    subject: str = Form(..., max_length=60),
    grade: int = Form(..., ge=1, le=12),
    title: str | None = Form(None, max_length=200),
):
    """Upload a chapter as PDF or Markdown. Embedding happens in the background; poll
    GET /chapters/{id} until status is `ready`."""
    data = await file.read(MAX_UPLOAD_BYTES + 1)
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "File is larger than 15 MB")

    name = (file.filename or "").lower()
    if name.endswith(".pdf"):
        parsed = parse_pdf(data, title or file.filename.rsplit(".", 1)[0])
    elif name.endswith((".md", ".txt")):
        parsed = parse_markdown(data.decode("utf-8", errors="replace"))
        parsed.title = title or parsed.title
    else:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "Upload a .pdf or .md file")
    if not parsed.sections:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "No readable text found")

    chapter = Chapter(
        subject=subject,
        grade=grade,
        title=parsed.title,
        status=ChapterStatus.processing,
        concepts=[],
    )
    session.add(chapter)
    await session.commit()
    background.add_task(_ingest_in_background, chapter.id, parsed)
    return chapter
