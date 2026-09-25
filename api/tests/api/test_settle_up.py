from tests.api.conftest import gid, login, register, uid

API = "/api/v1"


def plan(client, headers, friend):
    return client.get(f"{API}/friends/{uid(friend)}/settle-up", headers=headers).json()


def group_people(client, headers, group):
    b = client.get(f"{API}/groups/{gid(group)}/balances", headers=headers).json()
    return {p["user"]["name"]: p["net_minor"] for p in b["people"]}


def test_plan_lists_each_shared_group(client, seeded):
    p = plan(client, login(client, "ansh"), "aman")
    assert (p["friend"]["name"], p["currency"], p["net_minor"]) == ("Aman Verma", "INR", 117000)
    # oldest group first: Flatmates (June) before Goa Trip (September)
    assert [(g["name"], g["net_minor"]) for g in p["groups"]] == [
        ("Flatmates", 32000),
        ("Goa Trip", 85000),
    ]


def test_full_settle_up_zeroes_every_group(client, seeded):
    headers = login(client, "ansh")
    r = client.post(
        f"{API}/friends/{uid('aman')}/settle-up",
        headers=headers,
        json={"date": "2026-09-24", "method": "upi"},
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["remaining_net_minor"] == 0
    assert sorted((s["from_user"]["name"], s["amount_minor"]) for s in body["settlements"]) == [
        ("Aman Verma", 32000),
        ("Aman Verma", 85000),
    ]
    assert group_people(client, headers, "goa")["Aman Verma"] == 0
    assert group_people(client, headers, "flat")["Aman Verma"] == 0
    friends = {
        f["user"]["name"]: f["net_minor"]
        for f in client.get(f"{API}/balances", headers=headers).json()["friends"]
    }
    assert friends["Aman Verma"] == 0


def test_part_payment_pays_oldest_group_first(client, seeded):
    headers = login(client, "ansh")
    r = client.post(
        f"{API}/friends/{uid('aman')}/settle-up",
        headers=headers,
        json={"amount_minor": 50000, "date": "2026-09-24"},
    )
    assert r.status_code == 201, r.text
    assert r.json()["remaining_net_minor"] == 67000
    assert group_people(client, headers, "flat")["Aman Verma"] == 0
    assert group_people(client, headers, "goa")["Aman Verma"] == 85000 - 18000


def test_settling_when_you_owe(client, seeded):
    headers = login(client, "ansh")
    r = client.post(
        f"{API}/friends/{uid('rahul')}/settle-up", headers=headers, json={"date": "2026-09-24"}
    )
    s = r.json()["settlements"]
    assert [(x["from_user"]["name"], x["to_user"]["name"], x["amount_minor"]) for x in s] == [
        ("Ansh C", "Rahul Sharma", 50000)
    ]


def test_mixed_directions_are_cleared_in_each_group(client, seeded):
    headers = login(client, "ansh")
    # Make Ansh owe Aman ₹500 in Flatmates while Aman still owes ₹850 in Goa.
    client.post(
        f"{API}/groups/{gid('flat')}/settlements",
        headers=headers,
        json={
            "from_user": uid("aman"),
            "to_user": uid("ansh"),
            "amount_minor": 82000,
            "date": "2026-09-24",
        },
    )
    assert plan(client, headers, "aman")["groups"] == [
        {"group_id": gid("flat"), "name": "Flatmates", "net_minor": -50000},
        {"group_id": gid("goa"), "name": "Goa Trip", "net_minor": 85000},
    ]
    r = client.post(
        f"{API}/friends/{uid('aman')}/settle-up", headers=headers, json={"date": "2026-09-24"}
    )
    assert r.json()["remaining_net_minor"] == 0
    directions = sorted(
        (x["from_user"]["name"], x["amount_minor"]) for x in r.json()["settlements"]
    )
    assert directions == [("Aman Verma", 85000), ("Ansh C", 50000)]


def test_errors_are_explained(client, seeded):
    headers = login(client, "ansh")
    r = client.post(
        f"{API}/friends/{uid('vivek')}/settle-up", headers=headers, json={"date": "2026-09-24"}
    )
    assert r.status_code == 422 and r.json()["error"]["message"] == "You're already all square"
    r = client.post(
        f"{API}/friends/{uid('aman')}/settle-up",
        headers=headers,
        json={"amount_minor": 999999, "date": "2026-09-24"},
    )
    assert r.json()["error"]["message"] == "That's more than the balance between you"


def test_only_people_you_share_a_group_with(client, seeded):
    stranger_headers, stranger = register(client, "Stranger", "stranger@example.com")
    assert (
        client.get(f"{API}/friends/{uid('aman')}/settle-up", headers=stranger_headers).status_code
        == 404
    )
    assert (
        client.get(
            f"{API}/friends/{uid('ansh')}/settle-up", headers=login(client, "ansh")
        ).status_code
        == 404
    )


def test_settle_up_is_audited_per_settlement(client, seeded):
    from sqlalchemy import select

    from app.core.db import SessionLocal
    from app.models import AuditLog

    client.post(
        f"{API}/friends/{uid('aman')}/settle-up",
        headers=login(client, "ansh"),
        json={"date": "2026-09-24"},
    )
    with SessionLocal() as s:
        rows = s.scalars(select(AuditLog).where(AuditLog.action == "settlement.create")).all()
    assert sum(1 for r in rows if r.diff_json.get("via") == "settle_up") == 2
