from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Classroom, ClassroomMember, Doubt, User
from app.schemas import ConceptStat, InsightsOut, RecentDoubt

CONCEPT_COUNTS = text("""
    SELECT c.concept, ch.title AS chapter_title,
           count(*) AS count,
           count(*) FILTER (WHERE d.helpful IS FALSE) AS unhelpful
    FROM doubts d
    JOIN classroom_members m ON m.student_id = d.student_id AND m.classroom_id = :classroom_id
    JOIN chapters ch ON ch.id = d.chapter_id
    CROSS JOIN LATERAL json_array_elements_text(d.concepts) AS c(concept)
    WHERE d.created_at >= :since
      AND (CAST(:chapter_id AS int) IS NULL OR d.chapter_id = :chapter_id)
    GROUP BY c.concept, ch.title
    ORDER BY count DESC, unhelpful DESC
    LIMIT :limit
""")


async def top_concepts(
    session: AsyncSession,
    classroom_id: int,
    since: datetime,
    *,
    chapter_id: int | None = None,
    limit: int = 12,
) -> list[ConceptStat]:
    rows = await session.execute(
        CONCEPT_COUNTS,
        {"classroom_id": classroom_id, "since": since, "chapter_id": chapter_id, "limit": limit},
    )
    return [ConceptStat(**row._mapping) for row in rows]


async def classroom_insights(
    session: AsyncSession, classroom: Classroom, days: int = 7
) -> InsightsOut:
    since = datetime.now(UTC) - timedelta(days=days)
    members = select(ClassroomMember.student_id).where(ClassroomMember.classroom_id == classroom.id)
    in_class = (Doubt.student_id.in_(members), Doubt.created_at >= since)

    total, active, rated, helpful = (
        await session.execute(
            select(
                func.count(Doubt.id),
                func.count(func.distinct(Doubt.student_id)),
                func.count(Doubt.helpful),
                func.count().filter(Doubt.helpful.is_(True)),
            ).where(*in_class)
        )
    ).one()
    total_students = await session.scalar(select(func.count()).select_from(members.subquery()))
    recent_rows = await session.execute(
        select(Doubt, User.name)
        .join(User, User.id == Doubt.student_id)
        .where(*in_class)
        .order_by(Doubt.created_at.desc())
        .limit(10)
    )

    return InsightsOut(
        days=days,
        total_doubts=total,
        active_students=active,
        total_students=total_students or 0,
        helpful_rate=round(helpful / rated, 2) if rated else None,
        concepts=await top_concepts(session, classroom.id, since),
        recent=[
            RecentDoubt(
                question=d.question,
                student_name=name,
                concepts=d.concepts,
                created_at=d.created_at,
            )
            for d, name in recent_rows
        ],
    )
