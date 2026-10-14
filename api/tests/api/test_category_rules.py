"""Categories learned from what you choose (categories/rules.py), synced on your user stream."""

import uuid

from sqlalchemy import select

from app.core.db import SessionLocal
from app.modules.categories.models import CategoryRule
from app.modules.categories.rules import pattern_of, rule_id
from app.modules.sync.models import ChangeLog
from tests.api.conftest import cat, gid, login, uid

API = "/api/v1"


def rules(user: str) -> dict[str, tuple[str, bool]]:
    """pattern -> (category id, income) for a user's rules."""
    with SessionLocal() as s:
        rows = s.scalars(select(CategoryRule).where(CategoryRule.user_id == uuid.UUID(uid(user))))
        return {r.pattern: (str(r.category_id), r.income) for r in rows}


def rule_log(user: str) -> list[tuple[str, str]]:
    with SessionLocal() as s:
        rows = s.scalars(
            select(ChangeLog)
            .where(ChangeLog.stream_id == f"user:{uid(user)}", ChangeLog.entity == "category_rule")
            .order_by(ChangeLog.seq)
        )
        return [(r.op, (r.data or {}).get("pattern")) for r in rows]


def entry(**extra):
    return {
        "type": "expense",
        "amount_minor": 45000,
        "description": "Dinner",
        "date": "2026-09-20",
        **extra,
    }


def test_a_manual_entry_teaches_its_merchant_or_description(client, seeded):
    h = login(client, "ansh")
    client.post(f"{API}/personal/transactions", headers=h, json=entry(category_id=cat("food")))
    client.post(
        f"{API}/personal/transactions",
        headers=h,
        json=entry(description="Lunch", merchant="  ZOMATO   LIMITED ", category_id=cat("food")),
    )
    client.post(
        f"{API}/personal/transactions",
        headers=h,
        json=entry(type="income", description="Rent share", category_id=cat("income")),
    )
    client.post(f"{API}/personal/transactions", headers=h, json=entry(description="No category"))
    assert rules("ansh") == {
        "dinner": (cat("food"), False),
        "zomato limited": (cat("food"), False),
        "rent share": (cat("income"), True),
    }
    assert [p for _, p in rule_log("ansh")] == ["dinner", "zomato limited", "rent share"]


def test_categories_the_app_guessed_for_sms_teach_nothing_until_you_change_one(client, seeded):
    h = login(client, "ansh")
    sms = entry(
        description="Darcan Global",
        merchant="DARCAN GLOBAL",
        category_id=cat("shopping"),
        source="sms",
        reviewed=False,
    )
    t = client.post(f"{API}/personal/transactions", headers=h, json=sms).json()
    batch = client.post(
        f"{API}/personal/transactions/batch",
        headers=h,
        json={"items": [{**sms, "reference": "123456789012"}]},
    )
    assert batch.status_code == 201, batch.text
    assert rules("ansh") == {}

    # Looking at it changes nothing; picking another category teaches it.
    client.put(
        f"{API}/personal/transactions/{t['id']}",
        headers=h,
        json={**sms, "reviewed": True, "version": 1},
    )
    assert rules("ansh") == {}
    client.put(
        f"{API}/personal/transactions/{t['id']}",
        headers=h,
        json={**sms, "category_id": cat("food"), "version": 2},
    )
    assert rules("ansh") == {"darcan global": (cat("food"), False)}


def test_choosing_again_moves_the_rule_and_keeps_its_id(client, seeded):
    h = login(client, "ansh")
    t = client.post(
        f"{API}/personal/transactions",
        headers=h,
        json=entry(merchant="KFC", category_id=cat("shopping")),
    ).json()
    client.put(
        f"{API}/personal/transactions/{t['id']}",
        headers=h,
        json=entry(merchant="KFC", category_id=cat("food"), version=1),
    )
    assert rules("ansh") == {"kfc": (cat("food"), False)}
    with SessionLocal() as s:
        (rule,) = s.scalars(select(CategoryRule))
        assert rule.id == rule_id(uuid.UUID(uid("ansh")), False, "kfc")
    assert rule_log("ansh") == [("upsert", "kfc"), ("upsert", "kfc")]


def test_splits_teach_their_description(client, seeded):
    h = login(client, "ansh")
    body = {
        "description": "Swiggy order",
        "amount_minor": 90000,
        "payer_id": uid("ansh"),
        "date": "2026-09-24",
        "category_id": cat("food"),
        "split": {
            "method": "equal",
            "inputs": [{"user_id": uid("ansh")}, {"user_id": uid("aman")}],
        },
    }
    e = client.post(f"{API}/groups/{gid('flat')}/expenses", headers=h, json=body).json()
    assert rules("ansh") == {"swiggy order": (cat("food"), False)}
    # An edit that leaves the category alone teaches nothing more.
    client.put(
        f"{API}/expenses/{e['id']}", headers=h, json={**body, "amount_minor": 80000, "version": 1}
    )
    assert len(rule_log("ansh")) == 1
    client.put(
        f"{API}/expenses/{e['id']}",
        headers=h,
        json={**body, "category_id": cat("shopping"), "version": 2},
    )
    assert rules("ansh") == {"swiggy order": (cat("shopping"), False)}


def test_rules_are_in_the_user_snapshot_and_go_with_their_category(client, seeded):
    h = login(client, "ansh")
    mine = client.post(
        f"{API}/categories",
        headers=h,
        json={"label": "Pets", "icon": "health", "scope": "personal"},
    ).json()
    t = client.post(
        f"{API}/personal/transactions",
        headers=h,
        json=entry(merchant="Heads Up For Tails", category_id=mine["id"]),
    ).json()
    snap = client.get(f"{API}/sync/snapshot/user:{uid('ansh')}", headers=h).json()
    learned = [e for e in snap["entities"] if e["entity"] == "category_rule"]
    assert [(e["data"]["pattern"], e["data"]["category_id"]) for e in learned] == [
        ("heads up for tails", mine["id"])
    ]

    # The category can go once nothing uses it, and its rules go with it.
    client.put(
        f"{API}/personal/transactions/{t['id']}",
        headers=h,
        json=entry(merchant="Heads Up For Tails", version=1),
    )
    assert client.delete(f"{API}/categories/{mine['id']}", headers=h).status_code == 204
    assert rules("ansh") == {}
    assert rule_log("ansh")[-1] == ("delete", None)


def test_the_pattern_and_id_match_the_app():
    # app/test/core/category_rules_test.dart checks the same values.
    assert pattern_of("  Zomato \t LIMITED ") == "zomato limited"
    user = uuid.UUID("332ab8e1-bd10-4aba-b102-000fde14e5ee")
    assert str(rule_id(user, False, "zomato limited")) == "31ea0691-c685-5452-9ae5-6dac2475cabf"
