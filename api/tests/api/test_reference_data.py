"""System categories and default dashboards come from migration 0009, not only the demo seed."""

import importlib.util
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import func, select

from app.core.db import SessionLocal
from app.models import AnalyticsConfiguration, Category
from app.seed import data, loader
from tests.api.conftest import login

ROOT = Path(__file__).parents[2]


def _migration(name: str = "0009_reference_data"):
    path = ROOT / f"migrations/versions/{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_the_migrations_and_the_seed_agree():
    m, cards = _migration(), _migration("0011_personal_insight_cards")
    assert m._NAMESPACE == loader._NAMESPACE == cards._NAMESPACE
    assert m.CATEGORIES == [(c.key, c.label, c.icon, c.scope, c.sort) for c in data.CATEGORIES]
    assert sorted(m.DASHBOARDS + cards.CARDS) == sorted(
        (a.scope, a.position, a.type, a.title, a.period, a.source, a.params) for a in data.ANALYTICS
    )
    assert {cards._id(s, p) for s, p, *_ in cards.CARDS} == {
        str(loader.seed_id("analytics", f"{s}:{p}")) for s, p, *_ in cards.CARDS
    }


def test_an_unseeded_database_gets_categories_and_dashboards(client):
    cfg = Config(str(ROOT / "alembic.ini"))
    command.downgrade(cfg, "0008_tricount_sync")
    command.upgrade(cfg, "head")  # into the empty tables `clean` left
    with SessionLocal() as s:
        count = lambda model: s.scalar(select(func.count()).select_from(model))  # noqa: E731
        assert count(Category) == len(data.CATEGORIES)
        assert count(AnalyticsConfiguration) == len(data.ANALYTICS)

    # A first user signs up and has something to pick and something to look at.
    r = client.post(
        "/api/v1/auth/register",
        json={"name": "Neha", "email": "neha@example.com", "password": "long enough pw"},
    )
    assert r.status_code == 201, r.text
    h = {"Authorization": f"Bearer {r.json()['access_token']}"}
    keys = {c["key"] for c in client.get("/api/v1/categories", headers=h).json()}
    assert keys >= {"food", "other"}
    cards = client.get("/api/v1/analytics/personal?period=week", headers=h).json()["cards"]
    assert [c["title"] for c in cards][0] == "Spending over time"


def test_reseeding_replaces_them_in_place(client):
    cfg = Config(str(ROOT / "alembic.ini"))
    command.downgrade(cfg, "0008_tricount_sync")
    command.upgrade(cfg, "head")
    with SessionLocal.begin() as s:
        loader.load(s)  # no --reset: the seed's own copies take over
    h = login(client, "john")
    assert len(client.get("/api/v1/categories", headers=h).json()) >= len(data.CATEGORIES)
