from tests.api.conftest import eid, gid, login, register, uid

API = "/api/v1"


def test_share_status_on_expense_detail(client, seeded):
    headers = login(client, "ansh")
    e = client.get(f"{API}/expenses/{eid('goa_dinner')}", headers=headers).json()
    # Rahul paid; everyone else still owes Rahul something in Goa Trip.
    assert {s["user"]["name"]: s["status"] for s in e["splits"]} == {
        "Rahul Sharma": "paid",
        "Ansh C": "owes",
        "Aman Verma": "owes",
        "Vivek Iyer": "owes",
    }
    client.post(
        f"{API}/groups/{gid('goa')}/settlements",
        headers=headers,
        json={
            "from_user": uid("ansh"),
            "to_user": uid("rahul"),
            "amount_minor": 50000,
            "date": "2026-09-24",
        },
    )
    e = client.get(f"{API}/expenses/{eid('goa_dinner')}", headers=headers).json()
    assert {s["user"]["name"]: s["status"] for s in e["splits"]}["Ansh C"] == "settled"


def test_expense_history(client, seeded):
    headers = login(client, "ansh")
    scooter = client.get(f"{API}/expenses/{eid('goa_scooter')}/history", headers=headers).json()
    assert [(h["action"], h["person"]["name"], h["admin"]["name"]) for h in scooter] == [
        ("expense.update", "Priya Nair", "Ansh C")
    ]
    e = client.get(f"{API}/expenses/{eid('goa_uber')}", headers=headers).json()
    body = {
        "description": e["description"],
        "amount_minor": 70000,
        "payer_id": e["payer"]["id"],
        "date": e["date"],
        "category_id": e["category"]["id"],
        "split": {"method": "equal", "inputs": [{"user_id": s["user"]["id"]} for s in e["splits"]]},
    }
    client.put(f"{API}/expenses/{eid('goa_uber')}", headers=headers, json=body)
    history = client.get(f"{API}/expenses/{eid('goa_uber')}/history", headers=headers).json()
    assert history[-1]["action"] == "expense.update"
    assert history[-1]["diff"]["amount_minor"] == {"from": 62000, "to": 70000}
    assert history[-1]["admin"] is None


def test_feed_marks_settled_shares(client, seeded):
    headers = login(client, "ansh")
    feed = {
        i["title"]: i
        for i in client.get(f"{API}/feed?limit=100", headers=headers).json()
        if i["title"]
    }
    assert feed["Dinner at Thalassa"]["settled"] is False  # Ansh owes Rahul
    # Aman paid the electricity bill, but in Flatmates Aman owes Ansh ₹320 overall, so Ansh is
    # square with the payer: Home shows "your share ₹800 · Settled", as in the mockup.
    assert feed["Electricity bill"]["settled"] is True
    assert feed["Groceries"]["settled"] is False  # Ansh paid; the flag is only for others' bills


def test_group_icons(client, seeded):
    headers = login(client, "ansh")
    assert {g["name"]: g["icon"] for g in client.get(f"{API}/groups", headers=headers).json()} == {
        "Goa Trip": "travel",
        "Flatmates": "rent",
    }
    g = client.post(
        f"{API}/groups", headers=headers, json={"name": "Office Lunch", "icon": "food"}
    ).json()
    assert g["icon"] == "food"
    assert (
        client.post(
            f"{API}/groups", headers=headers, json={"name": "X", "icon": "rocket"}
        ).status_code
        == 422
    )


def test_register_with_currency(client):
    r = client.post(
        f"{API}/auth/register",
        json={"name": "Sam", "email": "sam@example.com", "password": "12345678", "currency": "USD"},
    )
    assert r.json()["user"]["currency"] == "USD"
    assert (
        client.post(
            f"{API}/auth/register",
            json={"name": "X", "email": "x@example.com", "password": "12345678", "currency": "JPY"},
        ).status_code
        == 422
    )
    _, user = register(client, "Default", "default@example.com")
    assert user["currency"] == "INR"
