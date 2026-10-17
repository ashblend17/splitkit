"""app.validate finds planted problems; app.recover repairs what it says it repairs."""

from sqlalchemy import text

from app import recover, validate
from app.core.db import SessionLocal
from app.seed import data
from app.seed.loader import account_id
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
    h = login(client, "john")
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
                "INSERT INTO personal_transactions (id, user_id, type, direction, amount_minor, "
                "currency, date, description) VALUES (gen_random_uuid(), :u, 'expense', 'out', "
                "100, 'INR', '2026-09-25', 'x')"
            ),
            {"u": ghost},
        )
        session.execute(
            text(
                "UPDATE expenses SET version = version + 5 WHERE description = 'Dinner at Thalassa'"
            )
        )
        # John's Uber entry, linked to a split Rahul paid.
        session.execute(
            text(
                "UPDATE personal_transactions SET expense_id = "
                "(SELECT id FROM expenses WHERE description = 'Dinner at Thalassa' LIMIT 1) "
                "WHERE description = 'Uber to airport'"
            )
        )
    with SessionLocal.begin() as session:
        # Past the trigger and the foreign keys: a lone transfer leg, and an entry of Rahul's in
        # John's account.
        session.execute(text("SET LOCAL session_replication_role = replica"))
        hdfc = account_id(next(a for a in data.ACCOUNTS if a.key == "hdfc"))
        session.execute(
            text(
                "INSERT INTO personal_transactions (user_id, type, direction, amount_minor, "
                "currency, date, description, account_id, transfer_group_id) VALUES "
                "(:john, 'transfer', 'out', 100, 'INR', '2026-09-25', 'Half', :a, "
                "gen_random_uuid()), "
                "(:rahul, 'expense', 'out', 100, 'INR', '2026-09-25', 'Not mine', :a, NULL)"
            ),
            {"john": uid("john"), "rahul": uid("rahul"), "a": hdfc},
        )
        # The emergency fund follows Cash, which the trip jar's money went into (counted
        # twice), Cash is deleted under it, and the jar counts more than its entry.
        cash = account_id(next(a for a in data.ACCOUNTS if a.key == "cash"))
        session.execute(
            text("UPDATE personal_goals SET linked_account_id = :a WHERE name = 'Emergency fund'"),
            {"a": cash},
        )
        session.execute(
            text("UPDATE personal_accounts SET deleted_at = now() WHERE id = :a"), {"a": cash}
        )
        session.execute(
            text(
                "UPDATE personal_goal_contributions SET amount_minor = 900000 "
                "WHERE transaction_id IS NOT NULL"
            )
        )
        # September's salary deleted under its plans, and the account a rule sends money to
        # closed under it.
        session.execute(
            text(
                "UPDATE personal_transactions SET deleted_at = now() "
                "WHERE type = 'income' AND date = '2026-09-01'"
            )
        )
        session.execute(
            text("UPDATE personal_accounts SET status = 'closed' WHERE name = 'Emergency savings'")
        )
        # Zerodha made a bank account under its holdings, and the index fund deleted under the
        # SIP entry and reminder that name it.
        session.execute(text("UPDATE personal_accounts SET type = 'bank' WHERE name = 'Zerodha'"))
        session.execute(
            text(
                "UPDATE personal_holdings SET deleted_at = now() WHERE name = 'Nifty 50 index fund'"
            )
        )
    with SessionLocal() as session:
        found = failing(session)
    assert {
        "settlements_are_between_members",
        "versions_start_at_one",
        "accounts_are_sane",
        "sync_log_matches_tables",
        "personal_links_are_the_owners",
        "transfer_pairs_are_whole",
        "entries_use_own_accounts",
        "goal_contributions_count_once",
        "goal_contributions_fit",
        "linked_goals_follow_live_accounts",
        "allocation_plans_follow_their_income",
        "allocation_rules_point_somewhere",
        "holdings_are_in_investment_accounts",
        "reminder_schedules_point_somewhere",
    } <= found
    assert validate.main(["--json"]) == 1


def test_a_gap_is_found_and_reset_stream_repairs_it(client, seeded):
    h = login(client, "john")
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
    admin = login(client, "john")
    start = client.post(
        "/api/v1/admin/sessions", headers=admin, json={"target_user_id": uid("rahul")}
    ).json()
    view_as = {"Authorization": f"Bearer {start['access_token']}"}
    assert client.get("/api/v1/me", headers=view_as).status_code == 200
    assert recover.main(["end-admin-sessions"]) == 0
    assert client.get("/api/v1/me", headers=view_as).status_code == 401
