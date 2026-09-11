from functools import lru_cache

from app.ai.base import AIError, EmbeddingProvider, LLMProvider
from app.config import get_settings

__all__ = ["AIError", "EmbeddingProvider", "LLMProvider", "get_embedder", "get_llm"]


@lru_cache
def get_llm() -> LLMProvider:
    s = get_settings()
    match s.llm_provider:
        case "gemini":
            from app.ai.gemini import GeminiLLM

            return GeminiLLM(
                s.gemini_api_key, s.gemini_chat_model, s.gemini_json_model, s.gemini_thinking_level
            )
        case "openai_compat":
            from app.ai.openai_compat import OpenAICompatLLM

            return OpenAICompatLLM(
                s.openai_compat_base_url, s.openai_compat_api_key, s.openai_compat_model
            )
        case _:
            from app.ai.fake import FakeLLM

            return FakeLLM()


@lru_cache
def get_embedder() -> EmbeddingProvider:
    s = get_settings()
    if s.embedding_provider == "gemini":
        from app.ai.gemini import GeminiEmbeddings

        return GeminiEmbeddings(s.gemini_api_key, s.gemini_embedding_model, s.embedding_dim)
    from app.ai.fake import FakeEmbeddings

    return FakeEmbeddings(s.embedding_dim)
