"""The sync change log: every write appends full state to its streams, in order, atomically."""

import uuid
from concurrent.futures import ThreadPoolExecutor

from sqlalchemy import select, update

from app.core.db import SessionLocal
from app.modules.sync.models import ChangeLog, SyncStream
from tests.api.conftest import cat, eid, gid, login, register, uid

API = "/api/v1"


def expense_body(amount=90000, description="Lunch", **extra):
    return {
        "description": description,
        "amount_minor": amount,
        "payer_id": uid("ansh"),
        "date": "2026-09-24",
        "category_id": cat("food"),
        "split": {
            "method": "equal",
            "inputs": [{"user_id": u} for u in (uid("ansh"), uid("aman"))],
        },
        **extra,
    }


def log_rows(stream: str) -> list[ChangeLog]:
    with SessionLocal() as s:
        return list(
            s.scalars(
                select(ChangeLog).where(ChangeLog.stream_id == stream).order_by(ChangeLog.seq)
            )
        )


def sync(client, headers, cursors=None, limit=500):
    r = client.post(f"{API}/sync", headers=headers, json={"cursors": cursors or {}, "limit": limit})
    assert r.status_code == 200, r.text
    return {s["stream"]: s for s in r.json()["streams"]}


FLAT = f"group:{gid('flat')}"


# ---- writing the log ----


def test_expense_lifecycle_is_logged_with_full_state(client, seeded):
    h = login(client, "ansh")
    created = client.post(f"{API}/groups/{gid('flat')}/expenses", headers=h, json=expense_body())
    e = created.json()
    assert (e["version"], created.status_code) == (1, 201)
    client.put(f"{API}/expenses/{e['id']}", headers=h, json=expense_body(amount=120000, version=1))
    client.delete(f"{API}/expenses/{e['id']}", headers=h)

    rows = log_rows(FLAT)
    assert [(r.seq, r.action, r.op, r.version) for r in rows] == [
        (1, "expense.create", "upsert", 1),
        (2, "expense.update", "upsert", 2),
        (3, "expense.delete", "upsert", 3),  # soft delete: still an upsert, with deleted_at
    ]
    after_update = rows[1].data
    assert after_update["amount_minor"] == 120000
    assert sorted(s["share_minor"] for s in after_update["splits"]) == [60000, 60000]
    assert after_update["category"]["label"] == "Food"
    assert rows[2].data["deleted_at"] is not None
    assert rows[0].actor_id == uuid.UUID(uid("ansh"))


def test_members_and_memberships_go_to_both_streams(client, seeded):
    h = login(client, "ansh")
    r = client.post(f"{API}/groups/{gid('flat')}/members", headers=h, json={"name": "Neha"})
    neha = next(m for m in r.json()["members"] if m["user"]["name"] == "Neha")["user"]
    [member] = log_rows(FLAT)
    assert (member.entity, member.data["user"]["name"], member.data["left_at"]) == (
        "member",
        "Neha",
        None,
    )
    [membership] = log_rows(f"user:{neha['id']}")
    assert (membership.entity, membership.data) == (
        "membership",
        {"group_id": gid("flat"), "active": True},
    )
    client.delete(f"{API}/groups/{gid('flat')}/members/{neha['id']}", headers=h)
    assert log_rows(f"user:{neha['id']}")[-1].data["active"] is False


def test_rename_reaches_every_group_the_person_is_in(client, seeded):
    h = login(client, "ansh")
    r = client.patch(f"{API}/me", headers=h, json={"name": "Ansh Chauhan", "version": 1})
    assert r.status_code == 200, r.text
    [profile] = log_rows(f"user:{uid('ansh')}")
    assert (profile.entity, profile.data["name"], profile.version) == ("profile", "Ansh Chauhan", 2)
    assert "password_hash" not in profile.data
    for group in ("goa", "flat"):
        [m] = log_rows(f"group:{gid(group)}")
        assert (m.entity, m.data["user"]["name"]) == ("member", "Ansh Chauhan")


def test_personal_categories_and_layout_go_to_the_user_stream(client, seeded):
    h = login(client, "ansh")
    stream = f"user:{uid('ansh')}"
    client.post(
        f"{API}/personal/transactions",
        headers=h,
        json={
            "type": "expense",
            "amount_minor": 25000,
            "description": "Books",
            "date": "2026-09-24",
        },
    )
    c = client.post(f"{API}/categories", headers=h, json={"label": "Pets", "scope": "personal"})
    client.delete(f"{API}/categories/{c.json()['id']}", headers=h)
    layout = client.get(f"{API}/analytics/layout/personal", headers=h).json()
    client.put(f"{API}/analytics/layout/personal", headers=h, json={"cards": layout["cards"][:2]})
    client.delete(f"{API}/analytics/layout/personal", headers=h)
    assert [(r.entity, r.op) for r in log_rows(stream)] == [
        ("personal_transaction", "upsert"),
        ("category", "upsert"),
        ("category", "delete"),  # hard delete: a tombstone
        ("layout", "upsert"),
        ("layout", "delete"),  # back to the defaults
    ]
    assert len(log_rows(stream)[3].data["cards"]) == 2


def test_register_is_audited_and_logged(client, seeded):
    _, user = register(client, "Zoya", "zoya@example.com")
    [profile] = log_rows(f"user:{user['id']}")
    assert (profile.action, profile.data["email"]) == ("user.register", "zoya@example.com")


def test_a_failed_write_uses_no_seq(client, seeded):
    h = login(client, "ansh")
    bad = expense_body(
        split={"method": "exact", "inputs": [{"user_id": uid("ansh"), "value": "1"}]}
    )
    assert (
        client.post(f"{API}/groups/{gid('flat')}/expenses", headers=h, json=bad).status_code == 422
    )
    client.post(f"{API}/groups/{gid('flat')}/expenses", headers=h, json=expense_body())
    assert [r.seq for r in log_rows(FLAT)] == [1]


def test_concurrent_writes_get_gap_free_seqs(client, seeded):
    h = login(client, "ansh")
    url = f"{API}/groups/{gid('flat')}/expenses"
    with ThreadPoolExecutor(8) as pool:
        codes = list(
            pool.map(
                lambda n: client.post(url, headers=h, json=expense_body(1000 + n)).status_code,
                range(12),
            )
        )
    assert codes == [201] * 12
    assert [r.seq for r in log_rows(FLAT)] == list(range(1, 13))
    with SessionLocal() as s:
        assert s.get(SyncStream, FLAT).head_seq == 12


def test_settle_up_across_groups_bumps_both_streams_at_once(client, seeded):
    h = login(client, "ansh")
    plan = client.get(f"{API}/friends/{uid('aman')}/settle-up", headers=h).json()
    assert len(plan["groups"]) == 2
    r = client.post(
        f"{API}/friends/{uid('aman')}/settle-up",
        headers=h,
        json={"date": "2026-09-24", "method": "cash"},
    )
    assert r.status_code == 201, r.text
    for group in ("goa", "flat"):
        [row] = log_rows(f"group:{gid(group)}")
        assert (row.entity, row.data["method"]) == ("settlement", "cash")


# ---- versions and client ids ----


def test_stale_versions_are_refused(client, seeded):
    h = login(client, "ansh")
    e = client.get(f"{API}/expenses/{eid('goa_dinner')}", headers=h).json()
    assert e["version"] == 1
    ok = client.put(f"{API}/expenses/{e['id']}", headers=h, json=expense_body(version=1))
    # The expense is in Goa; Aman is a member there too, so the body is valid.
    assert ok.status_code == 200, ok.text
    stale = client.put(f"{API}/expenses/{e['id']}", headers=h, json=expense_body(version=1))
    assert stale.status_code == 409
    assert stale.json()["error"]["code"] == "version_conflict"
    assert stale.json()["error"]["current_version"] == 2
    gone = client.delete(f"{API}/expenses/{e['id']}?version=1", headers=h)
    assert gone.status_code == 409
    assert client.delete(f"{API}/expenses/{e['id']}?version=2", headers=h).status_code == 200
    # No version sent: today's app keeps working as before.
    assert client.post(f"{API}/expenses/{e['id']}/restore", headers=h).status_code == 200


def test_group_and_profile_versions(client, seeded):
    h = login(client, "ansh")
    assert (
        client.patch(
            f"{API}/groups/{gid('flat')}", headers=h, json={"name": "Flat", "version": 1}
        ).status_code
        == 200
    )
    stale = client.patch(
        f"{API}/groups/{gid('flat')}", headers=h, json={"name": "Flat 2", "version": 1}
    )
    assert stale.status_code == 409
    assert client.patch(f"{API}/me", headers=h, json={"name": "A", "version": 7}).status_code == 409


def test_client_ids_make_creates_safe_to_retry(client, seeded):
    h = login(client, "ansh")
    new_id = str(uuid.uuid4())
    url = f"{API}/groups/{gid('flat')}/expenses"
    first = client.post(url, headers=h, json=expense_body(id=new_id))
    again = client.post(url, headers=h, json=expense_body(id=new_id))
    assert (first.status_code, first.json()["id"]) == (201, new_id)
    assert again.json()["id"] == new_id
    assert len(log_rows(FLAT)) == 1  # the retry wrote nothing
    # Someone else can't take over that id.
    other = client.post(url, headers=login(client, "aman"), json=expense_body(id=new_id))
    assert (other.status_code, other.json()["error"]["code"]) == (409, "id_taken")


def test_client_ids_for_personal_and_settlements(client, seeded):
    h = login(client, "ansh")
    txn = {
        "id": str(uuid.uuid4()),
        "type": "income",
        "amount_minor": 100,
        "description": "Refund",
        "date": "2026-09-24",
    }
    ids = {
        client.post(f"{API}/personal/transactions", headers=h, json=txn).json()["id"]
        for _ in range(2)
    }
    assert ids == {txn["id"]}
    pay = {
        "id": str(uuid.uuid4()),
        "from_user": uid("ansh"),
        "to_user": uid("aman"),
        "amount_minor": 100,
        "date": "2026-09-24",
    }
    url = f"{API}/groups/{gid('flat')}/settlements"
    assert {client.post(url, headers=h, json=pay).json()["id"] for _ in range(2)} == {pay["id"]}


# ---- catching up ----


def test_sync_lists_my_streams_and_asks_for_snapshots_first(client, seeded):
    streams = sync(client, login(client, "ansh"))
    assert set(streams) == {"global", f"user:{uid('ansh')}", f"group:{gid('goa')}", FLAT}
    assert {s["status"] for s in streams.values()} == {"snapshot_required"}
    # Kabir is only in Goa.
    assert f"group:{gid('flat')}" not in sync(client, login(client, "kabir"))


def test_sync_returns_only_newer_changes_in_pages(client, seeded):
    h = login(client, "ansh")
    for n in range(5):
        client.post(f"{API}/groups/{gid('flat')}/expenses", headers=h, json=expense_body(1000 + n))
    page = sync(client, h, {FLAT: 1}, limit=2)[FLAT]
    assert (page["status"], page["head_seq"], page["has_more"]) == ("ok", 5, True)
    assert [c["seq"] for c in page["changes"]] == [2, 3]
    rest = sync(client, h, {FLAT: 3}, limit=2)[FLAT]
    assert ([c["seq"] for c in rest["changes"]], rest["has_more"]) == ([4, 5], False)
    assert sync(client, h, {FLAT: 5})[FLAT]["changes"] == []
    change = rest["changes"][-1]
    assert (change["entity"], change["op"], change["data"]["amount_minor"]) == (
        "expense",
        "upsert",
        1004,
    )


def test_old_unknown_or_future_cursors_need_a_snapshot(client, seeded):
    h = login(client, "ansh")
    for n in range(3):
        client.post(f"{API}/groups/{gid('flat')}/expenses", headers=h, json=expense_body(1000 + n))
    with SessionLocal.begin() as s:
        s.execute(update(SyncStream).where(SyncStream.id == FLAT).values(oldest_seq=2))
    assert sync(client, h, {FLAT: 1})[FLAT]["status"] == "snapshot_required"  # trimmed away
    assert sync(client, h, {FLAT: 2})[FLAT]["status"] == "ok"
    assert sync(client, h, {FLAT: 99})[FLAT]["status"] == "snapshot_required"  # server was reset


def test_leaving_a_group_makes_its_stream_gone(client, seeded):
    headers, user = register(client, "Zoya", "zoya@example.com")
    h = login(client, "ansh")
    client.post(
        f"{API}/groups/{gid('flat')}/members", headers=h, json={"email": "zoya@example.com"}
    )
    assert FLAT in sync(client, headers)
    client.delete(f"{API}/groups/{gid('flat')}/members/{user['id']}", headers=headers)
    streams = sync(client, headers, {FLAT: 1})
    assert streams[FLAT]["status"] == "gone"
    # Their own stream says why: the membership went inactive.
    mine = sync(client, headers, {f"user:{user['id']}": 0})[f"user:{user['id']}"]
    assert [c["data"]["active"] for c in mine["changes"] if c["entity"] == "membership"] == [
        True,
        False,
    ]


# ---- snapshots ----


def test_group_snapshot_has_everything_including_deleted(client, seeded):
    h = login(client, "ansh")
    client.post(f"{API}/groups/{gid('flat')}/expenses", headers=h, json=expense_body())
    snap = client.get(f"{API}/sync/snapshot/{FLAT}", headers=h).json()
    kinds = [e["entity"] for e in snap["entities"]]
    assert snap["head_seq"] == 1
    assert kinds.count("group") == 1
    assert kinds.count("member") == 3
    assert kinds.count("expense") == 12 + 1  # seeded Flatmates expenses plus the new one
    names = {e["data"]["user"]["name"] for e in snap["entities"] if e["entity"] == "member"}
    assert names == {"Ansh C", "Aman Verma", "Vivek Iyer"}
    # Snapshot and log entries have the same shape, so clients apply both the same way.
    new = next(
        e
        for e in snap["entities"]
        if e["entity"] == "expense" and e["data"]["amount_minor"] == 90000
    )
    assert new["data"] == log_rows(FLAT)[0].data


def test_user_and_global_snapshots(client, seeded):
    h = login(client, "ansh")
    mine = client.get(f"{API}/sync/snapshot/user:{uid('ansh')}", headers=h).json()
    kinds = [e["entity"] for e in mine["entities"]]
    assert kinds.count("profile") == 1
    assert kinds.count("membership") == 2
    assert kinds.count("personal_transaction") >= 50
    assert "member" not in kinds  # those belong to group streams
    world = client.get(f"{API}/sync/snapshot/global", headers=h).json()
    assert {e["entity"] for e in world["entities"]} == {"category", "layout"}
    assert {e["data"]["scope"] for e in world["entities"] if e["entity"] == "layout"} == {
        "personal",
        "group",
    }


def test_snapshots_of_other_peoples_streams_are_hidden(client, seeded):
    headers, _ = register(client, "Zoya", "zoya@example.com")
    assert client.get(f"{API}/sync/snapshot/{FLAT}", headers=headers).status_code == 404
    assert client.get(f"{API}/sync/snapshot/user:{uid('ansh')}", headers=headers).status_code == 404
