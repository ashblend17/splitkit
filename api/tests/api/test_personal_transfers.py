"""Transfers: two legs between your accounts, made and changed together, never income or
spending; and the other moves (balance corrections)."""

import uuid

import pytest
from sqlalchemy import select

from app.core.db import SessionLocal
from app.models import ChangeLog
from app.seed import data
from app.seed.loader import account_id
from tests.api.conftest import cat, eid, login, uid

API = "/api/v1"
TXNS = f"{API}/personal/transactions"
BATCH = f"{API}/personal/batch"
HDFC, CARD, CASH = (
    str(account_id(next(a for a in data.ACCOUNTS if a.key == k)))
    for k in ("hdfc", "icici_card", "cash")
)


def leg(direction: str, account: str, group: str, amount: int = 200000, **extra) -> dict:
    return {
        "type": "transfer",
        "direction": direction,
        "account_id": account,
        "transfer_group_id": group,
        "amount_minor": amount,
        "description": "Cash withdrawal",
        "date": "2026-09-24",
        **extra,
    }


def create(body: dict, id: str | None = None) -> dict:
    return {
        "kind": "transaction",
        "op": "create",
        "id": id or str(uuid.uuid4()),
        "transaction": body,
    }


def pair(group: str | None = None, **out_extra) -> list[dict]:
    group = group or str(uuid.uuid4())
    return [create(leg("out", HDFC, group, **out_extra)), create(leg("in", CASH, group))]


def september(client, h) -> tuple:
    s = client.get(f"{API}/personal/summary?month=2026-09-23", headers=h).json()
    listed = client.get(f"{TXNS}?start=2026-09-01&end=2026-09-30", headers=h).json()
    return (s["spent_minor"], s["income_minor"], s["by_category"]), (
        listed["spent_minor"],
        listed["income_minor"],
    )


def seed_legs(client, h) -> list[dict]:
    """The seeded card bill: HDFC out, card in."""
    items = client.get(f"{TXNS}?type=transfer", headers=h).json()["items"]
    return sorted(
        (i for i in items if i["description"] == "Credit card bill"), key=lambda i: i["direction"]
    )[::-1]


def user_log(n: int) -> list[ChangeLog]:
    with SessionLocal() as s:
        rows = s.scalars(
            select(ChangeLog)
            .where(ChangeLog.stream_id == f"user:{uid('john')}")
            .order_by(ChangeLog.seq.desc())
            .limit(n)
        )
        return list(rows)[::-1]


def test_a_transfer_is_two_legs_in_one_batch(client, seeded):
    h = login(client, "john")
    before = september(client, h)
    r = client.post(BATCH, headers=h, json={"items": pair()})
    assert r.status_code == 201, r.text
    out, into = (i["transaction"] for i in r.json()["items"])
    assert (out["direction"], out["account_id"], into["direction"], into["account_id"]) == (
        "out",
        HDFC,
        "in",
        CASH,
    )
    assert out["transfer_group_id"] == into["transfer_group_id"]
    assert out["category"] is None and out["counted"]
    # Neither income nor spending.
    assert september(client, h) == before
    assert [(r.entity, r.action) for r in user_log(2)] == [
        ("personal_transaction", "personal.create"),
        ("personal_transaction", "personal.create"),
    ]
    # The seeded ones too.
    assert len(client.get(f"{TXNS}?type=transfer", headers=h).json()["items"]) == 6


def test_one_leg_alone_is_refused(client, seeded):
    h = login(client, "john")
    r = client.post(TXNS, headers=h, json=leg("out", HDFC, str(uuid.uuid4())))
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "transfer_unpaired"
    assert r.json()["error"]["message"] == (
        "A transfer needs both halves in one request (POST /personal/batch)"
    )


@pytest.mark.parametrize(
    ("change", "message"),
    [
        ({"amount": 150000}, "Both halves of a transfer must be the same amount"),
        ({"account_id": CASH}, "A transfer moves money between two different accounts"),
        ({"direction": "in"}, "One half goes out and the other comes in"),
    ],
)
def test_the_legs_must_match(client, seeded, change, message):
    h = login(client, "john")
    group = str(uuid.uuid4())
    first = leg(change.get("direction", "out"), change.get("account_id", HDFC), group)
    first["amount_minor"] = change.get("amount", 200000)
    r = client.post(
        BATCH, headers=h, json={"items": [create(first), create(leg("in", CASH, group))]}
    )
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "transfer_invalid"
    assert r.json()["error"]["message"] == message
    assert r.json()["error"]["item"] == 0
    assert len(client.get(f"{TXNS}?type=transfer", headers=h).json()["items"]) == 4


def test_a_leg_alone_can_be_retold_but_not_changed(client, seeded):
    h = login(client, "john")
    out, into = seed_legs(client, h)
    body = {k: out[k] for k in ("type", "direction", "amount_minor", "date", "account_id")}
    body |= {"transfer_group_id": out["transfer_group_id"], "version": out["version"]}

    r = client.put(f"{TXNS}/{out['id']}", headers=h, json={**body, "description": "Card bill"})
    assert r.status_code == 200, r.text
    assert r.json()["description"] == "Card bill" and r.json()["direction"] == "out"
    body["version"] = r.json()["version"]
    # Without a direction, a leg keeps its own.
    r = client.put(
        f"{TXNS}/{out['id']}", headers=h, json={**body, "direction": None, "description": "Bill"}
    )
    assert r.json()["direction"] == "out"
    body["version"] = r.json()["version"]

    r = client.put(
        f"{TXNS}/{out['id']}",
        headers=h,
        json={**body, "description": "Bill", "amount_minor": 100},
    )
    assert (r.status_code, r.json()["error"]["code"]) == (422, "transfer_invalid")
    r = client.put(
        f"{TXNS}/{out['id']}",
        headers=h,
        json={**body, "description": "Bill", "type": "expense", "transfer_group_id": None},
    )
    assert r.json()["error"] == {
        "code": "transfer_unpaired",
        "message": "Change both halves of a transfer together",
        "transfer_group_id": out["transfer_group_id"],
    }
    assert client.get(f"{TXNS}/{into['id']}", headers=h).json()["version"] == into["version"]


def test_deleting_a_leg_deletes_the_transfer(client, seeded):
    h = login(client, "john")
    out, into = seed_legs(client, h)
    r = client.delete(f"{TXNS}/{into['id']}?version={into['version']}", headers=h)
    assert r.status_code == 200 and r.json()["deleted_at"]
    partner = client.get(f"{TXNS}/{out['id']}", headers=h).json()
    assert partner["deleted_at"] and partner["version"] == out["version"] + 1
    assert {(r.entity_id.hex, r.action) for r in user_log(2)} == {
        (uuid.UUID(out["id"]).hex, "personal.delete"),
        (uuid.UUID(into["id"]).hex, "personal.delete"),
    }
    r = client.post(f"{TXNS}/{out['id']}/restore", headers=h)
    assert r.status_code == 200 and r.json()["deleted_at"] is None
    assert client.get(f"{TXNS}/{into['id']}", headers=h).json()["deleted_at"] is None
    assert [r.action for r in user_log(2)] == ["personal.restore", "personal.restore"]


def test_two_entries_become_a_transfer_and_back(client, seeded):
    """Two entries the bank told about separately are paired, then unpaired: one goes back to
    being spending, the other (made in the app) is deleted, in one batch."""
    h = login(client, "john")
    spend = {"amount_minor": 50000, "date": "2026-09-24", "category_id": cat("other")}
    a = client.post(
        TXNS,
        headers=h,
        json={**spend, "type": "expense", "description": "To ICICI", "account_id": HDFC},
    ).json()
    b = client.post(
        TXNS,
        headers=h,
        json={**spend, "type": "income", "description": "From HDFC", "account_id": CARD},
    ).json()
    group = str(uuid.uuid4())

    def as_leg(entry: dict, direction: str) -> dict:
        return {
            "kind": "transaction",
            "op": "update",
            "id": entry["id"],
            "version": entry["version"],
            "transaction": {
                **leg(direction, entry["account_id"], group, entry["amount_minor"]),
                "description": entry["description"],
            },
        }

    r = client.post(BATCH, headers=h, json={"items": [as_leg(a, "out"), as_leg(b, "in")]})
    assert r.status_code == 201, r.text
    a2, b2 = (i["transaction"] for i in r.json()["items"])
    assert (a2["type"], a2["category"], b2["type"], b2["direction"]) == (
        "transfer",
        None,
        "transfer",
        "in",
    )
    back = {
        "type": "expense",
        "amount_minor": 50000,
        "date": "2026-09-24",
        "description": "To ICICI",
        "account_id": HDFC,
        "transfer_group_id": None,
    }
    r = client.post(
        BATCH,
        headers=h,
        json={
            "items": [
                {
                    "kind": "transaction",
                    "op": "update",
                    "id": a["id"],
                    "version": a2["version"],
                    "transaction": back,
                },
                {"kind": "transaction", "op": "delete", "id": b["id"], "version": b2["version"]},
            ]
        },
    )
    assert r.status_code == 201, r.text
    kept, gone = (i["transaction"] for i in r.json()["items"])
    assert (kept["type"], kept["direction"], kept["transfer_group_id"]) == ("expense", "out", None)
    assert gone["deleted_at"]


GROUP = str(uuid.uuid4())


@pytest.mark.parametrize(
    ("body", "code", "message"),
    [
        (
            {
                "type": "transfer",
                "direction": "out",
                "transfer_group_id": GROUP,
                "category_id": cat("other"),
            },
            "category_not_allowed",
            "Transfers and balance corrections don't have a category",
        ),
        (
            {"type": "adjustment", "direction": "in", "expense_id": eid("goa_uber")},
            "link_invalid",
            "Only spending and income can be linked to Split",
        ),
        (
            {"type": "expense", "direction": "in"},
            "direction_invalid",
            "An expense is money going out",
        ),
        (
            {"type": "refund", "direction": "out"},
            "direction_invalid",
            "A refund is money coming in",
        ),
        ({"type": "adjustment"}, "direction_required", "Say whether money came in or went out"),
        (
            {"type": "adjustment", "direction": "in", "account_id": None},
            "account_required",
            "Pick the account to correct",
        ),
        (
            {"type": "transfer", "direction": "out"},
            "transfer_invalid",
            "Give both halves of a transfer the same transfer_group_id",
        ),
        (
            {
                "type": "transfer",
                "direction": "out",
                "transfer_group_id": GROUP,
                "account_id": None,
            },
            "transfer_invalid",
            "A transfer needs an account on each side",
        ),
        (
            {"type": "expense", "transfer_group_id": GROUP},
            "transfer_invalid",
            "Only a transfer has a transfer_group_id",
        ),
        (
            {"type": "expense", "refund_of_id": str(uuid.uuid4())},
            "refund_invalid",
            "Only a refund can point at a spend",
        ),
    ],
)
def test_what_each_type_allows(client, seeded, body, code, message):
    h = login(client, "john")
    base = {"amount_minor": 1000, "description": "Entry", "date": "2026-09-24", "account_id": HDFC}
    r = client.post(TXNS, headers=h, json={**base, **body})
    assert r.status_code == 422, r.text
    assert (r.json()["error"]["code"], r.json()["error"]["message"]) == (code, message)


def test_a_balance_correction_isnt_spending(client, seeded):
    h = login(client, "john")
    before = september(client, h)
    r = client.post(
        TXNS,
        headers=h,
        json={
            "type": "adjustment",
            "direction": "out",
            "account_id": HDFC,
            "amount_minor": 6_114_500,
            "description": "Bank says ₹39,936",
            "date": "2026-09-23",
        },
    )
    assert r.status_code == 201, r.text
    assert (r.json()["type"], r.json()["direction"], r.json()["account_id"]) == (
        "adjustment",
        "out",
        HDFC,
    )
    assert september(client, h) == before
