"""System categories and default dashboards come from migrations (0009, 0011 and 0018), not
only the demo seed."""

import importlib.util
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import func, select

from app.core.db import SessionLocal
from app.models import AnalyticsConfiguration, Category
from app.seed import data, loader
from tests.api.conftest import login, uid

ROOT = Path(__file__).parents[2]


def _migration(name: str = "0009_reference_data"):
    path = ROOT / f"migrations/versions/{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_the_migrations_and_the_seed_agree():
    m, cards = _migration(), _migration("0011_personal_insight_cards")
    finance = _migration("0018_finance_insight_cards")
    assert m._NAMESPACE == loader._NAMESPACE == cards._NAMESPACE == finance._NAMESPACE
    assert m.CATEGORIES == [(c.key, c.label, c.icon, c.scope, c.sort) for c in data.CATEGORIES]
    assert sorted(m.DASHBOARDS + cards.CARDS + finance.CARDS) == sorted(
        (a.scope, a.position, a.type, a.title, a.period, a.source, a.params) for a in data.ANALYTICS
    )
    for added in (cards, finance):
        assert {added._id(s, p) for s, p, *_ in added.CARDS} == {
            str(loader.seed_id("analytics", f"{s}:{p}")) for s, p, *_ in added.CARDS
        }
    assert _migration("0013_personal_ledger").KINDS == {c.key: c.kind for c in data.CATEGORIES}


def test_an_unseeded_database_gets_categories_and_dashboards(client):
    cfg = Config(str(ROOT / "alembic.ini"))
    command.downgrade(cfg, "0008_tricount_sync")
    command.upgrade(cfg, "head")  # into the empty tables `clean` left
    with SessionLocal() as s:
        count = lambda model: s.scalar(select(func.count()).select_from(model))  # noqa: E731
        assert count(Category) == len(data.CATEGORIES)
        assert count(AnalyticsConfiguration) == len(data.ANALYTICS)
        kinds = dict(s.execute(select(Category.key, Category.kind)).all())
        assert kinds == {c.key: c.kind for c in data.CATEGORIES}

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


def test_the_finance_cards_come_and_go_with_0018(client, seeded):
    """Downgrading takes the two default cards away, and the copies people saved (an older
    server can't draw them); upgrading brings the defaults back."""
    h = login(client, "john")
    layout = client.get("/api/v1/analytics/layout/personal", headers=h).json()["cards"]
    assert [c["source"] for c in layout[7:]] == ["personal_savings_rate", "personal_need_want"]
    mine = [layout[0], layout[7], layout[8]]
    r = client.put("/api/v1/analytics/layout/personal", headers=h, json={"cards": mine})
    assert r.status_code == 200, r.text
    finance = _migration("0018_finance_insight_cards")
    sources = {source for *_, source, _ in finance.CARDS}

    def cards() -> list[tuple[str | None, str]]:
        with SessionLocal() as s:
            rows = s.execute(
                select(AnalyticsConfiguration.owner_id, AnalyticsConfiguration.source).where(
                    AnalyticsConfiguration.scope == "personal"
                )
            ).all()
        return [(str(o) if o else None, src) for o, src in rows]

    cfg = Config(str(ROOT / "alembic.ini"))
    command.downgrade(cfg, "0017_personal_reminders")
    left = cards()
    assert not {src for _, src in left} & sources
    assert (uid("john"), "personal_monthly") in left and len(left) == 7 + 1
    command.upgrade(cfg, "head")
    assert sorted(src for o, src in cards() if o is None) == sorted(
        a.source for a in data.ANALYTICS if a.scope == "personal"
    )
