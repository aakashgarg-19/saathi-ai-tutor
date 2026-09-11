"""Chat provider for any OpenAI-compatible endpoint: Groq (free tier), Sarvam, Ollama, vLLM."""

import json
from collections.abc import AsyncIterator
from typing import Any

import httpx

from app.ai.base import AIError, JsonTask, raise_for_upstream


class OpenAICompatLLM:
    name = "openai_compat"

    def __init__(self, base_url: str, api_key: str, model: str):
        self._model = model
        headers = {"Authorization": f"Bearer {api_key}"} if api_key else {}
        self._client = httpx.AsyncClient(base_url=base_url, headers=headers, timeout=60)

    def _messages(self, system: str, prompt: str) -> list[dict]:
        return [{"role": "system", "content": system}, {"role": "user", "content": prompt}]

    async def stream(self, system: str, prompt: str) -> AsyncIterator[str]:
        body = {
            "model": self._model,
            "messages": self._messages(system, prompt),
            "temperature": 0.3,
            "stream": True,
        }
        async with self._client.stream("POST", "/chat/completions", json=body) as resp:
            if resp.status_code >= 400:
                await resp.aread()
                raise_for_upstream(resp)
            async for line in resp.aiter_lines():
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if data == "[DONE]":
                    return
                for choice in json.loads(data).get("choices", []):
                    if text := choice.get("delta", {}).get("content"):
                        yield text

    async def complete_json(self, system: str, prompt: str, *, task: JsonTask) -> Any:
        body = {
            "model": self._model,
            "messages": self._messages(system, prompt),
            "temperature": 0.3,
            "response_format": {"type": "json_object"},
        }
        resp = await self._client.post("/chat/completions", json=body)
        raise_for_upstream(resp)
        try:
            return json.loads(resp.json()["choices"][0]["message"]["content"])
        except (KeyError, json.JSONDecodeError) as e:
            raise AIError("AI returned malformed JSON.") from e
