"""app.validate finds planted problems; app.recover repairs what it says it repairs."""

from sqlalchemy import text

from app import recover, validate
from app.core.db import SessionLocal
from tests.api.conftest import gid, login, uid
from tests.api.test_expenses import dinner as dinner_body


def failing(session) -> set[str]:
    return {r.check.key for r in validate.run(session) if not r.ok}


def sync(client, h, cursors):
    r = client.post("/api/v1/sync", headers=h, json={"cursors": cursors})
    return {s["stream"]: s for s in r.json()["streams"]}


def test_seeded_data_is_valid(seeded):
    with SessionLocal() as session:
        assert failing(session) == set()
    assert validate.main([]) == 0


def test_planted_problems_are_found(client, seeded):
    h = login(client, "ansh")
    client.post(f"/api/v1/groups/{gid('goa')}/expenses", headers=h, json=dinner_body())
    with SessionLocal.begin() as session:
        stranger = session.execute(
            text(
                "INSERT INTO users (id, name, email) "
                "VALUES (gen_random_uuid(), 'Stranger', 'stranger@example.com') RETURNING id"
            )
        ).scalar_one()
        session.execute(text("UPDATE settlements SET to_user = :u"), {"u": stranger})
        session.execute(text("UPDATE groups SET version = 0 WHERE name = 'Flatmates'"))
        ghost = session.execute(
            text("INSERT INTO users (id, name) VALUES (gen_random_uuid(), 'Ghost') RETURNING id")
        ).scalar_one()
        session.execute(
            text(
                "INSERT INTO personal_transactions (id, user_id, type, amount_minor, currency, "
                "date, description) VALUES (gen_random_uuid(), :u, 'expense', 100, 'INR', "
                "'2026-09-25', 'x')"
            ),
            {"u": ghost},
        )
        session.execute(
            text(
                "UPDATE expenses SET version = version + 5 WHERE description = 'Dinner at Thalassa'"
            )
        )
    with SessionLocal() as session:
        found = failing(session)
    assert {
        "settlements_are_between_members",
        "versions_start_at_one",
        "accounts_are_sane",
        "sync_log_matches_tables",
    } <= found
    assert validate.main(["--json"]) == 1


def test_a_gap_is_found_and_reset_stream_repairs_it(client, seeded):
    h = login(client, "ansh")
    stream = f"group:{gid('goa')}"
    for _ in range(3):
        r = client.post(f"/api/v1/groups/{gid('goa')}/expenses", headers=h, json=dinner_body())
        assert r.status_code == 201
    head = sync(client, h, {})[stream]["head_seq"]
    with SessionLocal.begin() as session:
        session.execute(
            text("DELETE FROM change_log WHERE stream_id = :s AND seq = 2"), {"s": stream}
        )
    with SessionLocal() as session:
        assert "sync_streams_are_gap_free" in failing(session)

    with SessionLocal.begin() as session:
        new_head = recover.reset_stream(session, stream)
    assert new_head > head
    with SessionLocal() as session:
        assert failing(session) == set()
    # A device at any old cursor reloads; one at the new head carries on.
    assert sync(client, h, {stream: head})[stream]["status"] == "snapshot_required"
    snap = client.get(f"/api/v1/sync/snapshot/{stream}", headers=h).json()
    assert snap["head_seq"] == new_head
    assert sync(client, h, {stream: new_head})[stream]["status"] == "ok"


def test_reset_every_stream(client, seeded):
    with SessionLocal.begin() as session:
        streams = recover.all_streams(session)
        for s in streams:
            recover.reset_stream(session, s)
    assert "global" in streams and f"group:{gid('goa')}" in streams
    with SessionLocal() as session:
        assert failing(session) == set()


def test_end_admin_sessions(client, seeded):
    admin = login(client, "ansh")
    start = client.post(
        "/api/v1/admin/sessions", headers=admin, json={"target_user_id": uid("rahul")}
    ).json()
    view_as = {"Authorization": f"Bearer {start['access_token']}"}
    assert client.get("/api/v1/me", headers=view_as).status_code == 200
    assert recover.main(["end-admin-sessions"]) == 0
    assert client.get("/api/v1/me", headers=view_as).status_code == 401
