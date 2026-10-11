"""Admin: dashboard, users, view-as sessions (read-only enforced on the server), audit log."""

import re
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import func, select, update

from app.core.db import SessionLocal
from app.main import app
from app.modules.admin.models import AdminSession, AuditLog
from app.modules.auth.deps import READ_ONLY_POSTS
from app.modules.expenses.models import Expense
from app.modules.groups.models import ActivityEvent
from app.modules.sync.models import ChangeLog
from app.modules.users.models import User
from app.seed import data
from tests.api.conftest import cat, eid, gid, login, register, uid

API = "/api/v1"


def start(client, admin_headers, target="rahul", mode=None):
    body = {"target_user_id": uid(target)} if isinstance(target, str) else target
    if mode:
        body["mode"] = mode
    r = client.post(f"{API}/admin/sessions", headers=admin_headers, json=body)
    assert r.status_code == 201, r.text
    out = r.json()
    return out, {"Authorization": f"Bearer {out['access_token']}"}


def expense_body(**extra):
    return {
        "description": "Parasailing",
        "amount_minor": 300000,
        "payer_id": uid("rahul"),
        "date": "2026-09-24",
        "category_id": cat("entertainment"),
        "split": {"method": "equal", "inputs": [{"user_id": uid(u)} for u in ("rahul", "aman")]},
        **extra,
    }


def count(model, *where) -> int:
    with SessionLocal() as s:
        return s.scalar(select(func.count()).select_from(model).where(*where))


# ---- who can use admin routes ----

ADMIN_GETS = ["/admin/dashboard", "/admin/users", "/admin/sessions", "/admin/audit"]


@pytest.mark.parametrize("path", ADMIN_GETS)
def test_non_admins_get_403(client, seeded, path):
    r = client.get(f"{API}{path}", headers=login(client, "rahul"))
    assert r.status_code == 403
    assert r.json()["error"]["code"] == "not_admin"


def test_non_admin_cannot_start_a_session(client, seeded):
    r = client.post(
        f"{API}/admin/sessions",
        headers=login(client, "rahul"),
        json={"target_user_id": uid("aman")},
    )
    assert (r.status_code, r.json()["error"]["code"]) == (403, "not_admin")


def test_admin_routes_need_a_token(client, seeded):
    assert client.get(f"{API}/admin/dashboard").status_code == 401


@pytest.mark.parametrize("path", ADMIN_GETS)
def test_view_as_token_cannot_reach_admin_routes(client, seeded, path):
    _, as_rahul = start(client, login(client, "ansh"), mode="edit")
    r = client.get(f"{API}{path}", headers=as_rahul)
    assert (r.status_code, r.json()["error"]["code"]) == (403, "not_admin")


# ---- dashboard ----


def test_dashboard_matches_the_seed(client, seeded):
    r = client.get(f"{API}/admin/dashboard", headers=login(client, "ansh"))
    assert r.status_code == 200, r.text
    d = r.json()
    live = [e for e in data.EXPENSES if not e.deleted]
    assert (d["users"], d["admins"], d["placeholders"]) == (len(data.USERS), 1, 0)
    assert d["groups"] == len(data.GROUPS)
    assert d["expenses"] == len(live)
    assert d["expenses_imported"] == len([e for e in live if e.imported])
    assert d["expense_volume"] == [
        {"currency": "INR", "amount_minor": sum(e.amount for e in live) * 100}
    ]
    assert d["settlements"] == len(data.SETTLEMENTS)
    assert d["settlement_volume"] == [
        {"currency": "INR", "amount_minor": sum(s.amount for s in data.SETTLEMENTS) * 100}
    ]
    assert d["personal_transactions"] == len(data.PERSONAL)
    assert d["personal_users"] == len({p.user for p in data.PERSONAL})
    assert d["open_sessions"] == 0  # the seeded session has ended
    assert d["system"]["database"].startswith("PostgreSQL 16")
    assert d["system"]["database_bytes"] > 0
    assert d["system"]["last_import_source"] == "tricount"

    recent = d["recent"]
    assert len(recent) == min(8, len(data.AUDIT))
    newest = recent[0]
    assert (newest["actor"]["name"], newest["done_as"], newest["group"]["name"]) == (
        "Rahul Sharma",
        "user",
        "Goa Trip",
    )
    assert newest["summary"] == "Added “Dinner at Thalassa” · ₹1,800"
    by_admin = next(e for e in recent if e["done_as"] == "admin")
    assert (by_admin["actor"]["name"], by_admin["acting_as"]["name"]) == ("Ansh C", "Priya Nair")
    assert by_admin["summary"] == "Changed the category of “Scooter rentals”"
    importer = next(e for e in recent if e["done_as"] == "system")
    assert importer["actor"] is None
    assert importer["summary"] == "Import finished · 13 expenses, 3 to review"
    kabir = next(e for e in recent if e["action"] == "member.join")
    assert kabir["summary"] == "Joined via invite link"


def test_dashboard_counts_placeholders_and_active_groups(client, seeded):
    h = login(client, "ansh")
    client.post(f"{API}/groups/{gid('flat')}/members", headers=h, json={"name": "Neha"})
    d = client.get(f"{API}/admin/dashboard", headers=h).json()
    assert d["placeholders"] == 1 and d["users"] == len(data.USERS)
    assert d["groups_active_week"] >= 1

    # Archived (with activity this week): out of both counts, so "active" never exceeds "groups".
    client.patch(f"{API}/groups/{gid('flat')}", headers=h, json={"archived": True})
    after = client.get(f"{API}/admin/dashboard", headers=h).json()
    assert after["groups"] == d["groups"] - 1
    assert after["groups_active_week"] == d["groups_active_week"] - 1


# ---- users ----


def test_users_list_has_counts_and_balances(client, seeded):
    r = client.get(f"{API}/admin/users", headers=login(client, "ansh"))
    assert r.status_code == 200, r.text
    page = r.json()
    assert (page["total"], page["has_more"]) == (len(data.USERS), False)
    rows = {u["name"]: u for u in page["items"]}
    assert page["items"][0]["role"] == "admin"  # admins first
    ansh = rows["Ansh C"]
    assert ansh["group_count"] == 2 and ansh["personal_count"] == len(data.PERSONAL)
    assert ansh["settlement_count"] == 1 and ansh["last_active_at"] is not None
    kabir = rows["Kabir Mehta"]
    assert kabir["group_count"] == 1 and kabir["personal_count"] == 0

    # Nets add up to zero across everyone (all seed groups are INR).
    total = sum(b["amount_minor"] for u in page["items"] for b in u["balances"])
    assert total == 0
    # Matches what the user sees on Home.
    rahul_home = client.get(f"{API}/balances", headers=login(client, "rahul")).json()
    [inr] = rahul_home["totals"]
    rahul_net = sum(b["amount_minor"] for b in rows["Rahul Sharma"]["balances"])
    assert rahul_net == inr["net_minor"]
    # Expenses Rahul paid or shares in.
    involved = [
        e
        for e in data.EXPENSES
        if not e.deleted and (e.payer == "rahul" or any(p == "rahul" for p, _ in e.inputs))
    ]
    assert rows["Rahul Sharma"]["expense_count"] == len(involved)


def test_user_search_and_paging(client, seeded):
    h = login(client, "ansh")

    def names(**params):
        return [
            u["name"]
            for u in client.get(f"{API}/admin/users", headers=h, params=params).json()["items"]
        ]

    assert names(q="priya") == ["Priya Nair"]
    assert names(q="EXAMPLE.COM") == sorted(u.name for u in data.USERS if u.role == "user")
    assert names(q="100%") == []  # LIKE wildcards are literal
    assert names(role="admin") == ["Ansh C"]
    first = client.get(f"{API}/admin/users", headers=h, params={"limit": 2}).json()
    assert len(first["items"]) == 2 and first["has_more"] and first["total"] == len(data.USERS)
    rest = client.get(f"{API}/admin/users", headers=h, params={"limit": 50, "offset": 2}).json()
    assert len(rest["items"]) == len(data.USERS) - 2 and not rest["has_more"]

    client.post(f"{API}/groups/{gid('flat')}/members", headers=h, json={"name": "Neha"})
    assert names(q="neha") == []
    neha = client.get(
        f"{API}/admin/users", headers=h, params={"q": "neha", "include_placeholders": True}
    ).json()["items"]
    assert [(u["name"], u["is_placeholder"], u["group_count"]) for u in neha] == [("Neha", True, 1)]


# ---- starting sessions ----


def test_session_defaults_to_read_only_and_resolves_to_the_target(client, seeded):
    out, as_rahul = start(client, login(client, "ansh"))
    assert out["session"]["mode"] == "read_only" and out["session"]["active"]
    assert (out["session"]["admin"]["name"], out["session"]["target"]["name"]) == (
        "Ansh C",
        "Rahul Sharma",
    )
    assert out["user"]["id"] == uid("rahul") and out["expires_in"] > 0
    me = client.get(f"{API}/me", headers=as_rahul).json()
    assert me["id"] == uid("rahul")
    # Reads work and show exactly what Rahul sees.
    rahul_home = client.get(f"{API}/balances", headers=login(client, "rahul")).json()
    assert client.get(f"{API}/balances", headers=as_rahul).json() == rahul_home


@pytest.mark.parametrize(
    ("target", "message"),
    [
        ("ansh", "You're already signed in as yourself"),
        ("second_admin", "You can't view the app as another admin"),
        ("placeholder", "Neha doesn't have an account yet, so there's nothing to view as them"),
    ],
)
def test_who_cannot_be_viewed_as(client, seeded, target, message):
    h = login(client, "ansh")
    if target == "second_admin":
        _, other = register(client, "Other Admin", "other.admin@example.com")
        with SessionLocal.begin() as s:
            s.execute(update(User).where(User.id == uuid.UUID(other["id"])).values(role="admin"))
        target_id = other["id"]
    elif target == "placeholder":
        r = client.post(f"{API}/groups/{gid('flat')}/members", headers=h, json={"name": "Neha"})
        target_id = next(m for m in r.json()["members"] if m["user"]["name"] == "Neha")["user"][
            "id"
        ]
    else:
        target_id = uid(target)
    r = client.post(f"{API}/admin/sessions", headers=h, json={"target_user_id": target_id})
    assert r.status_code == 422
    assert r.json()["error"] == {"code": "cannot_view_as", "message": message}


def test_unknown_target_is_404(client, seeded):
    r = client.post(
        f"{API}/admin/sessions",
        headers=login(client, "ansh"),
        json={"target_user_id": str(uuid.uuid4())},
    )
    assert r.status_code == 404


# ---- read-only is enforced on the server ----


def _write_routes():
    """Every write route, from the OpenAPI spec (operationId is the route name)."""
    for path, ops in app.openapi()["paths"].items():
        if path.startswith(f"{API}/auth"):
            continue
        for method, op in ops.items():
            if method in ("post", "put", "patch", "delete"):
                if op["operationId"] not in READ_ONLY_POSTS:
                    yield method.upper(), path


WRITE_ROUTES = list(_write_routes())


def test_write_route_list_covers_every_module():
    paths = {p for _, p in WRITE_ROUTES}
    for fragment in ("/expenses", "/settlements", "/groups", "/me", "/personal", "/categories",
                     "/analytics/layout", "/friends", "/admin/sessions"):  # fmt: skip
        assert any(fragment in p for p in paths), fragment
    assert len(WRITE_ROUTES) >= 20


@pytest.mark.parametrize(("method", "path"), WRITE_ROUTES)
def test_read_only_blocks_every_write_route(client, seeded, method, path):
    _, as_rahul = start(client, login(client, "ansh"))
    filled = re.sub(
        r"\{(\w+)\}", lambda m: "personal" if m[1] == "scope" else str(uuid.uuid4()), path
    )
    before = count(AuditLog)
    r = client.request(method, filled, headers=as_rahul, json={})
    assert r.status_code == 403, (method, path, r.text)
    assert r.json()["error"]["code"] == "read_only"
    assert count(AuditLog) == before


def test_read_only_blocks_real_writes_and_writes_nothing(client, seeded):
    _, as_rahul = start(client, login(client, "ansh"))
    expenses, logs = count(Expense), count(ChangeLog)
    attempts = [
        ("POST", f"/groups/{gid('goa')}/expenses", expense_body()),
        ("PUT", f"/expenses/{eid('goa_dinner')}", expense_body()),
        ("DELETE", f"/expenses/{eid('goa_dinner')}", None),
        ("PATCH", "/me", {"name": "Hacked"}),
        ("POST", "/groups", {"name": "Sneaky"}),
        ("POST", f"/friends/{uid('ansh')}/settle-up", {"date": "2026-09-24", "method": "cash"}),
    ]
    for method, path, body in attempts:
        r = client.request(method, f"{API}{path}", headers=as_rahul, json=body)
        assert (r.status_code, r.json()["error"]["code"]) == (403, "read_only"), path
    assert (count(Expense), count(ChangeLog)) == (expenses, logs)
    # Read-only POSTs still work.
    assert client.post(f"{API}/sync", headers=as_rahul, json={"cursors": {}}).status_code == 200


# ---- edit mode ----


def test_edit_mode_writes_carry_the_admin_everywhere(client, seeded):
    admin = login(client, "ansh")
    _, as_rahul = start(client, admin, mode="edit")
    r = client.post(f"{API}/groups/{gid('goa')}/expenses", headers=as_rahul, json=expense_body())
    assert r.status_code == 201, r.text
    e = r.json()
    assert e["acting_admin_id"] == uid("ansh") and e["created_by"]["id"] == uid("rahul")
    expense_id = uuid.UUID(e["id"])

    pay = client.post(
        f"{API}/groups/{gid('goa')}/settlements",
        headers=as_rahul,
        json={
            "from_user": uid("rahul"),
            "to_user": uid("aman"),
            "amount_minor": 10000,
            "date": "2026-09-24",
            "method": "cash",
        },
    )
    assert pay.status_code == 201, pay.text
    assert pay.json()["acting_admin_id"] == uid("ansh")
    # A delete made in edit mode is marked too.
    gone = client.delete(f"{API}/settlements/{pay.json()['id']}", headers=as_rahul)
    assert gone.json()["acting_admin_id"] == uid("ansh")

    with SessionLocal() as s:
        audit = s.scalar(select(AuditLog).where(AuditLog.entity_id == expense_id))
        assert (audit.actor_id, audit.acting_as_id) == (
            uuid.UUID(uid("ansh")),
            uuid.UUID(uid("rahul")),
        )
        activity = s.scalar(select(ActivityEvent).where(ActivityEvent.entity_id == expense_id))
        assert (activity.actor_id, activity.acting_admin_id) == (
            uuid.UUID(uid("rahul")),
            uuid.UUID(uid("ansh")),
        )
        change = s.scalar(select(ChangeLog).where(ChangeLog.entity_id == expense_id))
        assert change.acting_admin_id == uuid.UUID(uid("ansh"))
        assert change.data["acting_admin_id"] == uid("ansh")
        stored = s.get(Expense, expense_id)
        assert stored.acting_admin_id == uuid.UUID(uid("ansh"))

    # Everyone's feed shows the Admin badge for it.
    feed = client.get(f"{API}/feed", headers=login(client, "aman")).json()
    item = next(i for i in feed if i["id"] == e["id"])
    assert item["by_admin"] is True
    history = client.get(f"{API}/expenses/{e['id']}/history", headers=login(client, "rahul"))
    [created] = history.json()
    assert (created["person"]["name"], created["admin"]["name"]) == ("Rahul Sharma", "Ansh C")

    # The audit log shows who acted as whom.
    entries = client.get(
        f"{API}/admin/audit", headers=admin, params={"entity": "expense", "admin_only": True}
    ).json()["items"]
    mine = next(x for x in entries if x["entity_id"] == e["id"])
    assert (mine["done_as"], mine["actor"]["name"], mine["acting_as"]["name"]) == (
        "admin",
        "Ansh C",
        "Rahul Sharma",
    )
    assert mine["summary"] == "Added “Parasailing” · ₹3,000"


def test_switching_mode_is_explicit_and_audited(client, seeded):
    admin = login(client, "ansh")
    out, as_rahul = start(client, admin)
    sid = out["session"]["id"]
    path = f"{API}/groups/{gid('goa')}/expenses"
    assert client.post(path, headers=as_rahul, json=expense_body()).status_code == 403

    r = client.patch(f"{API}/admin/sessions/{sid}", headers=admin, json={"mode": "edit"})
    assert r.status_code == 200 and r.json()["mode"] == "edit"
    assert client.post(path, headers=as_rahul, json=expense_body()).status_code == 201  # same token

    client.patch(f"{API}/admin/sessions/{sid}", headers=admin, json={"mode": "read_only"})
    assert client.post(path, headers=as_rahul, json=expense_body()).status_code == 403

    trail = client.get(
        f"{API}/admin/audit", headers=admin, params={"entity": "admin_session"}
    ).json()["items"]
    assert [x["action"] for x in trail] == [
        "admin_session.mode",
        "admin_session.mode",
        "admin_session.start",
    ]
    assert trail[1]["summary"] == "Switched to edit mode while viewing as Rahul"
    assert trail[1]["diff"] == {"mode": {"from": "read_only", "to": "edit"}}
    assert trail[2]["summary"] == "Started viewing as Rahul · read-only"
    # Session events are not group activity and are not synced.
    assert count(ActivityEvent, ActivityEvent.entity == "admin_session") == 0
    assert count(ChangeLog, ChangeLog.entity == "admin_session") == 0


def test_only_the_starting_admin_can_switch_mode(client, seeded):
    out, _ = start(client, login(client, "ansh"))
    _, other = register(client, "Other Admin", "other.admin@example.com")
    with SessionLocal.begin() as s:
        s.execute(update(User).where(User.id == uuid.UUID(other["id"])).values(role="admin"))
    other_h = login_email(client, "other.admin@example.com")
    r = client.patch(
        f"{API}/admin/sessions/{out['session']['id']}", headers=other_h, json={"mode": "edit"}
    )
    assert r.status_code == 404


def login_email(client, email):
    r = client.post(f"{API}/auth/login", json={"email": email, "password": "correct-horse"})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# ---- ending sessions ----


def test_ended_session_rejects_its_token(client, seeded):
    admin = login(client, "ansh")
    out, as_rahul = start(client, admin, mode="edit")
    sid = out["session"]["id"]
    r = client.post(f"{API}/admin/sessions/{sid}/end", headers=admin)
    assert r.status_code == 200 and r.json()["ended_at"] and not r.json()["active"]
    for call in (
        lambda: client.get(f"{API}/me", headers=as_rahul),
        lambda: client.post(
            f"{API}/groups/{gid('goa')}/expenses", headers=as_rahul, json=expense_body()
        ),
    ):
        res = call()
        assert (res.status_code, res.json()["error"]["code"]) == (401, "admin_session_ended")
    # Ending again changes nothing; switching mode on an ended session is refused.
    assert client.post(f"{API}/admin/sessions/{sid}/end", headers=admin).status_code == 200
    r = client.patch(f"{API}/admin/sessions/{sid}", headers=admin, json={"mode": "edit"})
    assert r.status_code == 409
    ends = count(AuditLog, AuditLog.action == "admin_session.end")
    assert ends == 1


def test_view_as_token_can_end_its_own_session_even_read_only(client, seeded):
    out, as_rahul = start(client, login(client, "ansh"))
    sid = out["session"]["id"]
    other = str(uuid.uuid4())
    assert client.post(f"{API}/admin/sessions/{other}/end", headers=as_rahul).status_code == 403
    r = client.post(f"{API}/admin/sessions/{sid}/end", headers=as_rahul)
    assert r.status_code == 200, r.text
    assert client.get(f"{API}/me", headers=as_rahul).status_code == 401
    with SessionLocal() as s:
        end = s.scalar(select(AuditLog).where(AuditLog.action == "admin_session.end"))
        assert (end.actor_id, end.acting_as_id) == (uuid.UUID(uid("ansh")), uuid.UUID(uid("rahul")))


def test_new_session_ends_the_previous_one(client, seeded):
    admin = login(client, "ansh")
    first, as_rahul = start(client, admin)
    _, as_aman = start(client, admin, target="aman")
    assert client.get(f"{API}/me", headers=as_rahul).status_code == 401
    assert client.get(f"{API}/me", headers=as_aman).json()["id"] == uid("aman")
    sessions = client.get(f"{API}/admin/sessions", headers=admin, params={"active": True}).json()
    assert [s["target"]["name"] for s in sessions["items"]] == ["Aman Verma"]
    everything = client.get(f"{API}/admin/sessions", headers=admin).json()
    assert everything["total"] == 3  # plus the seeded one
    assert everything["items"][-1]["target"]["name"] == "Priya Nair"


def test_expired_session_or_demoted_admin_rejects_the_token(client, seeded):
    out, as_rahul = start(client, login(client, "ansh"))
    with SessionLocal.begin() as s:
        s.execute(
            update(AdminSession)
            .where(AdminSession.id == uuid.UUID(out["session"]["id"]))
            .values(expires_at=datetime.now(UTC) - timedelta(minutes=1))
        )
    assert client.get(f"{API}/me", headers=as_rahul).status_code == 401

    _, as_aman = start(client, login(client, "ansh"), target="aman")
    with SessionLocal.begin() as s:
        s.execute(update(User).where(User.id == uuid.UUID(uid("ansh"))).values(role="user"))
    assert client.get(f"{API}/me", headers=as_aman).status_code == 401


def test_tampered_token_is_rejected(client, seeded):
    out, _ = start(client, login(client, "ansh"))
    from app.modules.auth.tokens import create_impersonation_token

    # Signed correctly, but names a session that belongs to another target.
    forged = create_impersonation_token(
        uuid.UUID(uid("aman")),
        uuid.UUID(uid("ansh")),
        uuid.UUID(out["session"]["id"]),
        "edit",
        datetime.now(UTC) + timedelta(hours=1),
    )
    r = client.get(f"{API}/me", headers={"Authorization": f"Bearer {forged}"})
    assert r.status_code == 401


# ---- audit log ----


def test_audit_is_newest_first_with_paging(client, seeded):
    h = login(client, "ansh")
    page = client.get(f"{API}/admin/audit", headers=h, params={"limit": 3}).json()
    assert page["total"] == len(data.AUDIT) and page["has_more"]
    ats = [x["at"] for x in page["items"]]
    assert ats == sorted(ats, reverse=True)
    rest = client.get(f"{API}/admin/audit", headers=h, params={"offset": 3}).json()
    assert len(rest["items"]) == len(data.AUDIT) - 3 and not rest["has_more"]


def test_audit_filters(client, seeded):
    h = login(client, "ansh")

    def actions(**params):
        r = client.get(f"{API}/admin/audit", headers=h, params=params)
        assert r.status_code == 200, r.text
        return [x["action"] for x in r.json()["items"]]

    assert actions(actor_id=uid("rahul")) == ["expense.create"]
    # Done as Priya: only the admin's edit, which Ansh made while viewing as her.
    assert actions(target_user_id=uid("priya")) == ["expense.update"]
    # Ansh's own trail leaves out what he did as Priya.
    assert "expense.update" not in actions(target_user_id=uid("ansh"))
    assert "expense.update" in actions(actor_id=uid("ansh"))
    assert actions(entity="settlement") == ["settlement.create"]
    assert sorted(actions(entity=["settlement", "import_batch"])) == [
        "import.complete",
        "settlement.create",
    ]
    assert actions(admin_only=True) == ["expense.update"]
    assert actions(start="2026-09-23", end="2026-09-23") == [
        "expense.create",
        "expense.update",
        "expense.create",
    ]
    assert actions(end="2026-09-21") == ["expense.delete", "member.join"]
    assert actions(start="2026-10-01") == []


def test_audit_where_column(client, seeded):
    items = client.get(f"{API}/admin/audit", headers=login(client, "ansh")).json()["items"]
    where = {x["action"]: (x["group"] or {}).get("name") for x in items}
    assert where["settlement.create"] == "Goa Trip"
    assert where["expense.delete"] == "Flatmates"
    assert where["import.complete"] == "Goa Trip"
    assert where["member.join"] == "Goa Trip"
    deleted = next(x for x in items if x["action"] == "expense.delete")
    assert deleted["summary"] == "Deleted “Water cans” · restorable"
    pay = next(x for x in items if x["action"] == "settlement.create")
    assert pay["summary"] == "Recorded a payment · Ansh paid Rahul ₹500"


def test_every_audit_line_is_words(client, seeded):
    """No action falls through to its raw name ("group.tricount_link") in the audit log."""
    h = login(client, "ansh")
    register(client, "Neha", "neha.k@example.com")
    flat = gid("flat")
    assert (
        client.patch(f"{API}/groups/{flat}", headers=h, json={"archived": True}).status_code == 200
    )
    assert (
        client.patch(f"{API}/groups/{flat}", headers=h, json={"archived": False}).status_code == 200
    )
    r = client.post(
        f"{API}/groups/{flat}/members",
        headers=h,
        json={"email": "meera@example.com", "name": "Meera"},
    )
    assert r.status_code == 201, r.text
    e = client.post(f"{API}/groups/{gid('goa')}/expenses", headers=h, json=expense_body()).json()
    r = client.put(
        f"{API}/expenses/{e['id']}", headers=h, json=expense_body(category_id=cat("travel"))
    )
    assert r.status_code == 200, r.text

    items = client.get(f"{API}/admin/audit?limit=200", headers=h).json()["items"]
    lines = {x["summary"] for x in items}
    assert {
        "Signed up",
        "Archived “Flatmates”",
        "Unarchived “Flatmates”",
        "Added Meera without an account",
        "Changed the category of “Parasailing”",
    } <= lines
    raw = [x["summary"] for x in items if re.search(r"[a-z]_[a-z]|^[a-z]+\.[a-z]+$", x["summary"])]
    assert raw == []


def test_record_refuses_a_read_only_actor():
    """The second line of defence behind the auth-layer check: nothing gets recorded."""
    from app.core.errors import ApiError
    from app.core.events import record
    from app.modules.auth.deps import Actor

    actor = Actor(user=User(id=uuid.uuid4(), name="Rahul"), admin_id=uuid.uuid4(), read_only=True)
    with pytest.raises(ApiError) as e:
        record(None, actor, "expense.create", "expense", uuid.uuid4())
    assert e.value.code == "read_only"
