from tests.api.conftest import gid, login, register, uid

API = "/api/v1"


def pay(client, headers, frm, to, amount, group="goa"):
    return client.post(
        f"{API}/groups/{gid(group)}/settlements",
        headers=headers,
        json={
            "from_user": uid(frm),
            "to_user": uid(to),
            "amount_minor": amount,
            "date": "2026-09-24",
            "method": "upi",
        },
    )


def people(client, headers, group="goa"):
    b = client.get(f"{API}/groups/{gid(group)}/balances", headers=headers).json()
    return {p["user"]["name"]: p["net_minor"] for p in b["people"]}


def test_settling_up_zeroes_the_balance(client, seeded):
    headers = login(client, "ansh")
    r = pay(client, headers, "ansh", "rahul", 50000)
    assert r.status_code == 201, r.text
    s = r.json()
    assert (s["from_user"]["name"], s["to_user"]["name"], s["currency"]) == (
        "Ansh C",
        "Rahul Sharma",
        "INR",
    )
    assert people(client, headers)["Rahul Sharma"] == 0


def test_recording_a_payment_someone_made_to_you(client, seeded):
    headers = login(client, "ansh")
    pay(client, headers, "priya", "ansh", 55000)
    assert people(client, headers)["Priya Nair"] == 100000


def test_settlement_never_touches_expenses(client, seeded):
    headers = login(client, "ansh")
    before = client.get(f"{API}/feed?limit=100", headers=headers).json()
    pay(client, headers, "ansh", "kabir", 75000)
    after = client.get(f"{API}/feed?limit=100", headers=headers).json()

    def expenses(items):
        return [
            (i["id"], i["amount_minor"], i["my_net_minor"]) for i in items if i["kind"] == "expense"
        ]

    assert expenses(before) == expenses(after)


def test_validation(client, seeded):
    headers = login(client, "ansh")
    assert pay(client, headers, "ansh", "ansh", 100).json()["error"]["code"] == "same_person"
    assert pay(client, headers, "ansh", "rahul", 0).status_code == 422
    r = pay(client, headers, "ansh", "rahul", 100, group="flat")
    assert r.json()["error"]["message"] == "Both people have to be in this group"


def test_delete_and_restore_payment(client, seeded):
    headers = login(client, "ansh")
    s = pay(client, headers, "ansh", "rahul", 50000).json()
    client.delete(f"{API}/settlements/{s['id']}", headers=headers)
    assert people(client, headers)["Rahul Sharma"] == -50000
    client.post(f"{API}/settlements/{s['id']}/restore", headers=headers)
    assert people(client, headers)["Rahul Sharma"] == 0


def test_list_and_permissions(client, seeded):
    headers = login(client, "ansh")
    assert [
        s["amount_minor"]
        for s in client.get(f"{API}/groups/{gid('goa')}/settlements", headers=headers).json()
    ] == [50000]
    stranger, _ = register(client, "Stranger", "stranger@example.com")
    assert client.get(f"{API}/groups/{gid('goa')}/settlements", headers=stranger).status_code == 404
