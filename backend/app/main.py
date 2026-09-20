import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.ai import get_embedder, get_llm
from app.config import get_settings
from app.db import engine
from app.routers import auth, chapters, classrooms, doubts, quizzes

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")

app = FastAPI(
    title="Saathi API",
    version="0.1.0",
    description="Curriculum-grounded, multilingual doubt solving with teacher insights.",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

for module in (auth, classrooms, chapters, doubts, quizzes):
    app.include_router(module.router)


@app.get("/health", tags=["meta"])
async def health():
    async with engine.connect() as conn:
        await conn.execute(text("SELECT 1"))
    return {"status": "ok", "llm": get_llm().name, "embeddings": get_embedder().name}
