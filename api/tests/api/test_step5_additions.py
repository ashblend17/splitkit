from tests.api.conftest import eid, gid, login, register, uid

API = "/api/v1"


def test_share_status_on_expense_detail(client, seeded):
    headers = login(client, "john")
    e = client.get(f"{API}/expenses/{eid('goa_dinner')}", headers=headers).json()
    # Rahul paid. Goa Trip's fewest payments have John paying nobody (he is owed), so his share
    # is settled; Aman and Vivek still pay someone.
    assert {s["user"]["name"]: s["status"] for s in e["splits"]} == {
        "Rahul Sharma": "paid",
        "John Doe": "settled",
        "Aman Verma": "owes",
        "Vivek Iyer": "owes",
    }
    # Aman makes his payment in the plan, to Kabir rather than Rahul: his share is settled too.
    client.post(
        f"{API}/groups/{gid('goa')}/settlements",
        headers=headers,
        json={
            "from_user": uid("aman"),
            "to_user": uid("kabir"),
            "amount_minor": 7300,
            "date": "2026-09-24",
        },
    )
    e = client.get(f"{API}/expenses/{eid('goa_dinner')}", headers=headers).json()
    assert {s["user"]["name"]: s["status"] for s in e["splits"]}["Aman Verma"] == "settled"


def test_expense_history(client, seeded):
    headers = login(client, "john")
    scooter = client.get(f"{API}/expenses/{eid('goa_scooter')}/history", headers=headers).json()
    assert [(h["action"], h["person"]["name"], h["admin"]["name"]) for h in scooter] == [
        ("expense.update", "Priya Nair", "John Doe")
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
    headers = login(client, "john")

    def feed():
        items = client.get(f"{API}/feed?limit=100", headers=headers).json()
        return {i["title"]: i for i in items if i["title"]}

    # Each group's fewest payments have John paying nobody (he is owed in both), so his shares
    # of others' bills are settled: Home shows "your share ₹800 · Settled", as in the mockup.
    assert feed()["Dinner at Thalassa"]["settled"] is True
    assert feed()["Electricity bill"]["settled"] is True
    assert feed()["Groceries"]["settled"] is False  # John paid; the flag is only for others' bills
    # Vivek overpays him in Goa Trip, so there John now has a payment to make.
    client.post(
        f"{API}/groups/{gid('goa')}/settlements",
        headers=headers,
        json={
            "from_user": uid("vivek"),
            "to_user": uid("john"),
            "amount_minor": 200000,
            "date": "2026-09-24",
        },
    )
    assert feed()["Dinner at Thalassa"]["settled"] is False
    assert feed()["Electricity bill"]["settled"] is True  # Flatmates is unchanged


def test_group_icons(client, seeded):
    headers = login(client, "john")
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
