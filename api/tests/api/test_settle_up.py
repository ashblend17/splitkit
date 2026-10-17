from tests.api.conftest import gid, login, register, uid

API = "/api/v1"


def plan(client, headers, friend):
    return client.get(f"{API}/friends/{uid(friend)}/settle-up", headers=headers).json()


def between(client, headers, group, a, b):
    """What the group's fewest payments have a paying b."""
    s = client.get(f"{API}/groups/{gid(group)}/balances", headers=headers).json()["suggested"]
    return sum(
        p["amount_minor"]
        for p in s
        if (p["from_user"]["id"], p["to_user"]["id"]) == (uid(a), uid(b))
    )


def test_plan_lists_each_shared_group(client, seeded):
    p = plan(client, login(client, "john"), "vivek")
    assert (p["friend"]["name"], p["currency"], p["net_minor"]) == ("Vivek Iyer", "INR", 147000)
    # What each group's fewest payments have Vivek paying John, oldest group first:
    # Flatmates (June) before Goa Trip (September).
    assert [(g["name"], g["net_minor"]) for g in p["groups"]] == [
        ("Flatmates", 32000),
        ("Goa Trip", 115000),
    ]


def test_full_settle_up_zeroes_every_group(client, seeded):
    headers = login(client, "john")
    r = client.post(
        f"{API}/friends/{uid('vivek')}/settle-up",
        headers=headers,
        json={"date": "2026-09-24", "method": "upi"},
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["remaining_net_minor"] == 0
    assert sorted((s["from_user"]["name"], s["amount_minor"]) for s in body["settlements"]) == [
        ("Vivek Iyer", 32000),
        ("Vivek Iyer", 115000),
    ]
    for group in ("goa", "flat"):
        assert between(client, headers, group, "vivek", "john") == 0
        b = client.get(f"{API}/groups/{gid(group)}/balances", headers=headers).json()
        assert b["net_minor"] == 0
    friends = {
        f["user"]["name"]: f["net_minor"]
        for f in client.get(f"{API}/balances", headers=headers).json()["friends"]
    }
    assert set(friends.values()) == {0}


def test_part_payment_pays_oldest_group_first(client, seeded):
    headers = login(client, "john")
    r = client.post(
        f"{API}/friends/{uid('vivek')}/settle-up",
        headers=headers,
        json={"amount_minor": 50000, "date": "2026-09-24"},
    )
    assert r.status_code == 201, r.text
    assert r.json()["remaining_net_minor"] == 97000
    assert between(client, headers, "flat", "vivek", "john") == 0
    assert between(client, headers, "goa", "vivek", "john") == 115000 - 18000


def test_settling_when_you_owe(client, seeded):
    headers = login(client, "vivek")
    r = client.post(
        f"{API}/friends/{uid('rahul')}/settle-up", headers=headers, json={"date": "2026-09-24"}
    )
    s = r.json()["settlements"]
    assert [(x["from_user"]["name"], x["to_user"]["name"], x["amount_minor"]) for x in s] == [
        ("Vivek Iyer", "Rahul Sharma", 111000)
    ]


def test_mixed_directions_are_cleared_in_each_group(client, seeded):
    headers = login(client, "john")
    # Vivek overpays in Flatmates, so there the plan has John paying Vivek ₹440, while in Goa
    # Vivek still pays John ₹1,150.
    client.post(
        f"{API}/groups/{gid('flat')}/settlements",
        headers=headers,
        json={
            "from_user": uid("vivek"),
            "to_user": uid("john"),
            "amount_minor": 82000,
            "date": "2026-09-24",
        },
    )
    assert plan(client, headers, "vivek")["groups"] == [
        {"group_id": gid("flat"), "name": "Flatmates", "net_minor": -44000},
        {"group_id": gid("goa"), "name": "Goa Trip", "net_minor": 115000},
    ]
    r = client.post(
        f"{API}/friends/{uid('vivek')}/settle-up", headers=headers, json={"date": "2026-09-24"}
    )
    assert r.json()["remaining_net_minor"] == 0
    directions = sorted(
        (x["from_user"]["name"], x["amount_minor"]) for x in r.json()["settlements"]
    )
    assert directions == [("John Doe", 44000), ("Vivek Iyer", 115000)]


def test_errors_are_explained(client, seeded):
    headers = login(client, "john")
    # One-to-one Aman owes John, but neither group's plan has a payment between them.
    r = client.post(
        f"{API}/friends/{uid('aman')}/settle-up", headers=headers, json={"date": "2026-09-24"}
    )
    assert r.status_code == 422 and r.json()["error"]["message"] == "You're already all square"
    r = client.post(
        f"{API}/friends/{uid('vivek')}/settle-up",
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
            f"{API}/friends/{uid('john')}/settle-up", headers=login(client, "john")
        ).status_code
        == 404
    )


def test_settle_up_is_audited_per_settlement(client, seeded):
    from sqlalchemy import select

    from app.core.db import SessionLocal
    from app.models import AuditLog

    client.post(
        f"{API}/friends/{uid('vivek')}/settle-up",
        headers=login(client, "john"),
        json={"date": "2026-09-24"},
    )
    with SessionLocal() as s:
        rows = s.scalars(select(AuditLog).where(AuditLog.action == "settlement.create")).all()
    assert sum(1 for r in rows if r.diff_json.get("via") == "settle_up") == 2
