from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+asyncpg://saathi:saathi@localhost:5432/saathi"
    # Tests disable pooling so connections never outlive the event loop that opened them.
    db_disable_pool: bool = False

    jwt_secret: str = "dev-only-secret-change-me-in-production"
    jwt_expiry_minutes: int = 60 * 24 * 7

    # "gemini" uses Google's free tier; "openai_compat" works with Groq / Sarvam / Ollama;
    # "fake" is a deterministic offline provider used in tests and keyless demos.
    llm_provider: Literal["gemini", "openai_compat", "fake"] = "fake"
    embedding_provider: Literal["gemini", "fake"] = "fake"

    gemini_api_key: str = ""
    # Pinned rather than "-latest" so cost and behaviour don't drift. Chosen by measured
    # latency and rule-following on Hindi grounded answers (see README).
    gemini_chat_model: str = "gemini-3.1-flash-lite"
    gemini_json_model: str = "gemini-3.5-flash"
    gemini_thinking_level: str | None = "minimal"
    gemini_embedding_model: str = "gemini-embedding-001"

    openai_compat_base_url: str = "https://api.groq.com/openai/v1"
    openai_compat_api_key: str = ""
    openai_compat_model: str = "llama-3.3-70b-versatile"

    embedding_dim: int = 768
    retrieval_top_k: int = 4
    # Chunks farther than this cosine distance are off-topic. None = provider's calibrated default.
    retrieval_max_distance: float | None = None

    cors_origins: list[str] = ["*"]


@lru_cache
def get_settings() -> Settings:
    return Settings()
