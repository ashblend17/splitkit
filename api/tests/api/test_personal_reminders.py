"""Reminders: only your decisions are stored (one per dedup key, ever, with an id every device
makes the same), and monthly SIP schedules that remind and never record anything."""

import json
import uuid
from pathlib import Path

import pytest
from sqlalchemy import func, select

from app.core.db import SessionLocal
from app.models import ChangeLog
from app.modules.personal import ledger_rules
from app.seed import data
from app.seed.loader import seed_id
from tests.api.conftest import login, register, uid
from tests.api.test_admin import start

API = "/api/v1"
STATES = f"{API}/personal/reminder-states"
SCHEDULES = f"{API}/personal/reminder-schedules"
GOALS = f"{API}/personal/goals"
LADAKH, GOLD = (str(seed_id("goal", f"john:{k}")) for k in ("ladakh", "gold"))
NIFTY = str(seed_id("holding", "john:nifty"))
VECTORS = json.loads(
    (Path(__file__).parents[3] / "shared" / "ledger_vectors.json").read_text(encoding="utf-8")
)
KEY = f"plan_outstanding:{uuid.uuid4()}"


def error(r) -> tuple[str, str]:
    assert r.status_code in (409, 422), r.text
    return r.json()["error"]["code"], r.json()["error"]["message"]


def log_count() -> int:
    with SessionLocal() as s:
        return s.scalar(select(func.count()).select_from(ChangeLog))


@pytest.mark.parametrize("case", VECTORS["reminder_state_ids"], ids=lambda c: c["dedup_key"])
def test_reminder_state_id_vectors(case):
    assert uuid.UUID(VECTORS["reminder_namespace"]) == ledger_rules.REMINDER_NAMESPACE
    assert ledger_rules.reminder_state_id(case["user_id"], case["dedup_key"]) == uuid.UUID(
        case["id"]
    )


def test_the_seeded_decision_and_schedule(client, seeded):
    h = login(client, "john")
    [dismissed] = client.get(STATES, headers=h).json()
    assert dismissed["dedup_key"] == f"goal_behind:{LADAKH}:2026-09"
    assert (dismissed["id"], dismissed["status"]) == (
        VECTORS["reminder_state_ids"][0]["id"],
        "dismissed",
    )
    [sip] = client.get(SCHEDULES, headers=h).json()
    assert (sip["holding_id"], sip["day_of_month"], sip["amount_minor"], sip["active"]) == (
        NIFTY,
        5,
        500_000,
        True,
    )
    # No due date: the app works out the next one.
    assert "next_due" not in sip and "due_at" not in sip


def test_a_decision_is_made_or_replaced_by_its_key(client, seeded):
    h = login(client, "john")
    expected = str(ledger_rules.reminder_state_id(uid("john"), KEY))
    r = client.post(
        STATES,
        headers=h,
        json={"dedup_key": KEY, "status": "snoozed", "snoozed_until": "2026-09-27T09:00:00+05:30"},
    )
    assert r.status_code == 201, r.text
    assert (r.json()["id"], r.json()["status"], r.json()["version"]) == (expected, "snoozed", 1)
    # Another device marks it done: the same row, replaced.
    r = client.post(STATES, headers=h, json={"id": expected, "dedup_key": KEY, "status": "done"})
    assert r.status_code == 200, r.text
    assert (r.json()["status"], r.json()["snoozed_until"], r.json()["version"]) == ("done", None, 2)
    # Sending the version seen makes a stale decision a conflict instead.
    r = client.post(STATES, headers=h, json={"dedup_key": KEY, "status": "dismissed", "version": 1})
    assert error(r)[0] == "version_conflict"
    # Taken back, then decided again: the same row comes back.
    assert client.delete(f"{STATES}/{expected}", headers=h).json()["deleted_at"]
    r = client.post(STATES, headers=h, json={"dedup_key": KEY, "status": "dismissed"})
    assert (r.status_code, r.json()["id"], r.json()["deleted_at"]) == (200, expected, None)
    r = client.put(f"{STATES}/{expected}", headers=h, json={"status": "done"})
    assert r.json()["status"] == "done"
    r = client.put(f"{STATES}/{expected}", headers=h, json={"dedup_key": "other", "status": "done"})
    assert error(r) == ("dedup_key_fixed", "A decision stays with its reminder")
    with SessionLocal() as s:
        actions = s.scalars(
            select(ChangeLog.action)
            .where(ChangeLog.entity == "personal_reminder_state")
            .order_by(ChangeLog.seq)
        ).all()
    assert actions == [
        "personal_reminder_state.create",
        "personal_reminder_state.update",
        "personal_reminder_state.delete",
        "personal_reminder_state.update",
        "personal_reminder_state.update",
    ]


@pytest.mark.parametrize(
    ("body", "code", "message"),
    [
        (
            {"dedup_key": KEY, "status": "snoozed"},
            "snooze_until_required",
            "Say until when it's snoozed",
        ),
        (
            {"dedup_key": KEY, "status": "done", "snoozed_until": "2026-09-27T09:00:00Z"},
            "snooze_until_not_used",
            "Only a snoozed reminder has an until time",
        ),
        ({"status": "done"}, "dedup_key_required", "Say which reminder this is"),
        (
            {"id": str(uuid.uuid4()), "dedup_key": KEY, "status": "done"},
            "id_invalid",
            "A reminder decision's id comes from its key (reminder_state_id)",
        ),
        ({"dedup_key": "x" * 201, "status": "done"}, "invalid_input", None),
        ({"dedup_key": KEY, "status": "pending"}, "invalid_input", None),
    ],
)
def test_what_a_decision_needs(client, seeded, body, code, message):
    r = client.post(STATES, headers=login(client, "john"), json=body)
    assert error(r)[0] == code
    if message:
        assert error(r)[1] == message


def test_schedules_lifecycle_and_targets(client, seeded):
    h = login(client, "john")
    r = client.post(
        SCHEDULES, headers=h, json={"goal_id": LADAKH, "day_of_month": 1, "amount_minor": 300_000}
    )
    assert r.status_code == 201, r.text
    trip = r.json()
    assert (trip["currency"], trip["active"], trip["holding_id"]) == ("INR", True, None)
    # Left out, the amount stays; a holding replaces the goal.
    r = client.put(
        f"{SCHEDULES}/{trip['id']}",
        headers=h,
        json={"day_of_month": 10, "holding_id": NIFTY, "version": 1},
    )
    assert r.status_code == 200, r.text
    assert (r.json()["goal_id"], r.json()["holding_id"], r.json()["amount_minor"]) == (
        None,
        NIFTY,
        300_000,
    )
    assert client.delete(f"{SCHEDULES}/{trip['id']}", headers=h).json()["deleted_at"]
    assert client.post(f"{SCHEDULES}/{trip['id']}/restore", headers=h).json()["deleted_at"] is None

    for body, code in [
        ({"day_of_month": 1}, "target_required"),
        ({"day_of_month": 1, "goal_id": LADAKH, "holding_id": NIFTY}, "target_invalid"),
        ({"day_of_month": 29, "goal_id": LADAKH}, "invalid_input"),
        ({"day_of_month": 1, "holding_id": str(uuid.uuid4())}, "unknown_holding"),
        ({"day_of_month": 1, "goal_id": str(uuid.uuid4())}, "unknown_goal"),
    ]:
        assert error(client.post(SCHEDULES, headers=h, json=body))[0] == code, body
    gold = client.get(f"{GOALS}/{GOLD}", headers=h).json()
    client.put(
        f"{GOALS}/{GOLD}",
        headers=h,
        json={"name": gold["name"], "target_minor": gold["target_minor"], "status": "archived"},
    )
    r = client.post(SCHEDULES, headers=h, json={"day_of_month": 1, "goal_id": GOLD})
    assert error(r) == ("goal_archived", "Gold coins is archived")


def test_a_schedule_follows_its_goal(client, seeded):
    h = login(client, "john")
    mine = client.post(SCHEDULES, headers=h, json={"day_of_month": 7, "goal_id": GOLD}).json()
    client.delete(f"{GOALS}/{GOLD}", headers=h)
    assert client.get(f"{SCHEDULES}/{mine['id']}", headers=h).json()["deleted_at"]
    r = client.post(f"{SCHEDULES}/{mine['id']}/restore", headers=h)
    assert error(r) == ("unknown_goal", "This reminder's goal was deleted. Restore it first")
    client.post(f"{GOALS}/{GOLD}/restore", headers=h)
    assert client.get(f"{SCHEDULES}/{mine['id']}", headers=h).json()["deleted_at"] is None


def test_decisions_and_schedules_in_one_batch(client, seeded):
    h = login(client, "john")
    state_id = str(ledger_rules.reminder_state_id(uid("john"), KEY))
    items = [
        {
            "kind": "reminder_state",
            "op": "create",
            "id": state_id,
            "reminder_state": {"dedup_key": KEY, "status": "dismissed"},
        },
        {
            "kind": "reminder_schedule",
            "op": "create",
            "id": str(uuid.uuid4()),
            "reminder_schedule": {"day_of_month": 3, "goal_id": LADAKH},
        },
    ]
    r = client.post(f"{API}/personal/batch", headers=h, json={"items": items})
    assert r.status_code == 201, r.text
    assert [i["kind"] for i in r.json()["items"]] == ["reminder_state", "reminder_schedule"]
    before = log_count()
    again = client.post(f"{API}/personal/batch", headers=h, json={"items": items})
    assert (again.json(), log_count()) == (r.json(), before)
    wrong = [{**items[0], "id": str(uuid.uuid4())}]
    r = client.post(f"{API}/personal/batch", headers=h, json={"items": wrong})
    assert (r.json()["error"]["code"], r.json()["error"]["item"]) == ("id_invalid", 0)


def test_other_people_have_their_own_decisions(client, seeded):
    h = login(client, "john")
    other, zoya = register(client, "Zoya", "zoya@example.com")
    [mine] = client.get(STATES, headers=h).json()
    sip = str(seed_id("reminder_schedule", "john:sip"))
    for path in (f"{STATES}/{mine['id']}", f"{SCHEDULES}/{sip}"):
        assert client.get(path, headers=other).status_code == 404
        assert client.delete(path, headers=other).status_code == 404
    assert (
        client.get(STATES, headers=other).json()
        == client.get(SCHEDULES, headers=other).json()
        == []
    )
    # The same key is a different decision, with a different id.
    r = client.post(STATES, headers=other, json={"dedup_key": mine["dedup_key"], "status": "done"})
    assert r.status_code == 201
    assert r.json()["id"] == str(ledger_rules.reminder_state_id(zoya["id"], mine["dedup_key"]))
    assert client.get(f"{STATES}/{mine['id']}", headers=h).json()["status"] == "dismissed"
    r = client.post(SCHEDULES, headers=other, json={"day_of_month": 1, "holding_id": NIFTY})
    assert error(r)[0] == "unknown_holding"


def test_reminders_sync_on_the_owners_stream(client, seeded):
    h = login(client, "john")
    client.post(STATES, headers=h, json={"dedup_key": KEY, "status": "done"})
    snap = client.get(f"{API}/sync/snapshot/user:{uid('john')}", headers=h).json()
    kinds = [e["entity"] for e in snap["entities"]]
    assert kinds.count("personal_reminder_state") == len(data.REMINDER_STATES) + 1
    assert kinds.count("personal_reminder_schedule") == len(data.SCHEDULES)
    with SessionLocal() as s:
        [row] = s.scalars(
            select(ChangeLog).where(ChangeLog.entity == "personal_reminder_state")
        ).all()
    states = {
        e["entity_id"]: e["data"]
        for e in snap["entities"]
        if e["entity"] == "personal_reminder_state"
    }
    assert row.stream_id == f"user:{uid('john')}" and states[str(row.entity_id)] == row.data


def test_read_only_view_as_cant_write_reminders(client, seeded):
    _, as_rahul = start(client, login(client, "john"))
    for path, body in (
        (STATES, {"dedup_key": KEY, "status": "done"}),
        (SCHEDULES, {"day_of_month": 1, "goal_id": LADAKH}),
    ):
        r = client.post(path, headers=as_rahul, json=body)
        assert (r.status_code, r.json()["error"]["code"]) == (403, "read_only")
