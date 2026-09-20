import secrets
import string

from fastapi import APIRouter, HTTPException, Query, WebSocket, WebSocketDisconnect, status
from sqlalchemy import func, select

from app.db import SessionLocal
from app.deps import CurrentUser, Session, Student, Teacher, classroom_for, user_from_token
from app.models import Classroom, ClassroomMember, Role
from app.schemas import ClassroomIn, ClassroomOut, InsightsOut, JoinIn
from app.services.analytics import classroom_insights
from app.services.realtime import hub

router = APIRouter(prefix="/classrooms", tags=["classrooms"])

# No 0/O/1/I so codes survive being read aloud or written on a blackboard.
CODE_ALPHABET = "".join(c for c in string.ascii_uppercase + string.digits if c not in "0O1I")


def _new_code() -> str:
    return "".join(secrets.choice(CODE_ALPHABET) for _ in range(6))


async def _with_counts(session, classrooms: list[Classroom]) -> list[ClassroomOut]:
    ids = [c.id for c in classrooms]
    counts = (
        dict(
            (
                await session.execute(
                    select(ClassroomMember.classroom_id, func.count())
                    .where(ClassroomMember.classroom_id.in_(ids))
                    .group_by(ClassroomMember.classroom_id)
                )
            ).all()
        )
        if ids
        else {}
    )
    return [
        ClassroomOut.model_validate(c).model_copy(update={"student_count": counts.get(c.id, 0)})
        for c in classrooms
    ]


@router.post("", response_model=ClassroomOut, status_code=status.HTTP_201_CREATED)
async def create_classroom(body: ClassroomIn, teacher: Teacher, session: Session):
    code = _new_code()
    while await session.scalar(select(Classroom).where(Classroom.join_code == code)):
        code = _new_code()
    classroom = Classroom(
        name=body.name.strip(), grade=body.grade, join_code=code, teacher_id=teacher.id
    )
    session.add(classroom)
    await session.commit()
    return ClassroomOut.model_validate(classroom)


@router.get("", response_model=list[ClassroomOut])
async def my_classrooms(user: CurrentUser, session: Session):
    query = select(Classroom).order_by(Classroom.created_at)
    if user.role == Role.teacher:
        query = query.where(Classroom.teacher_id == user.id)
    else:
        query = query.join(ClassroomMember).where(ClassroomMember.student_id == user.id)
    return await _with_counts(session, list(await session.scalars(query)))


@router.post("/join", response_model=ClassroomOut)
async def join_classroom(body: JoinIn, student: Student, session: Session):
    classroom = await session.scalar(
        select(Classroom).where(Classroom.join_code == body.join_code.strip().upper())
    )
    if classroom is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No classroom with that code")
    if not await session.get(ClassroomMember, (classroom.id, student.id)):
        session.add(ClassroomMember(classroom_id=classroom.id, student_id=student.id))
        await session.commit()
    [out] = await _with_counts(session, [classroom])
    return out


@router.get("/{classroom_id}/insights", response_model=InsightsOut)
async def insights(
    classroom_id: int, teacher: Teacher, session: Session, days: int = Query(7, ge=1, le=90)
):
    classroom = await classroom_for(session, classroom_id, teacher)
    return await classroom_insights(session, classroom, days)


@router.websocket("/{classroom_id}/live")
async def live(ws: WebSocket, classroom_id: int, token: str = Query(...)):
    """Teacher dashboards subscribe here for doubt / quiz events. Browsers can't set
    Authorization headers on WebSockets, so the JWT travels as a query parameter."""
    async with SessionLocal() as session:
        try:
            user = await user_from_token(session, token)
            await classroom_for(session, classroom_id, user)
            if user.role != Role.teacher:
                raise HTTPException(status.HTTP_403_FORBIDDEN)
        except HTTPException:
            await ws.close(code=status.WS_1008_POLICY_VIOLATION)
            return

    await ws.accept()
    hub.connect(classroom_id, ws)
    try:
        while True:
            await ws.receive_text()  # keep-alive pings from the client
    except WebSocketDisconnect:
        pass
    finally:
        hub.disconnect(classroom_id, ws)
