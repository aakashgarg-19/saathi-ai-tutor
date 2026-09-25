"""Idempotent demo seed: `python -m app.seed [--sample-activity]`.

Creates demo accounts, a classroom, ingests the bundled chapters, and optionally inserts
a week of plausible student doubts so the teacher dashboard isn't empty in a demo.
"""

import argparse
import asyncio
import random
import re
from datetime import UTC, datetime, timedelta
from pathlib import Path

from sqlalchemy import func, select

from app.db import SessionLocal
from app.models import Chapter, Classroom, ClassroomMember, Doubt, Role, User
from app.security import hash_password
from app.services.ingestion import ingest, parse_markdown
from app.services.rag import cache_key, retrieve

CONTENT_DIR = Path(__file__).parent / "content"
DEMO_PASSWORD = "demo1234"
JOIN_CODE = "DEMO7A"

TEACHER = ("Meena Iyer", "teacher@saathi.dev")
STUDENTS = [
    ("Aarav Sharma", "student@saathi.dev"),
    ("Priya Nair", "priya@saathi.dev"),
    ("Rohan Das", "rohan@saathi.dev"),
    ("Fatima Khan", "fatima@saathi.dev"),
    ("Kabir Singh", "kabir@saathi.dev"),
]

SAMPLE_QUESTIONS = {
    "Nutrition in Plants": [
        ("What is photosynthesis?", "en"),
        ("Why do leaves need sunlight to make food?", "en"),
        ("प्रकाश संश्लेषण में ऑक्सीजन कहाँ से आती है?", "hi"),
        ("How does carbon dioxide enter the leaf?", "en"),
        ("What do stomata do?", "en"),
        ("Why is cuscuta called a parasite?", "en"),
        ("How does the pitcher plant digest insects?", "en"),
        ("Why does bread get fungus in the monsoon?", "en"),
        ("What is the difference between xylem and phloem?", "en"),
        ("How do red leaves do photosynthesis without green colour?", "en"),
        ("What is a lichen made of?", "en"),
        ("Why do farmers grow pulses between crops?", "en"),
    ],
    "Microorganisms: Friend and Foe": [
        ("How does curd form from milk?", "en"),
        ("Why should we complete the antibiotic course?", "en"),
        ("How does a vaccine protect us?", "en"),
        ("Which mosquito spreads malaria?", "en"),
        ("What is pasteurisation?", "en"),
        ("Why does yeast make bread soft?", "en"),
    ],
}


def _slug_meta(path: Path) -> tuple[int, str]:
    match = re.match(r"class(\d+)_(\w+?)_", path.stem)
    return int(match.group(1)), match.group(2).title()


async def _get_or_create_user(session, name: str, email: str, role: Role) -> User:
    user = await session.scalar(select(User).where(User.email == email))
    if user is None:
        user = User(name=name, email=email, role=role, password_hash=hash_password(DEMO_PASSWORD))
        session.add(user)
        await session.flush()
    return user


async def seed(sample_activity: bool) -> None:
    async with SessionLocal() as session:
        teacher = await _get_or_create_user(session, *TEACHER, Role.teacher)
        students = [await _get_or_create_user(session, n, e, Role.student) for n, e in STUDENTS]

        classroom = await session.scalar(select(Classroom).where(Classroom.join_code == JOIN_CODE))
        if classroom is None:
            classroom = Classroom(
                name="Class 7-A Science", grade=7, join_code=JOIN_CODE, teacher_id=teacher.id
            )
            session.add(classroom)
            await session.flush()
        for s in students:
            if not await session.get(ClassroomMember, (classroom.id, s.id)):
                session.add(ClassroomMember(classroom_id=classroom.id, student_id=s.id))
        await session.commit()

        chapters: dict[str, Chapter] = {}
        for path in sorted(CONTENT_DIR.glob("*.md")):
            parsed = parse_markdown(path.read_text())
            chapter = await session.scalar(select(Chapter).where(Chapter.title == parsed.title))
            if chapter is None:
                grade, subject = _slug_meta(path)
                chapter = Chapter(title=parsed.title, grade=grade, subject=subject, concepts=[])
                session.add(chapter)
                await session.commit()
                print(f"Ingesting '{parsed.title}' ...")
                await ingest(session, chapter, parsed)
            chapters[chapter.title] = chapter
        print(f"Chapters ready: {', '.join(chapters)}")

        if sample_activity:
            already = await session.scalar(
                select(func.count(Doubt.id)).where(Doubt.answer == "(sample data)")
            )
            if already:
                print("Sample activity already present, skipping.")
            else:
                await _sample_activity(session, students[1:], chapters)

    print(f"\nDemo logins (password '{DEMO_PASSWORD}'):")
    print(f"  teacher: {TEACHER[1]}\n  student: {STUDENTS[0][1]}\n  join code: {JOIN_CODE}")


async def _sample_activity(session, students: list[User], chapters: dict[str, Chapter]) -> None:
    """Other students' doubts, attributed to concepts via real retrieval (embeddings only)."""
    rng = random.Random(7)
    now = datetime.now(UTC)
    count = 0
    for title, questions in SAMPLE_QUESTIONS.items():
        chapter = chapters.get(title)
        if not chapter:
            continue
        for question, lang in questions:
            retrieved = await retrieve(session, chapter.id, question)
            concepts = list(dict.fromkeys(r.chunk.concept for r in retrieved))[:2]
            # Weight photosynthesis-related doubts so the demo heatmap tells a story.
            repeats = 3 if "Photosynthesis" in concepts or "Stomata" in " ".join(concepts) else 1
            for _ in range(repeats):
                session.add(
                    Doubt(
                        student_id=rng.choice(students).id,
                        chapter_id=chapter.id,
                        question=question,
                        language=lang,
                        answer="(sample data)",
                        concepts=concepts,
                        source_chunk_ids=[r.chunk.id for r in retrieved],
                        # Distinct key so sample rows never serve as cached answers.
                        cache_key=cache_key(chapter.id, lang, f"sample {question}"),
                        helpful=rng.choice([True, True, True, False, None]),
                        created_at=now - timedelta(days=rng.uniform(0, 6), hours=rng.uniform(0, 8)),
                    )
                )
                count += 1
    await session.commit()
    print(f"Inserted {count} sample doubts.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sample-activity", action="store_true")
    asyncio.run(seed(parser.parse_args().sample_activity))
