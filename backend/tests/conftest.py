import os

# Must be set before any app module creates the engine.
os.environ.setdefault(
    "DATABASE_URL", "postgresql+asyncpg://saathi:saathi@localhost:5432/saathi_test"
)
os.environ["DB_DISABLE_POOL"] = "true"
os.environ["LLM_PROVIDER"] = "fake"
os.environ["EMBEDDING_PROVIDER"] = "fake"

import json  # noqa: E402
from pathlib import Path  # noqa: E402

import pytest  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy import text  # noqa: E402

from app import models  # noqa: E402, F401
from app.ai import get_llm  # noqa: E402
from app.db import Base, engine  # noqa: E402
from app.main import app  # noqa: E402

CHAPTER_MD = Path(__file__).parents[1] / "app/seed/content/class7_science_nutrition_in_plants.md"


@pytest.fixture(scope="session", autouse=True)
async def schema():
    get_llm()._delay = 0  # no artificial streaming delay in tests
    async with engine.begin() as conn:
        await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


@pytest.fixture(autouse=True)
async def clean_tables():
    yield
    async with engine.begin() as conn:
        tables = ", ".join(t.name for t in Base.metadata.sorted_tables)
        await conn.execute(text(f"TRUNCATE {tables} RESTART IDENTITY CASCADE"))


@pytest.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


async def register(client: AsyncClient, role: str, email: str, name: str = "Test User") -> dict:
    resp = await client.post(
        "/auth/register",
        json={
            "name": name,
            "email": email,
            "password": "secret123",
            "role": role,
        },
    )
    assert resp.status_code == 201, resp.text
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


def parse_sse(body: str) -> list[tuple[str, dict]]:
    events = []
    for block in body.strip().split("\n\n"):
        lines = dict(line.split(": ", 1) for line in block.splitlines())
        events.append((lines["event"], json.loads(lines["data"])))
    return events


@pytest.fixture
async def classroom(client):
    """A teacher with a classroom, one joined student, and one ingested chapter."""
    teacher = await register(client, "teacher", "teacher@test.dev", "Ms Teacher")
    student = await register(client, "student", "student@test.dev", "Asha")

    room = (
        await client.post("/classrooms", json={"name": "7-A", "grade": 7}, headers=teacher)
    ).json()
    resp = await client.post(
        "/classrooms/join", json={"join_code": room["join_code"]}, headers=student
    )
    assert resp.status_code == 200

    resp = await client.post(
        "/chapters",
        headers=teacher,
        data={"subject": "Science", "grade": "7"},
        files={"file": ("nutrition.md", CHAPTER_MD.read_bytes(), "text/markdown")},
    )
    assert resp.status_code == 202, resp.text
    chapter = (await client.get(f"/chapters/{resp.json()['id']}", headers=teacher)).json()
    assert chapter["status"] == "ready"

    return {"teacher": teacher, "student": student, "room": room, "chapter": chapter}
