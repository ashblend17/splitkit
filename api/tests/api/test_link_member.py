"""Linking a placeholder member to an account: merge into an existing one, or invite an email
that signing up claims. Nobody's balance may move."""

from app import validate
from app.core.db import SessionLocal
from tests.api.conftest import login, register, uid

API = "/api/v1"


def flat(client):
    """John's new group with a placeholder "Sam". Returns (headers, group id, Sam's id)."""
    h = login(client, "john")
    g = client.post(f"{API}/groups", headers=h, json={"name": "Flat"}).json()
    g = client.post(f"{API}/groups/{g['id']}/members", headers=h, json={"name": "Sam"}).json()
    return h, g["id"], next(m["user"]["id"] for m in g["members"] if m["user"]["name"] == "Sam")


def spend(client, h, group, payer, amount, people):
    r = client.post(
        f"{API}/groups/{group}/expenses",
        headers=h,
        json={
            "description": "Groceries",
            "amount_minor": amount,
            "payer_id": payer,
            "date": "2026-10-01",
            "split": {"method": "equal", "inputs": [{"user_id": p} for p in people]},
        },
    )
    assert r.status_code == 201, r.text
    return r.json()


def pay(client, h, group, frm, to, amount):
    r = client.post(
        f"{API}/groups/{group}/settlements",
        headers=h,
        json={"from_user": frm, "to_user": to, "amount_minor": amount, "date": "2026-10-02"},
    )
    assert r.status_code == 201, r.text
    return r.json()


def link(client, h, group, member, email):
    return client.post(
        f"{API}/groups/{group}/members/{member}/link", headers=h, json={"email": email}
    )


def nets(client, h, group) -> dict[str, int]:
    r = client.get(f"{API}/groups/{group}/balances", headers=h)
    return {p["user"]["id"]: p["net_minor"] for p in r.json()["members"]}


def assert_valid():
    with SessionLocal() as session:
        assert {r.check.key for r in validate.run(session) if not r.ok} == set()


def test_link_to_an_existing_account_moves_everything(client, seeded):
    h, group, sam = flat(client)
    me = uid("john")
    spend(client, h, group, me, 30000, [me, sam])
    paid_by_sam = spend(client, h, group, sam, 20000, [me, sam])
    pay(client, h, group, sam, me, 5000)
    before = nets(client, h, group)
    sam_h, account = register(client, "Sam Rao", "sam@example.com")

    r = link(client, h, group, sam, "Sam@Example.com")

    assert r.status_code == 200, r.text
    members = {m["user"]["id"]: m for m in r.json()["members"]}
    assert set(members) == {me, account["id"]}
    assert members[account["id"]]["placeholder_name"] == "Sam"
    assert members[account["id"]]["user"]["is_placeholder"] is False
    assert nets(client, h, group) == {me: before[me], account["id"]: before[sam]}
    # Sam's account now sees the group, his position in it, and the expense he paid.
    mine = [g for g in client.get(f"{API}/groups", headers=sam_h).json() if g["id"] == group]
    assert [g["my_net_minor"] for g in mine] == [before[sam]]
    e = client.get(f"{API}/expenses/{paid_by_sam['id']}", headers=sam_h).json()
    assert e["payer"]["id"] == account["id"] and e["version"] > paid_by_sam["version"]
    stale = client.delete(
        f"{API}/expenses/{paid_by_sam['id']}?version={paid_by_sam['version']}", headers=h
    )
    assert stale.status_code == 409
    assert_valid()


def test_link_when_the_account_is_already_in_the_split(client, seeded):
    h, group, sam = flat(client)
    me, rahul = uid("john"), uid("rahul")
    client.post(
        f"{API}/groups/{group}/members", headers=h, json={"email": "rahul.sharma@example.com"}
    )
    shared = spend(client, h, group, me, 30000, [me, sam, rahul])
    between = pay(client, h, group, rahul, sam, 4000)  # between the two: it goes
    pay(client, h, group, sam, me, 1000)  # moves to Rahul
    before = nets(client, h, group)

    r = link(client, h, group, sam, "rahul.sharma@example.com")

    assert r.status_code == 200, r.text
    assert [m["user"]["id"] for m in r.json()["members"]] == [me, rahul]
    assert nets(client, h, group) == {me: before[me], rahul: before[rahul] + before[sam]}
    e = client.get(f"{API}/expenses/{shared['id']}", headers=h).json()
    assert e["split_method"] == "exact"
    assert {s["user"]["id"]: s["share_minor"] for s in e["splits"]} == {me: 10000, rahul: 20000}
    live = client.get(f"{API}/groups/{group}/settlements", headers=h).json()
    assert [(s["from_user"]["id"], s["to_user"]["id"], s["amount_minor"]) for s in live] == [
        (rahul, me, 1000)
    ]
    restore = client.post(f"{API}/settlements/{between['id']}/restore", headers=h)
    assert restore.status_code == 409 and restore.json()["error"]["code"] == "member_left"
    assert_valid()


def test_invite_then_sign_up_takes_the_placeholders_place(client, seeded):
    h, group, sam = flat(client)
    me = uid("john")
    spend(client, h, group, sam, 20000, [me, sam])
    before = nets(client, h, group)

    r = link(client, h, group, sam, "New.Sam@example.com")

    assert r.status_code == 200, r.text
    invited = next(m for m in r.json()["members"] if m["user"]["id"] == sam)
    assert invited["invite_email"] == "new.sam@example.com" and invited["user"]["is_placeholder"]
    assert_valid()

    sam_h, account = register(client, "Sam Rao", "new.sam@EXAMPLE.com")

    assert account["id"] == sam and account["email"] == "new.sam@example.com"
    g = client.get(f"{API}/groups/{group}", headers=sam_h).json()
    m = next(m for m in g["members"] if m["user"]["id"] == sam)
    assert m["user"]["name"] == "Sam Rao" and m["user"]["is_placeholder"] is False
    assert m["placeholder_name"] == "Sam" and m["invite_email"] is None
    assert g["my_net_minor"] == before[sam]
    assert nets(client, h, group) == before
    again = client.post(
        f"{API}/auth/login", json={"email": "new.sam@example.com", "password": "correct-horse"}
    )
    assert again.status_code == 200
    assert_valid()


def test_one_sign_up_claims_every_invite_for_its_email(client, seeded):
    h, flat_id, sam = flat(client)
    me = uid("john")
    trip = client.post(f"{API}/groups", headers=h, json={"name": "Trip"}).json()
    trip = client.post(
        f"{API}/groups/{trip['id']}/members", headers=h, json={"name": "Sammy"}
    ).json()
    sammy = next(m["user"]["id"] for m in trip["members"] if m["user"]["name"] == "Sammy")
    spend(client, h, flat_id, sam, 20000, [me, sam])
    spend(client, h, trip["id"], me, 9000, [me, sammy])
    before = {flat_id: nets(client, h, flat_id), trip["id"]: nets(client, h, trip["id"])}
    link(client, h, flat_id, sam, "sam@example.com")
    link(client, h, trip["id"], sammy, "sam@example.com")

    sam_h, account = register(client, "Sam Rao", "sam@example.com")

    assert account["id"] == sam  # the oldest invite becomes the account
    assert nets(client, h, flat_id) == before[flat_id]
    assert nets(client, h, trip["id"]) == {
        me: before[trip["id"]][me],
        sam: before[trip["id"]][sammy],
    }
    g = client.get(f"{API}/groups/{trip['id']}", headers=sam_h).json()
    assert {m["placeholder_name"] for m in g["members"]} == {None, "Sammy"}
    assert_valid()


def test_merged_account_syncs_the_group(client, seeded):
    h, group, sam = flat(client)
    spend(client, h, group, sam, 20000, [uid("john"), sam])
    sam_h, account = register(client, "Sam Rao", "sam@example.com")
    streams = client.post(f"{API}/sync", headers=sam_h, json={"cursors": {}}).json()["streams"]
    assert f"group:{group}" not in {s["stream"] for s in streams}

    link(client, h, group, sam, "sam@example.com")

    streams = client.post(f"{API}/sync", headers=sam_h, json={"cursors": {}}).json()["streams"]
    assert f"group:{group}" in {s["stream"] for s in streams}
    snap = client.get(f"{API}/sync/snapshot/group:{group}", headers=sam_h).json()
    expense = next(e for e in snap["entities"] if e["entity"] == "expense")
    assert expense["data"]["payer_id"] == account["id"]
    assert [s["user_id"] for s in expense["data"]["splits"]] == [uid("john"), account["id"]]


def test_link_refusals(client, seeded):
    h, group, sam = flat(client)
    me = uid("john")
    not_placeholder = link(client, h, group, me, "someone@example.com")
    assert not_placeholder.status_code == 409
    assert not_placeholder.json()["error"]["code"] == "not_placeholder"
    assert link(client, h, group, uid("rahul"), "x@example.com").status_code == 404
    assert link(client, h, group, sam, "not an email").status_code == 422
    outsider = login(client, "rahul")
    assert link(client, outsider, group, sam, "x@example.com").status_code == 404
