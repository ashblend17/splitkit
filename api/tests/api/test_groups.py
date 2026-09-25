from tests.api.conftest import gid, login, register, uid

API = "/api/v1"


def test_group_list_matches_group_list_mockup(client, seeded):
    groups = client.get(f"{API}/groups", headers=login(client, "ansh")).json()
    by_name = {g["name"]: g for g in groups}
    assert by_name["Goa Trip"]["total_spent_minor"] == 4826000
    assert by_name["Goa Trip"]["my_net_minor"] == 115000  # "you are owed ₹1,150"
    assert len(by_name["Goa Trip"]["members"]) == 6
    assert by_name["Flatmates"]["total_spent_minor"] == 6148000
    assert by_name["Flatmates"]["my_net_minor"] == 32000
    assert by_name["Goa Trip"]["last_activity_at"] is not None


def test_create_group_and_add_members(client, seeded):
    headers = login(client, "ansh")
    g = client.post(f"{API}/groups", headers=headers, json={"name": "Office Lunch"}).json()
    assert [m["role"] for m in g["members"]] == ["owner"] and g["my_net_minor"] == 0

    r = client.post(
        f"{API}/groups/{g['id']}/members",
        headers=headers,
        json={"email": "rahul.sharma@example.com"},
    )
    assert r.status_code == 201
    r = client.post(
        f"{API}/groups/{g['id']}/members", headers=headers, json={"name": "Sam (no account)"}
    )
    members = r.json()["members"]
    assert [m["user"]["name"] for m in members] == ["Ansh C", "Rahul Sharma", "Sam (no account)"]
    assert (
        members[2]["user"]["is_placeholder"]
        and members[2]["placeholder_name"] == "Sam (no account)"
    )

    again = client.post(
        f"{API}/groups/{g['id']}/members",
        headers=headers,
        json={"email": "rahul.sharma@example.com"},
    )
    assert again.status_code == 409


def test_add_member_needs_exactly_one_of_email_or_name(client, seeded):
    r = client.post(f"{API}/groups/{gid('goa')}/members", headers=login(client, "ansh"), json={})
    assert r.status_code == 422


def test_unknown_email_is_explained(client, seeded):
    r = client.post(
        f"{API}/groups/{gid('goa')}/members",
        headers=login(client, "ansh"),
        json={"email": "nobody@example.com"},
    )
    assert r.status_code == 404 and r.json()["error"]["code"] == "no_account"


def test_non_members_cannot_see_a_group(client, seeded):
    headers, _ = register(client, "Stranger", "stranger@example.com")
    assert client.get(f"{API}/groups/{gid('goa')}", headers=headers).status_code == 404
    assert client.get(f"{API}/groups", headers=headers).json() == []


def test_cannot_leave_with_an_open_balance(client, seeded):
    r = client.delete(
        f"{API}/groups/{gid('goa')}/members/{uid('rahul')}", headers=login(client, "rahul")
    )
    assert r.status_code == 409
    assert r.json()["error"]["message"] == "You need to settle up before leaving the group"


def test_only_owner_removes_others(client, seeded):
    r = client.delete(
        f"{API}/groups/{gid('flat')}/members/{uid('vivek')}", headers=login(client, "aman")
    )
    assert r.status_code == 403


def test_leave_when_settled(client, seeded):
    headers = login(client, "ansh")
    g = client.post(f"{API}/groups", headers=headers, json={"name": "Temp"}).json()
    client.post(
        f"{API}/groups/{g['id']}/members", headers=headers, json={"email": "vivek.iyer@example.com"}
    )
    r = client.delete(
        f"{API}/groups/{g['id']}/members/{uid('vivek')}", headers=login(client, "vivek")
    )
    assert r.status_code == 204
    assert [
        m["user"]["name"]
        for m in client.get(f"{API}/groups/{g['id']}", headers=headers).json()["members"]
    ] == ["Ansh C"]


def test_archive_moves_group_out_of_default_list(client, seeded):
    headers = login(client, "ansh")
    client.patch(f"{API}/groups/{gid('flat')}", headers=headers, json={"archived": True})
    assert [g["name"] for g in client.get(f"{API}/groups", headers=headers).json()] == ["Goa Trip"]
    assert [
        g["name"] for g in client.get(f"{API}/groups?archived=true", headers=headers).json()
    ] == ["Flatmates"]
