"""Provider-agnostic interfaces for every model call the backend makes.

Routing all AI traffic through these two protocols keeps vendors swappable by config
(Gemini free tier today; Sarvam / AI4Bharat / self-hosted models tomorrow).
"""

from collections.abc import AsyncIterator
from typing import Any, Literal, Protocol

import httpx

JsonTask = Literal["quiz"]


class AIError(Exception):
    """Raised when an upstream model call fails in a way the user should hear about."""

    def __init__(self, message: str, *, retryable: bool = False):
        super().__init__(message)
        self.retryable = retryable


class LLMProvider(Protocol):
    name: str

    def stream(self, system: str, prompt: str) -> AsyncIterator[str]:
        """Yield the answer incrementally as text deltas."""
        ...

    async def complete_json(self, system: str, prompt: str, *, task: JsonTask) -> Any:
        """Return a parsed JSON value. `task` lets offline providers fake the right shape."""
        ...


class EmbeddingProvider(Protocol):
    name: str
    dim: int
    # Cosine distance beyond which a chunk is considered unrelated to the query.
    default_max_distance: float

    async def embed(self, texts: list[str], *, is_query: bool) -> list[list[float]]:
        """Return one L2-normalised vector per input text."""
        ...


def l2_normalise(vec: list[float]) -> list[float]:
    norm = sum(v * v for v in vec) ** 0.5
    return [v / norm for v in vec] if norm else vec


def raise_for_upstream(resp: httpx.Response) -> None:
    if resp.status_code == 429:
        raise AIError("AI quota reached, please try again in a minute.", retryable=True)
    if resp.status_code >= 500:
        raise AIError("AI service is temporarily unavailable.", retryable=True)
    if resp.status_code >= 400:
        raise AIError(f"AI request rejected ({resp.status_code}): {resp.text[:200]}")
