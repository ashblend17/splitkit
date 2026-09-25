from tests.api.conftest import login, register

API = "/api/v1"


def test_register_login_and_me(client):
    headers, user = register(client, "Meera", "Meera@Example.com")
    assert user["email"] == "meera@example.com" and user["role"] == "user"
    assert client.get(f"{API}/me", headers=headers).json()["name"] == "Meera"

    r = client.post(
        f"{API}/auth/login", json={"email": "meera@example.com", "password": "correct-horse"}
    )
    assert r.status_code == 200 and r.json()["token_type"] == "bearer"


def test_duplicate_email_is_rejected(client):
    register(client, "Meera", "meera@example.com")
    r = client.post(
        f"{API}/auth/register",
        json={"name": "M", "email": "MEERA@example.com", "password": "12345678"},
    )
    assert r.status_code == 409
    assert r.json()["error"] == {
        "code": "email_taken",
        "message": "An account with this email already exists",
    }


def test_wrong_password(client):
    register(client, "Meera", "meera@example.com")
    r = client.post(
        f"{API}/auth/login", json={"email": "meera@example.com", "password": "nope-nope"}
    )
    assert r.status_code == 401 and r.json()["error"]["code"] == "bad_credentials"


def test_short_password_is_a_validation_error(client):
    r = client.post(
        f"{API}/auth/register", json={"name": "M", "email": "m@example.com", "password": "short"}
    )
    assert r.status_code == 422


def test_protected_routes_need_a_valid_token(client):
    assert client.get(f"{API}/me").status_code == 401
    r = client.get(f"{API}/me", headers={"Authorization": "Bearer not-a-token"})
    assert r.status_code == 401 and r.json()["error"]["message"] == "Please log in again"


def test_update_me(client):
    headers, _ = register(client, "Meera", "meera@example.com")
    r = client.patch(f"{API}/me", headers=headers, json={"name": "Meera K", "currency": "INR"})
    assert r.status_code == 200 and r.json()["name"] == "Meera K"


def test_seeded_admin_can_log_in(client, seeded):
    me = client.get(f"{API}/me", headers=login(client, "ansh")).json()
    assert (me["name"], me["role"]) == ("Ansh C", "admin")
