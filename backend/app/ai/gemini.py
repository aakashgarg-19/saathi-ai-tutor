import asyncio
import json
from collections.abc import AsyncIterator
from typing import Any

import httpx

from app.ai.base import AIError, JsonTask, l2_normalise, raise_for_upstream

BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
EMBED_BATCH = 100
MAX_ATTEMPTS = 3


class GeminiLLM:
    name = "gemini"

    def __init__(
        self, api_key: str, model: str, json_model: str, thinking_level: str | None = None
    ):
        if not api_key:
            raise ValueError("GEMINI_API_KEY is required when LLM_PROVIDER=gemini")
        self._model = model
        self._json_model = json_model
        self._thinking_level = thinking_level
        self._client = httpx.AsyncClient(
            base_url=BASE_URL, headers={"x-goog-api-key": api_key}, timeout=60
        )

    def _body(self, system: str, prompt: str, **generation: Any) -> dict:
        return {
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": [{"role": "user", "parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.3,
                # Grounded, short answers don't benefit from reasoning tokens, which are
                # billed as output and add latency.
                **(
                    {"thinkingConfig": {"thinkingLevel": self._thinking_level}}
                    if self._thinking_level
                    else {}
                ),
                **generation,
            },
        }

    async def stream(self, system: str, prompt: str) -> AsyncIterator[str]:
        url = f"/models/{self._model}:streamGenerateContent"
        body = self._body(system, prompt)
        # Retry "high demand" / rate-limit errors, but only before any text has been
        # sent, so the student never sees a duplicated half-answer.
        for attempt in range(MAX_ATTEMPTS):
            async with self._client.stream("POST", url, params={"alt": "sse"}, json=body) as resp:
                if resp.status_code >= 400:
                    await resp.aread()
                    try:
                        raise_for_upstream(resp)
                    except AIError as e:
                        if not e.retryable or attempt == MAX_ATTEMPTS - 1:
                            raise
                    await asyncio.sleep(2**attempt)
                    continue
                async for line in resp.aiter_lines():
                    if not line.startswith("data:"):
                        continue
                    payload = json.loads(line[5:])
                    for cand in payload.get("candidates", []):
                        for part in cand.get("content", {}).get("parts", []):
                            if text := part.get("text"):
                                yield text
                return

    async def complete_json(self, system: str, prompt: str, *, task: JsonTask) -> Any:
        body = self._body(system, prompt, responseMimeType="application/json")
        for attempt in range(MAX_ATTEMPTS):
            resp = await self._client.post(f"/models/{self._json_model}:generateContent", json=body)
            try:
                raise_for_upstream(resp)
                break
            except AIError as e:
                if not e.retryable or attempt == MAX_ATTEMPTS - 1:
                    raise
                await asyncio.sleep(2**attempt)
        try:
            parts = resp.json()["candidates"][0]["content"]["parts"]
            return json.loads("".join(p.get("text", "") for p in parts))
        except (KeyError, IndexError, json.JSONDecodeError) as e:
            raise AIError("AI returned malformed JSON.", retryable=True) from e


class GeminiEmbeddings:
    name = "gemini"
    # Calibrated on gemini-embedding-001 @768d: on-topic top-1 distances were 0.23-0.36,
    # off-topic 0.38-0.54 (scripts/eval_retrieval.py cases vs. unrelated questions).
    default_max_distance = 0.40

    def __init__(self, api_key: str, model: str, dim: int):
        if not api_key:
            raise ValueError("GEMINI_API_KEY is required when EMBEDDING_PROVIDER=gemini")
        self._model = model
        self.dim = dim
        self._client = httpx.AsyncClient(
            base_url=BASE_URL, headers={"x-goog-api-key": api_key}, timeout=60
        )

    async def embed(self, texts: list[str], *, is_query: bool) -> list[list[float]]:
        task_type = "RETRIEVAL_QUERY" if is_query else "RETRIEVAL_DOCUMENT"
        out: list[list[float]] = []
        for i in range(0, len(texts), EMBED_BATCH):
            requests = [
                {
                    "model": f"models/{self._model}",
                    "content": {"parts": [{"text": t}]},
                    "taskType": task_type,
                    "outputDimensionality": self.dim,
                }
                for t in texts[i : i + EMBED_BATCH]
            ]
            resp = await self._client.post(
                f"/models/{self._model}:batchEmbedContents", json={"requests": requests}
            )
            raise_for_upstream(resp)
            # Truncated Gemini embeddings must be re-normalised for cosine distance.
            out.extend(l2_normalise(e["values"]) for e in resp.json()["embeddings"])
        return out
