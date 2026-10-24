"""Goal contributions: to a goal that counts them, from at most one entry of yours, never
counted twice (spec §4.4), and following their entry and their goal when deleted."""

import uuid

import pytest
from sqlalchemy import func, select

from app.core.db import SessionLocal
from app.models import ChangeLog
from app.seed import data
from app.seed.loader import account_id, seed_id
from tests.api.conftest import login, register

API = "/api/v1"
URL = f"{API}/personal/goal-contributions"
GOALS = f"{API}/personal/goals"
TXNS = f"{API}/personal/transactions"
BATCH = f"{API}/personal/batch"
EMERGENCY, LADAKH, GOLD = (
    str(seed_id("goal", f"john:{k}")) for k in ("emergency", "ladakh", "gold")
)
SAVINGS, HDFC, CASH = (
    str(account_id(next(a for a in data.ACCOUNTS if a.key == k)))
    for k in ("savings", "hdfc", "cash")
)
JAR = str(seed_id("goal_contribution", "john:1"))  # from the cash withdrawal
TRIP_SHARE = f"{API}/personal/allocation-rules/{seed_id('allocation_rule', 'john:trip_share')}"
"""The rule sending 10% of each income to Ladakh: it stops the goal being archived or deleted."""


def contribution(goal: str = LADAKH, amount: int = 500_000, **extra) -> dict:
    return {"goal_id": goal, "amount_minor": amount, "date": "2026-09-24", **extra}


def entry(client, h, account: str, amount: int = 1_000_000, type: str = "income") -> dict:
    body = {
        "type": type,
        "amount_minor": amount,
        "description": "Bonus",
        "date": "2026-09-24",
        "account_id": account,
    }
    r = client.post(TXNS, headers=h, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def to_savings(client, h, amount: int = 1_000_000) -> tuple[dict, dict]:
    """A transfer HDFC → Emergency savings: (out leg, in leg)."""
    group = str(uuid.uuid4())

    def leg(direction: str, account: str) -> dict:
        return {
            "kind": "transaction",
            "op": "create",
            "id": str(uuid.uuid4()),
            "transaction": {
                "type": "transfer",
                "direction": direction,
                "account_id": account,
                "transfer_group_id": group,
                "amount_minor": amount,
                "description": "To savings",
                "date": "2026-09-24",
            },
        }

    r = client.post(BATCH, headers=h, json={"items": [leg("out", HDFC), leg("in", SAVINGS)]})
    assert r.status_code == 201, r.text
    out, into = (i["transaction"] for i in r.json()["items"])
    return out, into


def error(r) -> tuple[str, str]:
    assert r.status_code == 422, r.text
    return r.json()["error"]["code"], r.json()["error"]["message"]


def log_count() -> int:
    with SessionLocal() as s:
        return s.scalar(select(func.count()).select_from(ChangeLog))


def test_the_seeded_contributions(client, seeded):
    h = login(client, "john")
    rows = client.get(f"{URL}?goal_id={LADAKH}", headers=h).json()
    assert [(c["amount_minor"], c["date"]) for c in rows] == [
        (200_000, "2026-09-12"),
        (1_500_000, "2026-08-31"),
    ]
    jar, saved = rows
    withdrawal = client.get(f"{TXNS}/{jar['transaction_id']}", headers=h).json()
    assert (withdrawal["description"], withdrawal["direction"], withdrawal["account_id"]) == (
        "Cash withdrawal",
        "in",
        CASH,
    )
    assert saved["transaction_id"] is None and saved["note"] == "Saved before I started tracking"
    assert client.get(f"{URL}?goal_id={GOLD}", headers=h).json() == []


def test_create_edit_delete_and_restore(client, seeded):
    h = login(client, "john")
    r = client.post(URL, headers=h, json=contribution(note="Birthday money"))
    assert r.status_code == 201, r.text
    c = r.json()
    assert (c["currency"], c["transaction_id"], c["version"]) == ("INR", None, 1)
    # The note stays when left out.
    r = client.put(
        f"{URL}/{c['id']}", headers=h, json={**contribution(amount=600_000), "version": 1}
    )
    assert (r.json()["amount_minor"], r.json()["note"], r.json()["version"]) == (
        600_000,
        "Birthday money",
        2,
    )
    assert client.delete(f"{URL}/{c['id']}?version=2", headers=h).json()["deleted_at"]
    assert [x["id"] for x in client.get(f"{URL}?deleted=true", headers=h).json()] == [c["id"]]
    assert client.post(f"{URL}/{c['id']}/restore", headers=h).json()["deleted_at"] is None


@pytest.mark.parametrize(
    ("body", "code", "message"),
    [
        (
            contribution(EMERGENCY),
            "goal_tracks_balance",
            "Emergency fund follows an account's balance, so it takes no contributions",
        ),
        (
            contribution(GOLD),
            "goal_is_manual",
            "Gold coins is tracked by hand, so it takes no contributions",
        ),
        (contribution(str(uuid.uuid4())), "unknown_goal", "That goal isn't available"),
        (
            contribution(transaction_id=str(uuid.uuid4())),
            "unknown_transaction",
            "That entry isn't available",
        ),
        (
            contribution(transaction_id="jar", amount=200_000),
            "already_contributed",
            "That entry already counts toward Ladakh trip",
        ),
    ],
)
def test_what_a_contribution_needs(client, seeded, body, code, message):
    h = login(client, "john")
    if body.get("transaction_id") == "jar":
        body = {
            **body,
            "transaction_id": client.get(f"{URL}/{JAR}", headers=h).json()["transaction_id"],
        }
    assert error(client.post(URL, headers=h, json=body)) == (code, message)


def test_the_goal_and_the_entry_must_allow_it(client, seeded):
    h = login(client, "john")
    bonus = entry(client, h, CASH)
    too_much = contribution(amount=1_000_001, transaction_id=bonus["id"])
    assert error(client.post(URL, headers=h, json=too_much)) == (
        "contribution_too_large",
        "A contribution can't be more than its entry",
    )
    # An entry can't shrink below what it puts into a goal.
    c = client.post(URL, headers=h, json=contribution(transaction_id=bonus["id"])).json()
    edit = {k: bonus[k] for k in ("type", "description", "date", "account_id", "version")}
    r = client.put(f"{TXNS}/{bonus['id']}", headers=h, json={**edit, "amount_minor": 400_000})
    assert error(r) == (
        "contribution_too_large",
        "₹5,000 of this entry counts toward Ladakh trip. Lower that contribution first",
    )
    # A deleted entry or goal, or an archived goal, takes nothing.
    client.delete(f"{URL}/{c['id']}", headers=h)
    client.delete(f"{TXNS}/{bonus['id']}", headers=h)
    r = client.post(URL, headers=h, json=contribution(transaction_id=bonus["id"]))
    assert error(r)[0] == "unknown_transaction"
    client.delete(TRIP_SHARE, headers=h)
    ladakh = client.get(f"{GOALS}/{LADAKH}", headers=h).json()
    client.put(
        f"{GOALS}/{LADAKH}",
        headers=h,
        json={"name": ladakh["name"], "target_minor": ladakh["target_minor"], "status": "archived"},
    )
    assert error(client.post(URL, headers=h, json=contribution())) == (
        "goal_archived",
        "Ladakh trip is archived",
    )
    client.delete(f"{GOALS}/{LADAKH}", headers=h)
    assert error(client.post(URL, headers=h, json=contribution()))[0] == "unknown_goal"


def test_nothing_counts_twice(client, seeded):
    """The emergency fund follows the savings account: money moved into it counts there, so
    it can't also be a contribution, from either leg of the transfer."""
    h = login(client, "john")
    out, into = to_savings(client, h)
    expected = (
        "counted_by_balance",
        "Emergency fund already counts that entry, through the balance of Emergency savings",
    )
    for leg in (into, out):
        r = client.post(URL, headers=h, json=contribution(transaction_id=leg["id"]))
        assert error(r) == expected
    # Moving a contributed entry into the savings account is refused the same way.
    bonus = entry(client, h, CASH)
    client.post(URL, headers=h, json=contribution(transaction_id=bonus["id"]))
    edit = {k: bonus[k] for k in ("type", "description", "date", "amount_minor", "version")}
    r = client.put(f"{TXNS}/{bonus['id']}", headers=h, json={**edit, "account_id": SAVINGS})
    assert error(r) == expected

    # An archived goal counts nothing, so the contribution goes through; unarchiving it then
    # would count the entry twice.
    emergency = client.get(f"{GOALS}/{EMERGENCY}", headers=h).json()
    body = {"name": emergency["name"], "target_minor": emergency["target_minor"]}
    client.put(f"{GOALS}/{EMERGENCY}", headers=h, json={**body, "status": "archived"})
    r = client.post(URL, headers=h, json=contribution(transaction_id=into["id"]))
    assert r.status_code == 201, r.text
    r = client.put(f"{GOALS}/{EMERGENCY}", headers=h, json={**body, "status": "active"})
    assert error(r) == (
        "counted_by_contribution",
        "An entry in Emergency savings already counts toward Ladakh trip",
    )


def test_contributions_follow_their_entry(client, seeded):
    h = login(client, "john")
    jar = client.get(f"{URL}/{JAR}", headers=h).json()
    # Deleting either leg of the cash withdrawal deletes the transfer and the contribution.
    withdrawal = client.get(f"{TXNS}/{jar['transaction_id']}", headers=h).json()
    out = next(
        i
        for i in client.get(f"{TXNS}?type=transfer", headers=h).json()["items"]
        if i["transfer_group_id"] == withdrawal["transfer_group_id"] and i["direction"] == "out"
    )
    client.delete(f"{TXNS}/{out['id']}", headers=h)
    assert client.get(f"{URL}/{JAR}", headers=h).json()["deleted_at"]
    client.post(f"{TXNS}/{out['id']}/restore", headers=h)
    assert client.get(f"{URL}/{JAR}", headers=h).json()["deleted_at"] is None
    with SessionLocal() as s:
        actions = s.scalars(
            select(ChangeLog.action)
            .where(ChangeLog.entity == "personal_goal_contribution")
            .order_by(ChangeLog.seq)
        ).all()
    assert actions == ["personal_goal_contribution.delete", "personal_goal_contribution.restore"]

    # One you deleted yourself stays deleted.
    client.delete(f"{URL}/{JAR}", headers=h)
    client.delete(f"{TXNS}/{out['id']}", headers=h)
    client.post(f"{TXNS}/{out['id']}/restore", headers=h)
    assert client.get(f"{URL}/{JAR}", headers=h).json()["deleted_at"]


def test_contributions_follow_their_goal(client, seeded):
    h = login(client, "john")
    mine = client.post(URL, headers=h, json=contribution()).json()
    client.delete(f"{URL}/{mine['id']}", headers=h)
    client.delete(TRIP_SHARE, headers=h)
    client.delete(f"{GOALS}/{LADAKH}", headers=h)
    assert client.get(f"{URL}?goal_id={LADAKH}", headers=h).json() == []
    r = client.post(f"{URL}/{JAR}/restore", headers=h)
    assert error(r) == (
        "unknown_goal",
        "This contribution's goal was deleted. Restore the goal first",
    )
    client.post(f"{GOALS}/{LADAKH}/restore", headers=h)
    assert len(client.get(f"{URL}?goal_id={LADAKH}", headers=h).json()) == 2  # not `mine`


def _leg(direction: str, account: str, group: str, id: str | None = None) -> dict:
    return {
        "kind": "transaction",
        "op": "create",
        "id": id or str(uuid.uuid4()),
        "transaction": {
            "type": "transfer",
            "direction": direction,
            "account_id": account,
            "transfer_group_id": group,
            "amount_minor": 300_000,
            "description": "For the bike",
            "date": "2026-09-24",
        },
    }


def _new_goal(id: str) -> dict:
    return {
        "kind": "goal",
        "op": "create",
        "id": id,
        "goal": {"name": "Bike", "target_minor": 9_000_000},
    }


def _put_in(goal: str, entry: str | None = None) -> dict:
    return {
        "kind": "goal_contribution",
        "op": "create",
        "id": str(uuid.uuid4()),
        "goal_contribution": contribution(goal, 300_000, transaction_id=entry),
    }


def test_a_transfer_a_goal_and_its_contribution_in_one_batch(client, seeded):
    h = login(client, "john")
    group, into, bike = str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4())
    items = [
        _leg("out", HDFC, group),
        _leg("in", CASH, group, into),
        _new_goal(bike),
        _put_in(bike, into),
    ]
    r = client.post(BATCH, headers=h, json={"items": items})
    assert r.status_code == 201, r.text
    assert [i["kind"] for i in r.json()["items"]] == [
        "transaction",
        "transaction",
        "goal",
        "goal_contribution",
    ]
    assert r.json()["items"][3]["goal_contribution"]["transaction_id"] == into
    # Sent again (a retry), it gives back the same and changes nothing.
    before = log_count()
    again = client.post(BATCH, headers=h, json={"items": items})
    assert (again.status_code, again.json(), log_count()) == (201, r.json(), before)

    # A refusal at the last item keeps nothing.
    other = str(uuid.uuid4())
    refused = [
        _leg("out", HDFC, other),
        _leg("in", CASH, other),
        _new_goal(str(uuid.uuid4())),
        _put_in(EMERGENCY),
    ]
    r = client.post(BATCH, headers=h, json={"items": refused})
    assert (r.json()["error"]["code"], r.json()["error"]["item"]) == ("goal_tracks_balance", 3)
    assert log_count() == before

    # Deletes go in batches too.
    c = client.post(URL, headers=h, json=contribution(bike)).json()
    deletes = [
        {"kind": "goal_contribution", "op": "delete", "id": c["id"], "version": 1},
        {"kind": "goal", "op": "delete", "id": bike, "version": 1},
    ]
    r = client.post(BATCH, headers=h, json={"items": deletes})
    assert r.status_code == 201, r.text
    assert all(i[i["kind"]]["deleted_at"] for i in r.json()["items"])


def test_other_peoples_goals_and_entries_cant_be_used(client, seeded):
    h = login(client, "john")
    other, _ = register(client, "Zoya", "zoya@example.com")
    hers = client.post(GOALS, headers=other, json={"name": "Hers", "target_minor": 100_000}).json()
    assert error(client.post(URL, headers=h, json=contribution(hers["id"])))[0] == "unknown_goal"
    jar = client.get(f"{URL}/{JAR}", headers=h).json()
    r = client.post(
        URL, headers=other, json=contribution(hers["id"], 100, transaction_id=jar["transaction_id"])
    )
    assert error(r)[0] == "unknown_transaction"
    assert client.get(f"{URL}/{JAR}", headers=other).status_code == 404
    assert client.get(URL, headers=other).json() == []
