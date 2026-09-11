"""Deterministic, network-free providers.

Used by the test-suite and for keyless demos. The embedding is a signed feature-hashing
bag-of-words, which is good enough for keyword-level retrieval; the LLM answers
extractively from the retrieved context so the full RAG flow is exercised end to end.
"""

import asyncio
import hashlib
import re
from collections.abc import AsyncIterator
from typing import Any

from app.ai.base import JsonTask, l2_normalise

CONTEXT_BLOCK = re.compile(r"\[S(\d+)\] \((.*?)\)\n(.*?)(?=\n\[S\d+\] |\n---|\Z)", re.S)
TOKEN = re.compile(r"[\wऀ-ॿ]+", re.U)
STOPWORDS = {
    "the",
    "a",
    "an",
    "is",
    "are",
    "was",
    "of",
    "to",
    "in",
    "and",
    "or",
    "what",
    "why",
    "how",
    "do",
    "does",
    "it",
    "this",
    "that",
    "for",
    "on",
    "with",
    "as",
    "by",
    "be",
}


def _tokens(text: str) -> list[str]:
    out = []
    for t in TOKEN.findall(text.lower()):
        if t in STOPWORDS or len(t) < 2:
            continue
        out.append(t[:-1] if t.endswith("s") and len(t) > 3 else t)
    return out


def _sentences(text: str) -> list[str]:
    return [s.strip() for s in re.split(r"(?<=[.!?।])\s+", text.strip()) if len(s.strip()) > 20]


class FakeEmbeddings:
    name = "fake"
    # Hashed bag-of-words: any shared keyword counts as related.
    default_max_distance = 0.97

    def __init__(self, dim: int):
        self.dim = dim

    async def embed(self, texts: list[str], *, is_query: bool) -> list[list[float]]:
        return [self._embed_one(t) for t in texts]

    def _embed_one(self, text: str) -> list[float]:
        vec = [0.0] * self.dim
        for tok in _tokens(text):
            h = int.from_bytes(hashlib.md5(tok.encode()).digest()[:8], "big")
            vec[h % self.dim] += 1.0 if (h >> 63) & 1 else -1.0
        return l2_normalise(vec)


class FakeLLM:
    name = "fake"

    def __init__(self, delay: float = 0.02):
        self._delay = delay

    async def stream(self, system: str, prompt: str) -> AsyncIterator[str]:
        blocks = CONTEXT_BLOCK.findall(prompt)
        if not blocks:
            answer = (
                "I couldn't find this in your chapter. Try asking about a topic from "
                "the selected chapter, or ask your teacher."
            )
        else:
            sid, concept, text = blocks[0]
            body = " ".join(_sentences(text)[:2]) or text.strip()
            answer = f"**{concept}**: {body} [S{sid}]"
            if "Answer language: Hindi" in prompt:
                answer = f"(Hindi translation unavailable offline)\n\n{answer}"
        for word in re.split(r"(\s+)", answer):
            if word:
                yield word
                await asyncio.sleep(self._delay)

    async def complete_json(self, system: str, prompt: str, *, task: JsonTask) -> Any:
        assert task == "quiz"
        n_match = re.search(r"Number of questions: (\d+)", prompt)
        n = int(n_match.group(1)) if n_match else 5
        sentences = [
            (concept, s)
            for _, concept, text in CONTEXT_BLOCK.findall(prompt)
            for s in _sentences(text)
        ]
        vocab = sorted({w for _, s in sentences for w in TOKEN.findall(s) if len(w) > 6})
        questions = []
        for concept, sentence in sentences:
            words = [w for w in TOKEN.findall(sentence) if len(w) > 6]
            if not words or len(vocab) < 4:
                continue
            key = max(words, key=len)
            distractors = [w for w in vocab if w.lower() != key.lower()][:3]
            options = sorted([key, *distractors], key=lambda w: hashlib.md5(w.encode()).digest())
            questions.append(
                {
                    "question": f"Fill in the blank: {sentence.replace(key, '_____', 1)}",
                    "options": options,
                    "answer_index": options.index(key),
                    "concept": concept,
                    "explanation": sentence,
                }
            )
            if len(questions) == n:
                break
        return {"title": "Practice quiz", "questions": questions}
