import json
import logging

from fastapi import APIRouter, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select

from app.ai import AIError
from app.db import SessionLocal
from app.deps import Session, Student
from app.models import Chapter, ChapterStatus, Doubt, User
from app.schemas import AskIn, DoubtOut, FeedbackIn
from app.services.rag import answer_doubt, sources_for

log = logging.getLogger(__name__)
router = APIRouter(prefix="/doubts", tags=["doubts"])


async def _ready_chapter(session, chapter_id: int) -> Chapter:
    chapter = await session.get(Chapter, chapter_id)
    if chapter is None or chapter.status != ChapterStatus.ready:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Chapter not found or still processing")
    return chapter


def _sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


@router.post("/ask/stream")
async def ask_stream(body: AskIn, student: Student, session: Session):
    """Server-Sent Events: `sources` -> `token`* -> `done` (or `error`)."""
    await _ready_chapter(session, body.chapter_id)
    student_id = student.id

    async def events():
        # Own session: the request-scoped one may be closed before streaming finishes.
        async with SessionLocal() as s:
            user = await s.get(User, student_id)
            chapter = await s.get(Chapter, body.chapter_id)
            try:
                async for event, data in answer_doubt(s, user, chapter, body):
                    yield _sse(event, data)
            except AIError as e:
                yield _sse("error", {"message": str(e), "retryable": e.retryable})
            except Exception:
                log.exception("Unexpected error while answering")
                yield _sse("error", {"message": "Something went wrong.", "retryable": True})

    return StreamingResponse(
        events(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.post("", response_model=DoubtOut)
async def ask(body: AskIn, student: Student, session: Session):
    """Non-streaming variant used by the app's offline sync queue. Idempotent per client_id."""
    chapter = await _ready_chapter(session, body.chapter_id)
    doubt_id = None
    try:
        async for event, data in answer_doubt(session, student, chapter, body):
            if event == "done":
                doubt_id = data["doubt_id"]
    except AIError as e:
        code = status.HTTP_503_SERVICE_UNAVAILABLE if e.retryable else status.HTTP_502_BAD_GATEWAY
        raise HTTPException(code, str(e)) from e
    return await _doubt_out(session, await session.get(Doubt, doubt_id))


@router.get("", response_model=list[DoubtOut])
async def my_doubts(
    student: Student,
    session: Session,
    chapter_id: int | None = None,
    limit: int = Query(50, ge=1, le=200),
):
    query = select(Doubt).where(Doubt.student_id == student.id)
    if chapter_id:
        query = query.where(Doubt.chapter_id == chapter_id)
    doubts = await session.scalars(query.order_by(Doubt.created_at.desc()).limit(limit))
    return [await _doubt_out(session, d) for d in doubts]


@router.post("/{doubt_id}/feedback", response_model=DoubtOut)
async def feedback(doubt_id: int, body: FeedbackIn, student: Student, session: Session):
    doubt = await session.get(Doubt, doubt_id)
    if doubt is None or doubt.student_id != student.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Doubt not found")
    doubt.helpful = body.helpful
    await session.commit()
    return await _doubt_out(session, doubt)


async def _doubt_out(session, doubt: Doubt) -> DoubtOut:
    out = DoubtOut.model_validate(doubt)
    out.sources = await sources_for(session, doubt.source_chunk_ids)
    return out
