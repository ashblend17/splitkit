from tests.api.conftest import login, register

API = "/api/v1"


def test_add_and_delete_own_category(client, seeded):
    headers = login(client, "ansh")
    c = client.post(
        f"{API}/categories",
        headers=headers,
        json={"label": "Pets", "icon": "health", "scope": "personal"},
    ).json()
    assert (c["key"], c["label"], c["owner_id"] is not None) == ("pets", "Pets", True)
    assert "Pets" in [
        x["label"] for x in client.get(f"{API}/categories?scope=personal", headers=headers).json()
    ]
    other, _ = register(client, "Other", "other@example.com")
    assert "Pets" not in [x["label"] for x in client.get(f"{API}/categories", headers=other).json()]
    dup = client.post(f"{API}/categories", headers=headers, json={"label": "pets"})
    assert dup.status_code == 409
    assert client.delete(f"{API}/categories/{c['id']}", headers=headers).status_code == 204


def test_cannot_delete_used_or_system_categories(client, seeded):
    headers = login(client, "ansh")
    food = next(
        x for x in client.get(f"{API}/categories", headers=headers).json() if x["key"] == "food"
    )
    assert client.delete(f"{API}/categories/{food['id']}", headers=headers).status_code == 404
    c = client.post(
        f"{API}/categories", headers=headers, json={"label": "Gym", "scope": "personal"}
    ).json()
    client.post(
        f"{API}/personal/transactions",
        headers=headers,
        json={
            "type": "expense",
            "amount_minor": 100000,
            "description": "Membership",
            "date": "2026-09-24",
            "category_id": c["id"],
        },
    )
    r = client.delete(f"{API}/categories/{c['id']}", headers=headers)
    assert (
        r.status_code == 409
        and r.json()["error"]["message"] == "This category is in use, so it can't be deleted"
    )


def test_keys_do_not_clash_with_system_keys(client, seeded):
    c = client.post(f"{API}/categories", headers=login(client, "ansh"), json={"label": "Food!"})
    assert c.status_code == 201 and c.json()["key"] == "food_2"  # "food" belongs to the built-in
