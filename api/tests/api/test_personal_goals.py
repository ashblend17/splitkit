"""Personal goals: stored and checked on the server, never computed there; private to their
owner; one tracking mode at a time, each with its own field; synced on the owner's stream."""

import uuid

import pytest
from sqlalchemy import select

from app.core.db import SessionLocal
from app.models import ChangeLog
from app.seed import data
from app.seed.loader import account_id, seed_id
from tests.api.conftest import login, register, uid
from tests.api.test_admin import start

API = "/api/v1"
URL = f"{API}/personal/goals"
TOP_UP = str(seed_id("allocation_rule", "john:top_up"))  # sends money to the savings account
EMERGENCY, LADAKH, GOLD = (
    str(seed_id("goal", f"john:{k}")) for k in ("emergency", "ladakh", "gold")
)
SAVINGS, HDFC, CASH = (
    str(account_id(next(a for a in data.ACCOUNTS if a.key == k)))
    for k in ("savings", "hdfc", "cash")
)


def goal(**extra) -> dict:
    return {"name": "New laptop", "target_minor": 12_000_000, **extra}


def log_actions(entity: str) -> list[str]:
    with SessionLocal() as s:
        rows = s.scalars(
            select(ChangeLog.action)
            .where(ChangeLog.stream_id == f"user:{uid('john')}", ChangeLog.entity == entity)
            .order_by(ChangeLog.seq)
        )
        return list(rows)


def test_the_seeded_goals(client, seeded):
    h = login(client, "john")
    goals = client.get(URL, headers=h).json()
    assert [(g["name"], g["tracking_mode"]) for g in goals] == [
        ("Emergency fund", "linked_balance"),
        ("Ladakh trip", "contribution"),
        ("Gold coins", "manual"),
    ]
    emergency, ladakh, gold = goals
    assert (emergency["linked_account_id"], emergency["manual_progress_minor"]) == (SAVINGS, None)
    assert (ladakh["target_date"], ladakh["currency"], ladakh["status"]) == (
        "2027-05-31",
        "INR",
        "active",
    )
    assert (gold["manual_progress_minor"], gold["linked_account_id"]) == (6_800_000, None)
    # Progress is the app's to work out.
    assert not any("progress" in k and k != "manual_progress_minor" for k in ladakh)


def test_create_edit_delete_and_restore(client, seeded):
    h = login(client, "john")
    r = client.post(URL, headers=h, json=goal(target_date="2027-01-31", priority=3))
    assert r.status_code == 201, r.text
    laptop = r.json()
    assert (laptop["tracking_mode"], laptop["status"], laptop["currency"], laptop["version"]) == (
        "contribution",
        "active",
        "INR",
        1,
    )
    # Left out, the date and priority stay; a null status keeps it.
    r = client.put(
        f"{URL}/{laptop['id']}",
        headers=h,
        json={"name": "Laptop", "target_minor": 9_000_000, "version": 1, "status": None},
    )
    assert r.status_code == 200, r.text
    edited = r.json()
    assert (edited["name"], edited["target_date"], edited["priority"], edited["version"]) == (
        "Laptop",
        "2027-01-31",
        3,
        2,
    )
    paused = client.put(
        f"{URL}/{laptop['id']}", headers=h, json={**goal(), "status": "paused", "version": 2}
    ).json()
    assert paused["status"] == "paused"
    stale = client.put(f"{URL}/{laptop['id']}", headers=h, json={**goal(), "version": 1})
    assert (stale.status_code, stale.json()["error"]["code"]) == (409, "version_conflict")

    gone = client.delete(f"{URL}/{laptop['id']}?version=3", headers=h).json()
    assert gone["deleted_at"]
    assert [g["id"] for g in client.get(f"{URL}?deleted=true", headers=h).json()] == [laptop["id"]]
    r = client.put(f"{URL}/{laptop['id']}", headers=h, json=goal())
    assert (r.status_code, r.json()["error"]["code"]) == (409, "deleted")
    assert client.post(f"{URL}/{laptop['id']}/restore", headers=h).json()["deleted_at"] is None
    assert log_actions("personal_goal") == [
        "personal_goal.create",
        "personal_goal.update",
        "personal_goal.update",
        "personal_goal.delete",
        "personal_goal.restore",
    ]


@pytest.mark.parametrize(
    ("body", "code", "message"),
    [
        (
            {"tracking_mode": "linked_balance"},
            "account_required",
            "Pick the account this goal follows",
        ),
        (
            {"linked_account_id": str(uuid.uuid4())},
            "account_not_used",
            "Only a goal that follows an account's balance has an account",
        ),
        ({"tracking_mode": "manual"}, "progress_required", "Say how much is saved so far"),
        (
            {"manual_progress_minor": 0},
            "progress_not_used",
            "Only a goal you track by hand has progress you type",
        ),
        ({"target_minor": 0}, "invalid_input", None),
        ({"target_date": "1999-12-31"}, "invalid_input", "Pick a date between 2000 and 2100"),
        ({"expected_return_bp": -1}, "invalid_input", None),
        (
            {"tracking_mode": "linked_balance", "linked_account_id": str(uuid.uuid4())},
            "unknown_account",
            None,
        ),
    ],
)
def test_what_a_goal_needs(client, seeded, body, code, message):
    r = client.post(URL, headers=login(client, "john"), json=goal(**body))
    assert (r.status_code, r.json()["error"]["code"]) == (422, code)
    if message:
        assert r.json()["error"]["message"] == message


def test_switching_tracking_modes(client, seeded):
    h = login(client, "john")
    gold = client.get(f"{URL}/{GOLD}", headers=h).json()
    body = {"name": gold["name"], "target_minor": gold["target_minor"]}
    # The typed progress goes with the mode that used it.
    r = client.put(f"{URL}/{GOLD}", headers=h, json={**body, "tracking_mode": "contribution"})
    assert (r.json()["tracking_mode"], r.json()["manual_progress_minor"]) == ("contribution", None)
    r = client.put(f"{URL}/{GOLD}", headers=h, json={**body, "tracking_mode": "linked_balance"})
    assert r.json()["error"]["code"] == "account_required"
    # Cash holds the trip jar's money, which counts toward Ladakh already.
    linked = {**body, "tracking_mode": "linked_balance", "linked_account_id": CASH}
    r = client.put(f"{URL}/{GOLD}", headers=h, json=linked)
    assert r.json()["error"] == {
        "code": "counted_by_contribution",
        "message": "An entry in Cash already counts toward Ladakh trip",
    }
    # And the emergency fund follows the savings account.
    r = client.put(f"{URL}/{GOLD}", headers=h, json={**linked, "linked_account_id": SAVINGS})
    assert r.json()["error"] == {
        "code": "account_followed",
        "message": "Emergency fund already follows Emergency savings",
    }
    locker = client.post(
        f"{API}/personal/accounts", headers=h, json={"name": "Locker", "type": "other_asset"}
    ).json()
    r = client.put(f"{URL}/{GOLD}", headers=h, json={**linked, "linked_account_id": locker["id"]})
    assert r.status_code == 200, r.text
    assert (r.json()["tracking_mode"], r.json()["linked_account_id"]) == (
        "linked_balance",
        locker["id"],
    )
    # Back to manual: the account goes, the progress is needed again.
    r = client.put(f"{URL}/{GOLD}", headers=h, json={**body, "tracking_mode": "manual"})
    assert r.json()["error"]["code"] == "progress_required"
    r = client.put(
        f"{URL}/{GOLD}",
        headers=h,
        json={**body, "tracking_mode": "manual", "manual_progress_minor": 7_000_000},
    )
    assert (r.json()["linked_account_id"], r.json()["manual_progress_minor"]) == (None, 7_000_000)


def test_the_followed_account(client, seeded):
    h = login(client, "john")
    accounts = f"{API}/personal/accounts"
    # Someone else's account isn't available; nor is one in another currency.
    other, _ = register(client, "Zoya", "zoya@example.com")
    hers = client.post(accounts, headers=other, json={"name": "Hers", "type": "bank"}).json()
    linked = goal(tracking_mode="linked_balance", linked_account_id=hers["id"])
    assert client.post(URL, headers=h, json=linked).json()["error"]["code"] == "unknown_account"
    client.patch(f"{API}/me", headers=h, json={"currency": "USD"})
    usd = client.post(accounts, headers=h, json={"name": "Chase", "type": "bank"}).json()
    client.patch(f"{API}/me", headers=h, json={"currency": "INR"})
    r = client.post(URL, headers=h, json={**linked, "linked_account_id": usd["id"]})
    assert r.json()["error"] == {
        "code": "currency_mismatch",
        "message": "That account is in USD; this goal is in INR",
    }

    # A followed account can't be deleted (nor one a rule sends money to); once its goal is, it
    # can, and the goal can't come back until the account does.
    r = client.delete(f"{accounts}/{SAVINGS}", headers=h)
    assert r.json()["error"]["code"] == "rule_points_here"
    client.delete(f"{API}/personal/allocation-rules/{TOP_UP}", headers=h)
    r = client.delete(f"{accounts}/{SAVINGS}", headers=h)
    assert r.json()["error"] == {
        "code": "account_in_use",
        "message": "A goal follows this account's balance, so it can't be deleted",
    }
    client.delete(f"{URL}/{EMERGENCY}", headers=h)
    assert client.delete(f"{accounts}/{SAVINGS}", headers=h).status_code == 200
    r = client.post(f"{URL}/{EMERGENCY}/restore", headers=h)
    assert r.json()["error"]["code"] == "unknown_account"
    client.post(f"{accounts}/{SAVINGS}/restore", headers=h)
    assert client.post(f"{URL}/{EMERGENCY}/restore", headers=h).status_code == 200


def test_other_people_cant_see_or_change_a_goal(client, seeded):
    other, _ = register(client, "Zoya", "zoya@example.com")
    assert client.get(URL, headers=other).json() == []
    for method, path in [
        ("GET", f"{URL}/{LADAKH}"),
        ("PUT", f"{URL}/{LADAKH}"),
        ("DELETE", f"{URL}/{LADAKH}"),
        ("POST", f"{URL}/{LADAKH}/restore"),
    ]:
        r = client.request(method, path, headers=other, json=goal() if method == "PUT" else None)
        assert (r.status_code, r.json()["error"]["code"]) == (404, "not_found"), method


def test_goals_sync_on_the_owners_stream(client, seeded):
    h = login(client, "john")
    laptop = client.post(URL, headers=h, json=goal()).json()
    with SessionLocal() as s:
        [row] = s.scalars(select(ChangeLog).where(ChangeLog.entity == "personal_goal")).all()
    assert (row.stream_id, str(row.entity_id), row.version) == (
        f"user:{uid('john')}",
        laptop["id"],
        1,
    )
    snap = client.get(f"{API}/sync/snapshot/user:{uid('john')}", headers=h).json()
    goals = {e["entity_id"]: e["data"] for e in snap["entities"] if e["entity"] == "personal_goal"}
    assert len(goals) == len(data.GOALS) + 1 and goals[laptop["id"]] == row.data
    kinds = [e["entity"] for e in snap["entities"]]
    assert kinds.count("personal_goal_contribution") == len(data.CONTRIBUTIONS)


def test_read_only_view_as_cant_write_goals(client, seeded):
    _, as_rahul = start(client, login(client, "john"))
    for path in (URL, f"{API}/personal/goal-contributions"):
        r = client.post(path, headers=as_rahul, json=goal())
        assert (r.status_code, r.json()["error"]["code"]) == (403, "read_only")
