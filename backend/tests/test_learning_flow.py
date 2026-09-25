from tests.conftest import parse_sse, register


async def ask_stream(client, headers, chapter_id, question, **extra):
    resp = await client.post(
        "/doubts/ask/stream",
        headers=headers,
        json={
            "chapter_id": chapter_id,
            "question": question,
            "language": "en",
            **extra,
        },
    )
    assert resp.status_code == 200
    return parse_sse(resp.text)


async def test_streamed_answer_is_grounded_and_tagged(client, classroom):
    events = await ask_stream(
        client,
        classroom["student"],
        classroom["chapter"]["id"],
        "How does carbon dioxide enter the leaf through stomata?",
    )
    kinds = [e for e, _ in events]
    assert kinds[0] == "sources" and kinds[-1] == "done" and "token" in kinds

    sources = events[0][1]["sources"]
    assert sources[0]["concept"] == "Stomata and Transport of Water"
    answer = "".join(d["text"] for e, d in events if e == "token")
    assert "[S1]" in answer
    done = events[-1][1]
    assert "Stomata and Transport of Water" in done["concepts"]
    assert done["from_cache"] is False


async def test_repeat_question_served_from_cache(client, classroom):
    cid = classroom["chapter"]["id"]
    await ask_stream(client, classroom["student"], cid, "What is photosynthesis?")
    events = await ask_stream(client, classroom["student"], cid, "what is PHOTOSYNTHESIS")
    assert events[-1][1]["from_cache"] is True


async def test_offline_sync_is_idempotent(client, classroom):
    body = {
        "chapter_id": classroom["chapter"]["id"],
        "question": "What do fungi feed on?",
        "language": "en",
        "client_id": "device-abc-1",
    }
    first = await client.post("/doubts", json=body, headers=classroom["student"])
    second = await client.post("/doubts", json=body, headers=classroom["student"])
    assert first.status_code == second.status_code == 200
    assert first.json()["id"] == second.json()["id"]
    history = await client.get("/doubts", headers=classroom["student"])
    assert len(history.json()) == 1


async def test_off_topic_question_has_no_sources(client, classroom):
    events = await ask_stream(
        client, classroom["student"], classroom["chapter"]["id"], "Who won the cricket world cup?"
    )
    assert events[0][1]["sources"] == []
    assert events[-1][1]["concepts"] == []


async def test_feedback_and_insights(client, classroom):
    cid = classroom["chapter"]["id"]
    await ask_stream(client, classroom["student"], cid, "What is photosynthesis?")
    await ask_stream(client, classroom["student"], cid, "Why is cuscuta a parasite?")
    history = (await client.get("/doubts", headers=classroom["student"])).json()
    resp = await client.post(
        f"/doubts/{history[0]['id']}/feedback",
        json={"helpful": False},
        headers=classroom["student"],
    )
    assert resp.json()["helpful"] is False

    room_id = classroom["room"]["id"]
    insights = (
        await client.get(f"/classrooms/{room_id}/insights", headers=classroom["teacher"])
    ).json()
    assert insights["total_doubts"] == 2
    assert insights["active_students"] == 1
    assert insights["helpful_rate"] == 0.0
    concepts = {c["concept"] for c in insights["concepts"]}
    assert {"Photosynthesis", "Parasitic Plants"} <= concepts
    assert insights["recent"][0]["student_name"] == "Asha"


async def test_insights_are_private_to_owning_teacher(client, classroom):
    other = await register(client, "teacher", "other@test.dev")
    room_id = classroom["room"]["id"]
    assert (await client.get(f"/classrooms/{room_id}/insights", headers=other)).status_code == 404
    resp = await client.get(f"/classrooms/{room_id}/insights", headers=classroom["student"])
    assert resp.status_code == 403


async def test_quiz_lifecycle(client, classroom):
    room_id, cid = classroom["room"]["id"], classroom["chapter"]["id"]
    await ask_stream(client, classroom["student"], cid, "What is photosynthesis?")

    resp = await client.post(
        f"/classrooms/{room_id}/quizzes",
        headers=classroom["teacher"],
        json={"chapter_id": cid, "num_questions": 3},
    )
    assert resp.status_code == 201, resp.text
    quiz = resp.json()
    assert len(quiz["questions"]) == 3
    assert "answer_index" not in quiz["questions"][0]  # answer key never reaches students
    # Without explicit focus, the quiz targets what the class asked about.
    assert quiz["questions"][0]["concept"] == "Photosynthesis"

    listed = (
        await client.get(f"/classrooms/{room_id}/quizzes", headers=classroom["student"])
    ).json()
    assert listed[0]["my_score"] is None

    resp = await client.post(
        f"/quizzes/{quiz['id']}/attempts", json={"answers": [0, 0, 0]}, headers=classroom["student"]
    )
    assert resp.status_code == 201
    result = resp.json()
    expected = sum(a == q["answer_index"] for a, q in zip([0, 0, 0], result["review"], strict=True))
    assert result["score"] == expected

    again = await client.post(
        f"/quizzes/{quiz['id']}/attempts", json={"answers": [0, 0, 0]}, headers=classroom["student"]
    )
    assert again.status_code == 409

    results = (
        await client.get(f"/quizzes/{quiz['id']}/results", headers=classroom["teacher"])
    ).json()
    assert results["attempts"][0]["student_name"] == "Asha"
    assert sum(results["per_question_correct"]) == expected


async def test_live_dashboard_receives_doubt_events(classroom):
    """WebSocket feed pushes a student's doubt to the teacher in real time."""
    from starlette.testclient import TestClient

    from app.main import app

    token = classroom["teacher"]["Authorization"].split()[1]
    room_id = classroom["room"]["id"]
    with (
        TestClient(app) as tc,
        tc.websocket_connect(f"/classrooms/{room_id}/live?token={token}") as ws,
    ):
        tc.post(
            "/doubts/ask/stream",
            headers=classroom["student"],
            json={
                "chapter_id": classroom["chapter"]["id"],
                "question": "What are stomata?",
            },
        )
        event = ws.receive_json()
        assert event["type"] == "doubt_created"
        assert event["student_name"] == "Asha"


async def test_quiz_accepts_bare_question_list(client, classroom, monkeypatch):
    """Some models return `[...]` instead of `{"questions": [...]}`; both must work."""
    from app.ai.fake import FakeLLM

    original = FakeLLM.complete_json

    async def bare_list(self, system, prompt, *, task):
        return (await original(self, system, prompt, task=task))["questions"]

    monkeypatch.setattr(FakeLLM, "complete_json", bare_list)
    resp = await client.post(
        f"/classrooms/{classroom['room']['id']}/quizzes",
        headers=classroom["teacher"],
        json={"chapter_id": classroom["chapter"]["id"], "num_questions": 3},
    )
    assert resp.status_code == 201, resp.text
    assert len(resp.json()["questions"]) == 3
