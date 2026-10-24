from tests.api.conftest import cat, eid, gid, login, register, uid

API = "/api/v1"


def dinner(**overrides):
    body = {
        "description": "Dinner at Thalassa",
        "amount_minor": 180000,
        "payer_id": uid("rahul"),
        "date": "2026-09-24",
        "category_id": cat("food"),
        "split": {
            "method": "equal",
            "inputs": [{"user_id": uid(p)} for p in ("john", "rahul", "aman", "vivek")],
        },
    }
    return {**body, **overrides}


def test_create_equal_expense(client, seeded):
    r = client.post(
        f"{API}/groups/{gid('goa')}/expenses", headers=login(client, "john"), json=dinner()
    )
    assert r.status_code == 201, r.text
    e = r.json()
    assert [s["share_minor"] for s in e["splits"]] == [45000] * 4
    assert (e["my_share_minor"], e["my_net_minor"]) == (45000, -45000)  # "You will owe Rahul ₹450"
    assert e["payer"]["name"] == "Rahul Sharma" and e["category"]["label"] == "Food"
    assert e["currency"] == "INR" and e["acting_admin_id"] is None


def test_split_validation_message_comes_back(client, seeded):
    body = dinner(
        split={
            "method": "exact",
            "inputs": [
                {"user_id": uid("john"), "value": 60000},
                {"user_id": uid("rahul"), "value": 40000},
                {"user_id": uid("aman"), "value": 50000},
                {"user_id": uid("vivek"), "value": 20000},
            ],
        }
    )
    r = client.post(f"{API}/groups/{gid('goa')}/expenses", headers=login(client, "john"), json=body)
    assert r.status_code == 422
    assert r.json()["error"] == {
        "code": "split_invalid",
        "message": "₹100 still needs to be allocated",
        "remaining_minor": 10000,
    }


def test_percent_split_with_decimal_strings(client, seeded):
    body = dinner(
        amount_minor=10000,
        split={
            "method": "percent",
            "inputs": [
                {"user_id": uid("john"), "value": "33.33"},
                {"user_id": uid("rahul"), "value": "33.33"},
                {"user_id": uid("aman"), "value": "33.34"},
            ],
        },
    )
    e = client.post(
        f"{API}/groups/{gid('goa')}/expenses", headers=login(client, "john"), json=body
    ).json()
    assert [(s["share_minor"], s["input_value"]) for s in e["splits"]] == [
        (3333, "33.33"),
        (3333, "33.33"),
        (3334, "33.34"),
    ]


def test_unknown_method_and_bad_exact_value(client, seeded):
    headers = login(client, "john")
    r = client.post(
        f"{API}/groups/{gid('goa')}/expenses",
        headers=headers,
        json=dinner(split={"method": "itemised", "inputs": []}),
    )
    assert r.json()["error"]["code"] == "unknown_split_method"
    r = client.post(
        f"{API}/groups/{gid('goa')}/expenses",
        headers=headers,
        json=dinner(
            amount_minor=100,
            split={
                "method": "exact",
                "inputs": [
                    {"user_id": uid("john"), "value": "99.5"},
                    {"user_id": uid("rahul"), "value": "0.5"},
                ],
            },
        ),
    )
    assert r.status_code == 422 and r.json()["error"]["code"] == "split_input_invalid"


def test_people_must_be_group_members(client, seeded):
    headers = login(client, "john")
    r = client.post(f"{API}/groups/{gid('flat')}/expenses", headers=headers, json=dinner())
    assert r.json()["error"]["code"] == "payer_not_member"
    body = dinner(payer_id=uid("john"))
    r = client.post(f"{API}/groups/{gid('flat')}/expenses", headers=headers, json=body)
    assert r.json()["error"]["message"] == "Everyone in the split has to be in this group"


def test_category_must_be_a_group_category(client, seeded):
    r = client.post(
        f"{API}/groups/{gid('goa')}/expenses",
        headers=login(client, "john"),
        json=dinner(category_id=cat("income")),
    )
    assert r.json()["error"]["code"] == "unknown_category"


def test_non_member_cannot_read_or_write(client, seeded):
    headers, _ = register(client, "Stranger", "stranger@example.com")
    assert client.get(f"{API}/expenses/{eid('goa_dinner')}", headers=headers).status_code == 404
    assert (
        client.post(
            f"{API}/groups/{gid('goa')}/expenses", headers=headers, json=dinner()
        ).status_code
        == 404
    )


def test_get_seeded_expense_detail(client, seeded):
    e = client.get(
        f"{API}/expenses/{eid('flat_electricity')}", headers=login(client, "john")
    ).json()
    assert e["split_method"] == "shares"
    assert {s["user"]["name"]: (s["share_minor"], s["input_value"]) for s in e["splits"]} == {
        "John Doe": (80000, "1"),
        "Aman Verma": (160000, "2"),
        "Vivek Iyer": (80000, "1"),
    }


def test_update_replaces_splits_and_moves_balances(client, seeded):
    headers = login(client, "john")
    body = dinner(
        amount_minor=180000,
        split={"method": "equal", "inputs": [{"user_id": uid("john")}, {"user_id": uid("rahul")}]},
    )
    r = client.put(f"{API}/expenses/{eid('goa_dinner')}", headers=headers, json=body)
    assert r.status_code == 200, r.text
    assert [s["share_minor"] for s in r.json()["splits"]] == [90000, 90000]
    people = {
        p["user"]["name"]: p["net_minor"]
        for p in client.get(f"{API}/groups/{gid('goa')}/balances", headers=headers).json()["people"]
    }
    assert people["Rahul Sharma"] == -50000 - 45000  # now owes Rahul ₹450 more
    # Aman and Vivek were taken off a bill Rahul paid: only their balance with Rahul moves.
    assert people["Aman Verma"] == 85000 and people["Vivek Iyer"] == 0


def test_delete_and_restore(client, seeded):
    headers = login(client, "john")
    r = client.delete(f"{API}/expenses/{eid('goa_dinner')}", headers=headers)
    assert r.json()["deleted_at"] is not None
    goa = client.get(f"{API}/groups/{gid('goa')}", headers=headers).json()
    assert goa["my_net_minor"] == 115000 + 45000
    assert (
        client.put(
            f"{API}/expenses/{eid('goa_dinner')}", headers=headers, json=dinner()
        ).status_code
        == 409
    )
    trash = client.get(f"{API}/feed?group_id={gid('goa')}&deleted=true", headers=headers).json()
    assert [i["title"] for i in trash] == ["Dinner at Thalassa"]

    r = client.post(f"{API}/expenses/{eid('goa_dinner')}/restore", headers=headers)
    assert r.json()["deleted_at"] is None
    assert (
        client.get(f"{API}/groups/{gid('goa')}", headers=headers).json()["my_net_minor"] == 115000
    )


def test_writes_are_audited(client, seeded):
    from sqlalchemy import select

    from app.core.db import SessionLocal
    from app.models import ActivityEvent, AuditLog

    r = client.post(
        f"{API}/groups/{gid('goa')}/expenses", headers=login(client, "john"), json=dinner()
    )
    new_id = r.json()["id"]
    with SessionLocal() as s:
        audit = s.scalar(select(AuditLog).where(AuditLog.entity_id == new_id))
        event = s.scalar(select(ActivityEvent).where(ActivityEvent.entity_id == new_id))
    assert (audit.action, str(audit.actor_id), audit.acting_as_id) == (
        "expense.create",
        uid("john"),
        None,
    )
    assert (event.type, event.acting_admin_id) == ("expense.create", None)


def test_split_preview_and_methods(client, seeded):
    headers = login(client, "john")
    assert [m["key"] for m in client.get(f"{API}/splits/methods", headers=headers).json()] == [
        "equal",
        "exact",
        "percent",
        "shares",
    ]
    r = client.post(
        f"{API}/splits/preview",
        headers=headers,
        json={
            "method": "percent",
            "total_minor": 180000,
            "inputs": [
                {"user_id": uid("john"), "value": 40},
                {"user_id": uid("rahul"), "value": 50},
            ],
        },
    )
    assert r.status_code == 200
    assert (r.json()["ok"], r.json()["message"]) == (
        False,
        "10% (₹180) still needs to be allocated",
    )


def test_categories_come_from_the_table(client, seeded):
    headers = login(client, "john")
    group = [
        c["label"] for c in client.get(f"{API}/categories?scope=group", headers=headers).json()
    ]
    assert group == [
        "Food",
        "Transport",
        "Shopping",
        "Fun",
        "Travel",
        "Stay",
        "Rent",
        "Bills",
        "Other",
    ]
    personal = [
        c["key"] for c in client.get(f"{API}/categories?scope=personal", headers=headers).json()
    ]
    assert "income" in personal and "travel" not in personal


def test_splits_keep_the_order_they_were_entered(client, seeded):
    """Every read, and the sync log, lists splits in input order, also after an edit."""
    h = login(client, "john")
    people = ["vivek", "john", "aman", "rahul"]
    split = {"method": "equal", "inputs": [{"user_id": uid(p)} for p in people]}
    e = client.post(f"{API}/groups/{gid('goa')}/expenses", headers=h, json=dinner(split=split))
    assert [s["user"]["id"] for s in e.json()["splits"]] == [uid(p) for p in people]

    edited = ["rahul", "vivek", "john"]
    body = dinner(split={"method": "equal", "inputs": [{"user_id": uid(p)} for p in edited]})
    r = client.put(f"{API}/expenses/{e.json()['id']}", headers=h, json=body)
    assert r.status_code == 200, r.text
    for _ in range(3):
        again = client.get(f"{API}/expenses/{e.json()['id']}", headers=h).json()
        assert [s["user"]["id"] for s in again["splits"]] == [uid(p) for p in edited]
    stream = f"group:{gid('goa')}"
    snap = client.get(f"{API}/sync/snapshot/{stream}", headers=h).json()
    entity = next(x for x in snap["entities"] if x["entity_id"] == e.json()["id"])
    assert [s["user_id"] for s in entity["data"]["splits"]] == [uid(p) for p in edited]
