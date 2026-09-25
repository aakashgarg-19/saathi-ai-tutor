"""Retrieval quality check: does the right textbook section come back for each question?

    uv run python -m scripts.eval_retrieval

Reports hit@1 and hit@k against hand-labelled questions (English + Hindi). Run it after
changing chunking, embeddings or the distance threshold, to catch regressions.
"""

import asyncio

from sqlalchemy import select

from app.ai import get_embedder
from app.config import get_settings
from app.db import SessionLocal
from app.models import Chapter
from app.services.rag import retrieve

# (chapter title, question, expected concept)
CASES = [
    ("Nutrition in Plants", "What is photosynthesis?", "Photosynthesis"),
    ("Nutrition in Plants", "How do we test a leaf for starch?", "Photosynthesis"),
    ("Nutrition in Plants", "Why are leaves called food factories?", "Chlorophyll and Leaves"),
    ("Nutrition in Plants", "Can red leaves make food?", "Chlorophyll and Leaves"),
    ("Nutrition in Plants", "What are guard cells?", "Stomata and Transport of Water"),
    ("Nutrition in Plants", "How does water reach the leaves?", "Stomata and Transport of Water"),
    ("Nutrition in Plants", "Why do farmers add fertilisers?", "Making Proteins and Fats"),
    ("Nutrition in Plants", "What is amarbel?", "Parasitic Plants"),
    ("Nutrition in Plants", "How does the pitcher plant trap insects?", "Insectivorous Plants"),
    ("Nutrition in Plants", "Why does bread get mould in the rainy season?", "Saprotrophs"),
    ("Nutrition in Plants", "What lives in the root nodules of gram?", "Symbiosis"),
    ("Nutrition in Plants", "प्रकाश संश्लेषण क्या है?", "Photosynthesis"),
    ("Nutrition in Plants", "पत्तियों में छोटे छिद्र क्या कहलाते हैं?", "Stomata and Transport of Water"),
    ("Microorganisms: Friend and Foe", "How is curd made?", "Useful Microorganisms in Food"),
    ("Microorganisms: Friend and Foe", "Who discovered penicillin?", "Medicines and Vaccines"),
    ("Microorganisms: Friend and Foe", "How do vaccines work?", "Medicines and Vaccines"),
    (
        "Microorganisms: Friend and Foe",
        "Which mosquito spreads dengue?",
        "Harmful Microorganisms and Diseases",
    ),
    (
        "Microorganisms: Friend and Foe",
        "Why is sugar added to jam?",
        "Food Poisoning and Food Preservation",
    ),
    ("Microorganisms: Friend and Foe", "What is fermentation?", "Fermentation"),
    ("Microorganisms: Friend and Foe", "दूध से दही कैसे बनता है?", "Useful Microorganisms in Food"),
]


async def main() -> None:
    k = get_settings().retrieval_top_k
    hit1 = hitk = 0
    async with SessionLocal() as session:
        chapters = {c.title: c.id for c in await session.scalars(select(Chapter))}
        for title, question, expected in CASES:
            got = [r.chunk.concept for r in await retrieve(session, chapters[title], question)]
            ok1, okk = bool(got) and got[0] == expected, expected in got
            hit1 += ok1
            hitk += okk
            mark = "✓" if ok1 else ("~" if okk else "✗")
            print(f"{mark} {question[:50]:<50} -> {got[0] if got else '(nothing)'}")

    n = len(CASES)
    print(
        f"\nembeddings={get_embedder().name}  hit@1={hit1 / n:.0%}  hit@{k}={hitk / n:.0%}  (n={n})"
    )


if __name__ == "__main__":
    asyncio.run(main())
