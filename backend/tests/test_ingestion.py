from app.services.ingestion import parse_markdown, split_text
from app.services.rag import cache_key


def test_parse_markdown_sections():
    parsed = parse_markdown(
        "# Light\n\nintro text\n\n## Reflection\nMirrors reflect.\n\n## Refraction\nBends."
    )
    assert parsed.title == "Light"
    assert [s.concept for s in parsed.sections] == ["Introduction", "Reflection", "Refraction"]


def test_split_text_respects_limit_and_overlaps():
    text = " ".join(f"Sentence number {i} is here." for i in range(60))
    chunks = split_text(text, max_chars=200)
    assert len(chunks) > 1
    assert all(len(c) <= 260 for c in chunks)
    # Last sentence of one chunk opens the next, so context isn't cut mid-thought.
    assert chunks[1].startswith(chunks[0].split(". ")[-1].rstrip("."))


def test_cache_key_normalises_question():
    key = cache_key(1, "en", "What is Photosynthesis?")
    assert key == cache_key(1, "en", "what is  photosynthesis")
    assert cache_key(1, "en", "x y") != cache_key(1, "hi", "x y")
