from tests.api.conftest import cat, login, register

API = "/api/v1"


def test_september_summary_matches_personal_mockup(client, seeded):
    s = client.get(f"{API}/personal/summary?month=2026-09-23", headers=login(client, "ansh")).json()
    assert (s["month"], s["spent_minor"], s["income_minor"], s["left_over_minor"]) == (
        "2026-09",
        3245000,
        8500000,
        5255000,
    )
    assert [(c["label"], c["amount_minor"]) for c in s["by_category"][:3]] == [
        ("Rent", 1800000),
        ("Food", 582000),
        ("Transport", 294000),
    ]
    # Goa Trip share (₹10,830) + Flatmates September shares (₹5,000 + ₹800 + ₹800 + ₹780)
    assert s["group_share_minor"] == 1083000 + 738000


def test_history_filters_match_history_mockup(client, seeded):
    headers = login(client, "ansh")
    r = client.get(
        f"{API}/personal/transactions?start=2026-09-01&end=2026-09-23&type=expense"
        "&category=food&category=transport",
        headers=headers,
    ).json()
    assert r["spent_minor"] == 876000  # "Total ₹8,760"
    assert r["count"] == 10 and r["income_minor"] == 0
    assert r["items"][0]["description"] == "Swiggy order"
    assert {i["category"]["label"] for i in r["items"]} == {"Food", "Transport"}


def test_personal_is_private(client, seeded):
    other, _ = register(client, "Someone", "someone@example.com")
    assert client.get(f"{API}/personal/transactions", headers=other).json()["count"] == 0
    mine = client.get(f"{API}/personal/transactions?limit=1", headers=login(client, "ansh")).json()[
        "items"
    ][0]
    assert client.get(f"{API}/personal/transactions/{mine['id']}", headers=other).status_code == 404


def test_create_edit_delete_restore(client, seeded):
    headers = login(client, "ansh")
    body = {
        "type": "expense",
        "amount_minor": 45000,
        "description": "Books",
        "date": "2026-09-24",
        "category_id": cat("shopping"),
        "notes": "Card",
    }
    t = client.post(f"{API}/personal/transactions", headers=headers, json=body).json()
    assert (t["currency"], t["category"]["label"]) == ("INR", "Shopping")
    t = client.put(
        f"{API}/personal/transactions/{t['id']}",
        headers=headers,
        json={**body, "amount_minor": 50000},
    ).json()
    assert t["amount_minor"] == 50000
    assert client.delete(f"{API}/personal/transactions/{t['id']}", headers=headers).json()[
        "deleted_at"
    ]
    deleted = client.get(f"{API}/personal/transactions?deleted=true", headers=headers).json()
    assert [i["description"] for i in deleted["items"]] == ["Books"]
    client.post(f"{API}/personal/transactions/{t['id']}/restore", headers=headers)
    assert (
        client.get(f"{API}/personal/summary?month=2026-09-01", headers=headers).json()[
            "spent_minor"
        ]
        == 3245000 + 50000
    )


def test_group_only_categories_are_rejected(client, seeded):
    r = client.post(
        f"{API}/personal/transactions",
        headers=login(client, "ansh"),
        json={
            "type": "expense",
            "amount_minor": 100,
            "description": "x",
            "date": "2026-09-24",
            "category_id": cat("travel"),
        },
    )
    assert r.status_code == 422 and r.json()["error"]["code"] == "unknown_category"


def test_totals_only_count_your_current_currency(client, seeded):
    headers = login(client, "ansh")
    client.patch(f"{API}/me", headers=headers, json={"currency": "USD"})
    body = {"type": "expense", "amount_minor": 1250, "description": "Coffee", "date": "2026-09-20"}
    assert (
        client.post(f"{API}/personal/transactions", headers=headers, json=body).status_code == 201
    )
    s = client.get(f"{API}/personal/summary?month=2026-09-23", headers=headers).json()
    # The rupee entries and INR groups aren't added to dollars.
    assert (s["currency"], s["spent_minor"], s["income_minor"], s["group_share_minor"]) == (
        "USD",
        1250,
        0,
        0,
    )
    listed = client.get(
        f"{API}/personal/transactions?start=2026-09-01&end=2026-09-30", headers=headers
    ).json()
    assert listed["spent_minor"] == 1250 and listed["count"] > 1
    assert {i["currency"] for i in listed["items"]} == {"INR", "USD"}
    cards = client.get(f"{API}/analytics/personal?on=2026-09-23", headers=headers).json()["cards"]
    monthly = next(c for c in cards if c["source"] == "personal_monthly")
    assert monthly["headline"] == "$12.50"
