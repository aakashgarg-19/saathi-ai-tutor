from tests.conftest import register


async def test_register_login_me(client):
    headers = await register(client, "student", "a@test.dev", "Asha")
    me = await client.get("/auth/me", headers=headers)
    assert me.json()["role"] == "student"

    resp = await client.post("/auth/login", json={"email": "A@test.dev", "password": "secret123"})
    assert resp.status_code == 200
    assert resp.json()["user"]["email"] == "a@test.dev"


async def test_duplicate_email_rejected(client):
    await register(client, "student", "a@test.dev")
    resp = await client.post(
        "/auth/register",
        json={
            "name": "Other",
            "email": "a@test.dev",
            "password": "secret123",
            "role": "teacher",
        },
    )
    assert resp.status_code == 409


async def test_wrong_password_and_bad_token(client):
    await register(client, "student", "a@test.dev")
    resp = await client.post("/auth/login", json={"email": "a@test.dev", "password": "nope123"})
    assert resp.status_code == 401
    resp = await client.get("/auth/me", headers={"Authorization": "Bearer garbage"})
    assert resp.status_code == 401


async def test_role_guard(client):
    student = await register(client, "student", "a@test.dev")
    resp = await client.post("/classrooms", json={"name": "X", "grade": 7}, headers=student)
    assert resp.status_code == 403
