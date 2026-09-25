"""API tests run against a real PostgreSQL (the docker-compose `db` service by default)."""

from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import OperationalError

from app.core.config import get_settings
from app.core.db import SessionLocal
from app.seed import data
from app.seed.loader import load, reset, seed_id


@pytest.fixture(scope="session")
def database():
    url = make_url(get_settings().database_url)
    admin = create_engine(url.set(database="postgres"), isolation_level="AUTOCOMMIT")
    try:
        with admin.connect() as conn:
            exists = conn.scalar(
                text("SELECT 1 FROM pg_database WHERE datname = :n"), {"n": url.database}
            )
            if not exists:
                conn.execute(text(f'CREATE DATABASE "{url.database}"'))
    except OperationalError as e:
        pytest.skip(
            f"PostgreSQL not reachable ({url.host}:{url.port}); run `docker compose up -d db`: {e}"
        )
    finally:
        admin.dispose()
    command.upgrade(Config(str(Path(__file__).parents[2] / "alembic.ini")), "head")


@pytest.fixture(autouse=True)
def clean(database):
    with SessionLocal.begin() as session:
        reset(session)


@pytest.fixture
def client():
    from app.main import app

    return TestClient(app)


@pytest.fixture
def seeded():
    with SessionLocal.begin() as session:
        load(session)


def uid(key: str) -> str:
    return str(seed_id("user", key))


def gid(key: str) -> str:
    return str(seed_id("group", key))


def eid(key: str) -> str:
    return str(seed_id("expense", key))


def cat(key: str) -> str:
    return str(seed_id("category", key))


def login(client: TestClient, key: str) -> dict[str, str]:
    email = next(u.email for u in data.USERS if u.key == key)
    r = client.post("/api/v1/auth/login", json={"email": email, "password": data.DEV_PASSWORD})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def register(client: TestClient, name: str, email: str) -> tuple[dict[str, str], dict]:
    r = client.post(
        "/api/v1/auth/register", json={"name": name, "email": email, "password": "correct-horse"}
    )
    assert r.status_code == 201, r.text
    body = r.json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]
