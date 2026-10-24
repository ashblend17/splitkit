"""Allocation rules and plans: stored and checked on the server, never calculated there. A plan
is an intention made with its income (one per income and rule, ever), cancelled with it, and
explained by its own snapshot after its rule changes."""

import json
import uuid
from pathlib import Path

import pytest
from sqlalchemy import func, select

from app.core.db import SessionLocal
from app.models import ChangeLog
from app.modules.personal import ledger_rules
from app.seed import data
from app.seed.loader import account_id, seed_id
from tests.api.conftest import cat, login, register, uid
from tests.api.test_admin import start

API = "/api/v1"
RULES = f"{API}/personal/allocation-rules"
PLANS = f"{API}/personal/allocation-plans"
TXNS = f"{API}/personal/transactions"
GOALS = f"{API}/personal/goals"
ACCOUNTS = f"{API}/personal/accounts"
BATCH = f"{API}/personal/batch"
EMERGENCY, LADAKH, GOLD = (
    str(seed_id("goal", f"john:{k}")) for k in ("emergency", "ladakh", "gold")
)
SAVINGS, CASH = (
    str(account_id(next(a for a in data.ACCOUNTS if a.key == k))) for k in ("savings", "cash")
)
TRIP_SHARE, TOP_UP = (
    str(seed_id("allocation_rule", f"john:{k}")) for k in ("trip_share", "top_up")
)
VECTORS = json.loads(
    (Path(__file__).parents[3] / "shared" / "ledger_vectors.json").read_text(encoding="utf-8")
)


def rule(**extra) -> dict:
    return {"kind": "percentage", "percent_bp": 2000, "goal_id": LADAKH, **extra}


def plan(income: str, rule_id: str = TRIP_SHARE, planned: int = 100_000, **extra) -> dict:
    destination = {"goal_id": LADAKH} if rule_id == TRIP_SHARE else {"account_id": SAVINGS}
    snapshot = (
        {"snapshot_kind": "percentage", "snapshot_percent_bp": 1000}
        if rule_id == TRIP_SHARE
        else {"snapshot_kind": "fixed", "snapshot_amount_minor": 500_000}
    )
    return {
        "id": str(ledger_rules.plan_id(income, rule_id)),
        "source_transaction_id": income,
        "rule_id": rule_id,
        "planned_minor": planned,
        **destination,
        **snapshot,
        **extra,
    }


def income(client, h, amount: int = 1_000_000, type: str = "income") -> dict:
    body = {"type": type, "amount_minor": amount, "description": "Freelance", "date": "2026-09-24"}
    r = client.post(TXNS, headers=h, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def salary(client, h) -> dict:
    [s] = client.get(f"{TXNS}?type=income&start=2026-09-01&end=2026-09-01", headers=h).json()[
        "items"
    ]
    return s


def error(r) -> tuple[str, str]:
    assert r.status_code in (409, 422), r.text
    return r.json()["error"]["code"], r.json()["error"]["message"]


def log_count() -> int:
    with SessionLocal() as s:
        return s.scalar(select(func.count()).select_from(ChangeLog))


@pytest.mark.parametrize("case", VECTORS["plan_ids"], ids=lambda c: c["id"])
def test_plan_id_vectors(case):
    assert uuid.UUID(VECTORS["plan_namespace"]) == ledger_rules.PLAN_NAMESPACE
    assert ledger_rules.plan_id(case["transaction_id"], case["rule_id"]) == uuid.UUID(case["id"])


def test_the_seeded_rules_and_septembers_plans(client, seeded):
    h = login(client, "john")
    trip, top_up = client.get(RULES, headers=h).json()
    assert (trip["kind"], trip["percent_bp"], trip["goal_id"], trip["name"]) == (
        "percentage",
        1000,
        LADAKH,
        None,
    )
    assert (top_up["kind"], top_up["amount_minor"], top_up["account_id"], top_up["name"]) == (
        "fixed",
        500_000,
        SAVINGS,
        "Emergency top-up",
    )
    pay = salary(client, h)
    plans = client.get(f"{PLANS}?source_transaction_id={pay['id']}", headers=h).json()
    assert [(p["id"], p["planned_minor"], p["snapshot_kind"]) for p in plans] == [
        (str(ledger_rules.plan_id(pay["id"], TRIP_SHARE)), 850_000, "percentage"),
        (str(ledger_rules.plan_id(pay["id"], TOP_UP)), 500_000, "fixed"),
    ]
    assert client.get(f"{PLANS}?goal_id={LADAKH}", headers=h).json() == plans[:1]
    assert client.get(f"{PLANS}?account_id={SAVINGS}", headers=h).json() == plans[1:]
    # A plan has no status: that's the app's to work out.
    assert "status" not in plans[0]


def test_rules_lifecycle(client, seeded):
    h = login(client, "john")
    r = client.post(RULES, headers=h, json=rule(name="  Trip boost ", priority=4))
    assert r.status_code == 201, r.text
    boost = r.json()
    assert (boost["name"], boost["currency"], boost["active"], boost["trigger"]) == (
        "Trip boost",
        "INR",
        True,
        "income_recorded",
    )
    # Left out, the name and priority stay. Another kind drops the old kind's value; another
    # destination replaces the old one.
    r = client.put(
        f"{RULES}/{boost['id']}",
        headers=h,
        json={"kind": "fixed", "amount_minor": 200_000, "account_id": SAVINGS, "version": 1},
    )
    assert r.status_code == 200, r.text
    edited = r.json()
    assert (edited["name"], edited["priority"], edited["percent_bp"], edited["goal_id"]) == (
        "Trip boost",
        4,
        None,
        None,
    )
    assert (edited["amount_minor"], edited["account_id"], edited["version"]) == (
        200_000,
        SAVINGS,
        2,
    )
    stale = client.put(f"{RULES}/{boost['id']}", headers=h, json={**rule(), "version": 1})
    assert error(stale)[0] == "version_conflict"
    assert client.delete(f"{RULES}/{boost['id']}?version=2", headers=h).json()["deleted_at"]
    assert [x["id"] for x in client.get(f"{RULES}?deleted=true", headers=h).json()] == [boost["id"]]
    assert error(client.put(f"{RULES}/{boost['id']}", headers=h, json=rule()))[0] == "deleted"
    assert client.post(f"{RULES}/{boost['id']}/restore", headers=h).json()["deleted_at"] is None
    # Over 100% is the user's call: the app warns, the server keeps it.
    r = client.post(RULES, headers=h, json=rule(percent_bp=15_000))
    assert r.status_code == 201 and r.json()["percent_bp"] == 15_000


@pytest.mark.parametrize(
    ("body", "code", "message"),
    [
        (rule(percent_bp=None), "percent_required", "Give the percentage"),
        (rule(amount_minor=100), "amount_not_used", "A percentage rule has no fixed amount"),
        ({"kind": "fixed", "goal_id": LADAKH}, "amount_required", "Give the amount"),
        (
            {"kind": "fixed", "amount_minor": 100, "percent_bp": 10, "goal_id": LADAKH},
            "percent_not_used",
            "A fixed rule has no percentage",
        ),
        (rule(goal_id=None), "destination_required", "Pick the goal or account the money goes to"),
        (
            rule(account_id=SAVINGS),
            "destination_invalid",
            "A rule sends money to a goal or an account, not both",
        ),
        (
            rule(goal_id=EMERGENCY),
            "goal_tracks_balance",
            "Emergency fund follows an account's balance: send the money to that account instead",
        ),
        (
            rule(goal_id=GOLD),
            "goal_is_manual",
            "Gold coins is tracked by hand, so money can't go to it",
        ),
        (rule(goal_id=str(uuid.uuid4())), "unknown_goal", "That goal isn't available"),
        (rule(goal_id=None, account_id=str(uuid.uuid4())), "unknown_account", None),
        (rule(source_category_id=str(uuid.uuid4())), "unknown_category", None),
        (rule(percent_bp=0), "invalid_input", None),
        (rule(percent_bp=100_001), "invalid_input", None),
    ],
)
def test_what_a_rule_needs(client, seeded, body, code, message):
    r = client.post(RULES, headers=login(client, "john"), json=body)
    assert error(r)[0] == code
    if message:
        assert error(r)[1] == message


def test_a_rules_destination_keeps_taking_money(client, seeded):
    h = login(client, "john")
    ladakh = client.get(f"{GOALS}/{LADAKH}", headers=h).json()
    body = {"name": ladakh["name"], "target_minor": ladakh["target_minor"]}
    trip_rule = {
        "code": "rule_points_here",
        "message": "The rule “10% of each income” sends money to this goal. Change or delete it "
        "first",
        "rule_id": TRIP_SHARE,
    }
    assert client.delete(f"{GOALS}/{LADAKH}", headers=h).json()["error"] == trip_rule
    for change in ({"status": "archived"}, {"tracking_mode": "manual", "manual_progress_minor": 0}):
        r = client.put(f"{GOALS}/{LADAKH}", headers=h, json={**body, **change})
        assert r.json()["error"] == trip_rule
    # A paused goal still takes money.
    r = client.put(f"{GOALS}/{LADAKH}", headers=h, json={**body, "status": "paused"})
    assert r.status_code == 200, r.text

    savings = client.get(f"{ACCOUNTS}/{SAVINGS}", headers=h).json()
    r = client.put(
        f"{ACCOUNTS}/{SAVINGS}",
        headers=h,
        json={"name": savings["name"], "type": "bank", "status": "closed"},
    )
    assert error(r) == (
        "rule_points_here",
        "The rule “Emergency top-up” sends money to this account. Change or delete it first",
    )
    assert error(client.delete(f"{ACCOUNTS}/{SAVINGS}", headers=h))[0] == "rule_points_here"
    # A closed account takes no rule.
    client.put(
        f"{ACCOUNTS}/{CASH}", headers=h, json={"name": "Cash", "type": "cash", "status": "closed"}
    )
    r = client.post(RULES, headers=h, json=rule(goal_id=None, account_id=CASH))
    assert error(r) == ("account_closed", "That account is closed")

    # Once the rule is gone the goal can be archived, and the rule can't come back to it.
    client.delete(f"{RULES}/{TRIP_SHARE}", headers=h)
    client.put(f"{GOALS}/{LADAKH}", headers=h, json={**body, "status": "archived"})
    r = client.post(f"{RULES}/{TRIP_SHARE}/restore", headers=h)
    assert error(r) == ("goal_archived", "Ladakh trip is archived")

    # Nor can a category a rule filters on be deleted.
    freelance = client.post(
        f"{API}/categories", headers=h, json={"label": "Freelance", "scope": "personal"}
    ).json()
    client.post(
        RULES,
        headers=h,
        json=rule(goal_id=None, account_id=SAVINGS, source_category_id=freelance["id"]),
    )
    r = client.delete(f"{API}/categories/{freelance['id']}", headers=h)
    assert (r.status_code, r.json()["error"]["code"]) == (409, "category_in_use")


def test_plans_lifecycle_and_one_per_income_and_rule(client, seeded):
    h = login(client, "john")
    pay = income(client, h)
    body = plan(pay["id"])
    r = client.post(PLANS, headers=h, json=body)
    assert r.status_code == 201, r.text
    made = r.json()
    assert (made["id"], made["currency"], made["version"]) == (body["id"], "INR", 1)
    # The same plan again is the same plan.
    before = log_count()
    assert client.post(PLANS, headers=h, json=body).json() == made
    assert log_count() == before
    # Another id for the same income and rule isn't a second plan.
    r = client.post(PLANS, headers=h, json={**body, "id": str(uuid.uuid4())})
    assert r.status_code == 409
    assert r.json()["error"] == {
        "code": "plan_exists",
        "message": "This income already has a plan from that rule",
        "plan_id": made["id"],
    }
    # Recomputed after the income changed; what it's for doesn't change.
    r = client.put(f"{PLANS}/{made['id']}", headers=h, json={**body, "planned_minor": 120_000})
    assert (r.json()["planned_minor"], r.json()["version"]) == (120_000, 2)
    r = client.put(f"{PLANS}/{made['id']}", headers=h, json={**body, "rule_id": TOP_UP})
    assert error(r) == ("plan_fixed", "A plan's income, rule and destination don't change")
    assert client.delete(f"{PLANS}/{made['id']}", headers=h).json()["deleted_at"]
    assert client.post(f"{PLANS}/{made['id']}/restore", headers=h).json()["deleted_at"] is None


def test_what_a_plan_needs(client, seeded):
    h = login(client, "john")
    pay = income(client, h)
    spend = income(client, h, type="expense")
    gone = income(client, h)
    client.delete(f"{TXNS}/{gone['id']}", headers=h)
    other, _ = register(client, "Zoya", "zoya@example.com")
    hers = income(client, other)
    for source in (spend["id"], gone["id"], hers["id"], str(uuid.uuid4())):
        r = client.post(PLANS, headers=h, json=plan(source))
        assert error(r) == ("unknown_income", "That income isn't available"), source
    r = client.post(PLANS, headers=h, json=plan(pay["id"], account_id=SAVINGS, goal_id=None))
    assert error(r) == ("destination_mismatch", "A plan goes where its rule sends money")
    r = client.post(PLANS, headers=h, json=plan(pay["id"], rule_id=str(uuid.uuid4())))
    assert error(r) == ("unknown_rule", "That rule isn't available")
    r = client.post(PLANS, headers=h, json=plan(pay["id"], snapshot_amount_minor=100))
    assert error(r)[0] == "snapshot_invalid"
    r = client.post(PLANS, headers=h, json={**plan(pay["id"]), "rule_id": None})
    assert error(r) == ("plan_incomplete", "A plan needs its income, its rule and one destination")
    # An inactive rule is the app's business; a deleted one makes no new plans.
    trip = client.get(f"{RULES}/{TRIP_SHARE}", headers=h).json()
    client.put(f"{RULES}/{TRIP_SHARE}", headers=h, json={"kind": trip["kind"], "active": False})
    assert client.post(PLANS, headers=h, json=plan(pay["id"])).status_code == 201
    client.delete(f"{RULES}/{TOP_UP}", headers=h)
    r = client.post(PLANS, headers=h, json=plan(pay["id"], rule_id=TOP_UP))
    assert error(r) == ("unknown_rule", "That rule was deleted, so it makes no new plans")
    # Its old plans stay.
    assert len(client.get(f"{PLANS}?rule_id={TOP_UP}", headers=h).json()) == 1


def test_plans_follow_their_income(client, seeded):
    h = login(client, "john")
    pay = salary(client, h)
    plans = f"{PLANS}?source_transaction_id={pay['id']}"
    client.delete(f"{TXNS}/{pay['id']}", headers=h)
    assert client.get(plans, headers=h).json() == []
    assert len(client.get(f"{plans}&deleted=true", headers=h).json()) == 2
    client.post(f"{TXNS}/{pay['id']}/restore", headers=h)
    trip_plan, top_up_plan = client.get(plans, headers=h).json()
    # One deleted by hand stays deleted.
    client.delete(f"{PLANS}/{top_up_plan['id']}", headers=h)
    client.delete(f"{TXNS}/{pay['id']}", headers=h)
    client.post(f"{TXNS}/{pay['id']}/restore", headers=h)
    assert [p["id"] for p in client.get(plans, headers=h).json()] == [trip_plan["id"]]

    # An income with plans stays an income until its plans go, in the same batch.
    pay = client.get(f"{TXNS}/{pay['id']}", headers=h).json()
    edit = {k: pay[k] for k in ("amount_minor", "description", "date", "account_id", "version")}
    r = client.put(f"{TXNS}/{pay['id']}", headers=h, json={**edit, "type": "expense"})
    assert error(r) == (
        "income_has_plans",
        "Your allocation rules made plans from this income. Delete them first",
    )
    trip_plan = client.get(f"{PLANS}/{trip_plan['id']}", headers=h).json()
    items = [
        {
            "kind": "allocation_plan",
            "op": "delete",
            "id": trip_plan["id"],
            "version": trip_plan["version"],
        },
        {
            "kind": "transaction",
            "op": "update",
            "id": pay["id"],
            "version": pay["version"],
            "transaction": {**edit, "type": "expense"},
        },
    ]
    r = client.post(BATCH, headers=h, json={"items": items})
    assert r.status_code == 201, r.text


def test_an_income_and_its_plans_in_one_batch(client, seeded):
    h = login(client, "john")
    pay = str(uuid.uuid4())
    body = {
        "type": "income",
        "amount_minor": 4_000_000,
        "description": "Bonus",
        "date": "2026-09-24",
    }
    items = [
        {"kind": "transaction", "op": "create", "id": pay, "transaction": body},
        *(
            {"kind": "allocation_plan", "op": "create", "id": p["id"], "allocation_plan": p}
            for p in (plan(pay, planned=400_000), plan(pay, TOP_UP, planned=500_000))
        ),
    ]
    r = client.post(BATCH, headers=h, json={"items": items})
    assert r.status_code == 201, r.text
    assert [i["kind"] for i in r.json()["items"]] == [
        "transaction",
        "allocation_plan",
        "allocation_plan",
    ]
    before = log_count()
    again = client.post(BATCH, headers=h, json={"items": items})
    assert (again.status_code, again.json(), log_count()) == (201, r.json(), before)

    # The income edited, its plans recomputed, together.
    made = r.json()["items"]
    edit = [
        {
            "kind": "transaction",
            "op": "update",
            "id": pay,
            "version": 1,
            "transaction": {**body, "amount_minor": 5_000_000},
        },
        {
            "kind": "allocation_plan",
            "op": "update",
            "id": made[1]["allocation_plan"]["id"],
            "version": 1,
            "allocation_plan": {**plan(pay, planned=500_000), "id": None},
        },
    ]
    r = client.post(BATCH, headers=h, json={"items": edit})
    assert r.status_code == 201, r.text
    assert r.json()["items"][1]["allocation_plan"]["planned_minor"] == 500_000

    # A refusal at the plan keeps the income out too.
    other = str(uuid.uuid4())
    refused = [
        {"kind": "transaction", "op": "create", "id": other, "transaction": body},
        {
            "kind": "allocation_plan",
            "op": "create",
            "id": str(uuid.uuid4()),
            "allocation_plan": {**plan(other), "goal_id": None, "account_id": SAVINGS, "id": None},
        },
    ]
    before = log_count()
    r = client.post(BATCH, headers=h, json={"items": refused})
    assert (r.json()["error"]["code"], r.json()["error"]["item"]) == ("destination_mismatch", 1)
    assert log_count() == before
    assert client.get(f"{TXNS}/{other}", headers=h).status_code == 404


def test_other_people_cant_see_or_use_rules_and_plans(client, seeded):
    h = login(client, "john")
    other, _ = register(client, "Zoya", "zoya@example.com")
    pay = salary(client, h)
    trip_plan = str(ledger_rules.plan_id(pay["id"], TRIP_SHARE))
    for path in (f"{RULES}/{TRIP_SHARE}", f"{PLANS}/{trip_plan}"):
        assert client.get(path, headers=other).status_code == 404
        assert client.delete(path, headers=other).status_code == 404
    assert client.get(RULES, headers=other).json() == client.get(PLANS, headers=other).json() == []
    assert error(client.post(RULES, headers=other, json=rule()))[0] == "unknown_goal"
    hers = income(client, other)
    r = client.post(PLANS, headers=other, json=plan(hers["id"]))
    assert error(r)[0] == "unknown_rule"


def test_rules_and_plans_sync_on_the_owners_stream(client, seeded):
    h = login(client, "john")
    made = client.post(RULES, headers=h, json=rule()).json()
    with SessionLocal() as s:
        [row] = s.scalars(
            select(ChangeLog).where(ChangeLog.entity == "personal_allocation_rule")
        ).all()
    assert (row.stream_id, str(row.entity_id), row.version) == (
        f"user:{uid('john')}",
        made["id"],
        1,
    )
    snap = client.get(f"{API}/sync/snapshot/user:{uid('john')}", headers=h).json()
    kinds = [e["entity"] for e in snap["entities"]]
    assert kinds.count("personal_allocation_rule") == len(data.RULES) + 1
    assert kinds.count("personal_allocation_plan") == len(data.PLANS)
    rules = {
        e["entity_id"]: e["data"]
        for e in snap["entities"]
        if e["entity"] == "personal_allocation_rule"
    }
    assert rules[made["id"]] == row.data


def test_read_only_view_as_cant_write_rules_or_plans(client, seeded):
    _, as_rahul = start(client, login(client, "john"))
    for path in (RULES, PLANS):
        r = client.post(path, headers=as_rahul, json=rule())
        assert (r.status_code, r.json()["error"]["code"]) == (403, "read_only")


def test_the_category_filter_must_be_yours(client, seeded):
    h = login(client, "john")
    r = client.post(RULES, headers=h, json=rule(source_category_id=cat("income")))
    assert r.status_code == 201, r.text
    assert r.json()["source_category_id"] == cat("income")
