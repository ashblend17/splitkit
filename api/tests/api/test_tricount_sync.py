"""Keeping a group in sync with a tricount, against an in-memory Tricount
(tests/tricount_fake.py)."""

from collections import defaultdict
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import httpx
import pytest
from sqlalchemy import select, update

from app.core.db import SessionLocal
from app.modules.tricount_sync import client as tricount_client
from app.modules.tricount_sync import reconcile, worker
from app.modules.tricount_sync.client import TricountError
from app.modules.tricount_sync.models import TricountEntry, TricountLink
from app.modules.users.models import User
from tests.api.conftest import gid, login, uid
from tests.tricount_fake import FakeTricount

API = "/api/v1"


@pytest.fixture
def tc():
    fake = FakeTricount()
    tricount_client.use_transport(fake.transport)
    yield fake
    tricount_client.use_transport(None)


def _new_group(client, h, name="Trek", members=("aman", "rahul")):
    g = client.post(f"{API}/groups", headers=h, json={"name": name}).json()
    for key in members:
        email = {"aman": "aman.v@example.com", "rahul": "rahul.sharma@example.com"}[key]
        client.post(f"{API}/groups/{g['id']}/members", headers=h, json={"email": email})
    return g["id"]


def _trek(tc):
    reg = tc.make("Trek", "INR", ["Ansh", "Aman", "Rahul S"])
    tc.add_expense(
        reg, "Tent", "3000.00", "Ansh", {"Ansh": "1000.00", "Aman": "1000.00", "Rahul S": "1000.00"}
    )
    tc.add_expense(
        reg,
        "Fuel",
        "1000.00",
        "Aman",
        {"Ansh": "500.00", "Aman": "250.00", "Rahul S": "250.00"},
        category="TRANSPORT",
        ratios={"Ansh": 2, "Aman": 1, "Rahul S": 1},
    )
    tc.add_transfer(reg, "250.00", "Rahul S", "Ansh")
    return reg


def _link(client, h, group_id, reg, people=None):
    link = f"https://tricount.com/{reg['public_identifier_token']}"
    preview = client.post(
        f"{API}/groups/{group_id}/tricount/preview", headers=h, json={"link": link}
    )
    assert preview.status_code == 200, preview.text
    chosen = people or [
        {
            "member_uuid": p["member_uuid"],
            "user_id": p["suggested"]["id"] if p["suggested"] else None,
        }
        for p in preview.json()["people"]
    ]
    r = client.post(
        f"{API}/groups/{group_id}/tricount", headers=h, json={"link": link, "people": chosen}
    )
    assert r.status_code == 201, r.text
    return preview.json(), r.json()


def _status(client, h, group_id):
    return client.get(f"{API}/groups/{group_id}/tricount", headers=h).json()


def _tricount_positions(reg) -> dict[str, int]:
    names = {m["uuid"]: m["name"] for m in reg["members"]}
    pos: dict[str, int] = defaultdict(int)
    for e in reg["entries"]:
        total = abs(Decimal(e["amount"]["value"]))
        pos[names[e["payer"]]] += int(total * 100)
        for a in e["allocations"]:
            pos[names[a["member"]]] -= int(abs(Decimal(a["amount"]["value"])) * 100)
    return {k: v for k, v in pos.items() if v}


def _splitkit_positions(client, h, group_id) -> dict[str, int]:
    b = client.get(f"{API}/groups/{group_id}/balances", headers=h).json()
    return {m["user"]["name"]: m["net_minor"] for m in b["members"] if m["net_minor"]}


def _sync(group_id):
    return reconcile.run(__import__("uuid").UUID(group_id))


# ---- linking ----


def test_preview_suggests_people_and_counts_entries(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    tc.add_expense(reg, "Refund", "100.00", "Aman", {"Ansh": "100.00"}, kind="INCOME")
    preview, _ = _link(client, h, group_id, reg)
    assert (preview["title"], preview["currency"], preview["problem"]) == ("Trek", "INR", None)
    assert (preview["expenses"], preview["payments"], preview["unsupported"]) == (2, 1, 1)
    states = {
        p["name"]: (p["state"], p["suggested"] and p["suggested"]["name"])
        for p in preview["people"]
    }
    assert states == {
        "Ansh": ("you", "Ansh C"),
        "Aman": ("suggested", "Aman Verma"),
        "Rahul S": ("suggested", "Rahul Sharma"),
    }


def test_link_pulls_everything_and_balances_match(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _, out = _link(client, h, group_id, reg)
    status = _status(client, h, group_id)
    assert status["link"]["state"] == "ok", status
    assert status["link"]["share_link"] == f"https://tricount.com/{reg['public_identifier_token']}"

    feed = client.get(f"{API}/feed?group_id={group_id}", headers=h).json()
    assert {i.get("title") or i["kind"] for i in feed} >= {"Tent", "Fuel"}
    assert _splitkit_positions(client, h, group_id) == {
        "Ansh C": 300000 - 100000 - 50000 - 25000,
        "Aman Verma": 100000 - 100000 - 25000,
        "Rahul Sharma": -100000 - 25000 + 25000,
    }
    names = {"Ansh": "Ansh C", "Aman": "Aman Verma", "Rahul S": "Rahul Sharma"}
    assert {names[k]: v for k, v in _tricount_positions(reg).items()} == _splitkit_positions(
        client, h, group_id
    )

    fuel = next(i for i in feed if i.get("title") == "Fuel")
    detail = client.get(f"{API}/expenses/{fuel['id']}", headers=h).json()
    assert detail["split_method"] == "shares"
    assert detail["category"]["key"] == "transport"
    assert detail["created_by"]["name"] == "Tricount"
    history = client.get(f"{API}/expenses/{fuel['id']}/history", headers=h).json()
    assert history[0]["person"]["name"] == "Tricount"

    # Nothing more to do on a second pass, and nothing was sent to Tricount.
    tc.writes.clear()
    again = _sync(group_id)
    assert (again.pulled, again.pushed, again.conflicts) == (0, 0, 0)
    assert [w for w in tc.writes if "registry-entry" in w[1]] == []


def test_currency_must_match(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = tc.make("Paris", "EUR", ["Ansh"])
    link = f"tricount.com/{reg['public_identifier_token']}"
    preview = client.post(
        f"{API}/groups/{group_id}/tricount/preview", headers=h, json={"link": link}
    ).json()
    assert preview["problem"].startswith("The tricount is in EUR and this group in INR")
    r = client.post(f"{API}/groups/{group_id}/tricount", headers=h, json={"link": link})
    assert r.status_code == 422 and r.json()["error"]["code"] == "currency_mismatch"


def test_bad_links(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    r = client.post(f"{API}/groups/{group_id}/tricount/preview", headers=h, json={"link": "hello"})
    assert r.status_code == 422 and "Tricount link" in r.json()["error"]["message"]
    r = client.post(
        f"{API}/groups/{group_id}/tricount/preview", headers=h, json={"link": "tNOPE1234"}
    )
    assert r.status_code == 404 and r.json()["error"]["message"] == "No tricount has that link"
    tc.down = True
    r = client.post(
        f"{API}/groups/{group_id}/tricount/preview", headers=h, json={"link": "tNOPE1234"}
    )
    assert r.status_code == 502 and "reach Tricount" in r.json()["error"]["message"]


def test_only_members_and_not_twice(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _link(client, h, group_id, reg)
    again = client.post(
        f"{API}/groups/{group_id}/tricount",
        headers=h,
        json={"link": reg["public_identifier_token"]},
    )
    assert again.status_code == 409
    other = _new_group(client, h, "Other")
    taken = client.post(
        f"{API}/groups/{other}/tricount", headers=h, json={"link": reg["public_identifier_token"]}
    )
    assert taken.status_code == 409 and taken.json()["error"]["code"] == "tricount_taken"
    outsider = login(client, "priya")
    assert client.get(f"{API}/groups/{group_id}/tricount", headers=outsider).status_code == 404


# ---- Splitkit -> Tricount ----


def _expense(
    client,
    h,
    group_id,
    description="Dinner",
    amount=90000,
    payer="ansh",
    people=("ansh", "aman", "rahul"),
):
    body = {
        "description": description,
        "amount_minor": amount,
        "payer_id": uid(payer),
        "date": "2026-09-25",
        "split": {"method": "equal", "inputs": [{"user_id": uid(p)} for p in people]},
    }
    r = client.post(f"{API}/groups/{group_id}/expenses", headers=h, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def test_splitkit_writes_reach_tricount(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _link(client, h, group_id, reg)

    e = _expense(client, h, group_id)
    assert _sync(group_id).pushed == 1
    sent = tc.by_description(reg, "Dinner")
    assert sent["amount"] == {"value": "-900.00", "currency": "INR"}
    assert sent["type_transaction"] == "NORMAL" and sent["date"].startswith("2026-09-25")
    assert sorted(a["amount"]["value"] for a in sent["allocations"]) == ["-300.00"] * 3

    # An edit replaces the entry in Tricount; a retried pass sends nothing twice.
    body = {
        **{k: e[k] for k in ("description", "date")},
        "amount_minor": 120000,
        "payer_id": uid("aman"),
        "version": e["version"],
        "split": {
            "method": "exact",
            "inputs": [
                {"user_id": uid("ansh"), "value": "100000"},
                {"user_id": uid("aman"), "value": "20000"},
            ],
        },
    }
    assert client.put(f"{API}/expenses/{e['id']}", headers=h, json=body).status_code == 200
    _sync(group_id)
    _sync(group_id)
    sent = tc.by_description(reg, "Dinner")
    assert sent["amount"]["value"] == "-1200.00" and sent["payer"] == tc.member(reg, "Aman")
    assert len([x for x in reg["entries"] if x["description"] == "Dinner"]) == 1

    # Delete, then restore: it's created in Tricount again with a new id.
    first_uuid = sent["uuid"]
    client.delete(f"{API}/expenses/{e['id']}", headers=h)
    _sync(group_id)
    assert not [x for x in reg["entries"] if x["description"] == "Dinner"]
    client.post(f"{API}/expenses/{e['id']}/restore", headers=h)
    _sync(group_id)
    back = tc.by_description(reg, "Dinner")
    assert back["uuid"] != first_uuid

    names = {"Ansh": "Ansh C", "Aman": "Aman Verma", "Rahul S": "Rahul Sharma"}
    assert {names[k]: v for k, v in _tricount_positions(reg).items()} == _splitkit_positions(
        client, h, group_id
    )


def test_payments_go_both_ways(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _link(client, h, group_id, reg)
    pay = {
        "from_user": uid("aman"),
        "to_user": uid("ansh"),
        "amount_minor": 12345,
        "date": "2026-09-26",
        "method": "cash",
        "note": "Cab money",
    }
    s = client.post(f"{API}/groups/{group_id}/settlements", headers=h, json=pay).json()
    _sync(group_id)
    sent = tc.by_description(reg, "Cab money")
    assert sent["type_transaction"] == "BALANCE" and sent["amount"]["value"] == "123.45"
    assert sent["payer"] == tc.member(reg, "Aman")
    tc.edit(reg, sent["id"], amount="200.00")
    _sync(group_id)
    assert client.get(f"{API}/settlements/{s['id']}", headers=h).json()["amount_minor"] == 20000


def test_a_failed_push_is_sent_later(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _link(client, h, group_id, reg)
    tc.down = True
    _expense(client, h, group_id, "Snacks", 30000)
    with pytest.raises(httpx.ConnectError):
        _sync(group_id)
    status = _status(client, h, group_id)["link"]
    assert status["state"] == "error" and "reach Tricount" in status["last_error"]
    with SessionLocal() as s:
        link = s.get(TricountLink, __import__("uuid").UUID(group_id))
        assert link.failures == 1 and link.next_attempt_at > datetime.now(UTC)
    # Not due again until the backoff has passed.
    assert __import__("uuid").UUID(group_id) not in worker.due()
    tc.down = False
    _sync(group_id)
    assert tc.by_description(reg, "Snacks")["amount"]["value"] == "-300.00"
    assert _status(client, h, group_id)["link"]["state"] == "ok"


def test_creates_survive_a_crash_between_send_and_save(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _link(client, h, group_id, reg)
    _expense(client, h, group_id, "Snacks", 30000)
    _sync(group_id)
    # Forget that the entry was sent, as if the pass died right after Tricount saved it.
    with SessionLocal.begin() as s:
        row = s.scalar(
            select(TricountEntry).where(TricountEntry.base["description"].astext == "Snacks")
        )
        s.delete(row)
    _sync(group_id)
    assert len([x for x in reg["entries"] if x["description"] == "Snacks"]) == 1
    assert _sync(group_id).pushed == 0


def test_expired_session_registers_again(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _link(client, h, group_id, reg)
    tc.expire_sessions()
    _expense(client, h, group_id, "Snacks", 30000)
    _sync(group_id)
    assert tc.by_description(reg, "Snacks")
    assert tc.calls.count(("POST", "/v1/session-registry-installation")) == 2


def test_tricount_refuses_other_apps(client, seeded, tc, monkeypatch):
    from app.core.config import get_settings

    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _link(client, h, group_id, reg)
    monkeypatch.setattr(get_settings(), "tricount_user_agent", "splitkit/1.0")
    _expense(client, h, group_id, "Snacks", 30000)
    with pytest.raises(TricountError):
        _sync(group_id)
    assert (
        "no longer available in the bunq app" in _status(client, h, group_id)["link"]["last_error"]
    )


# ---- Tricount -> Splitkit ----


def test_tricount_edits_and_deletes_arrive(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _link(client, h, group_id, reg)
    tent = tc.by_description(reg, "Tent")
    tc.edit(reg, tent["id"], description="Big tent")
    assert _sync(group_id).pulled == 1
    feed = client.get(f"{API}/feed?group_id={group_id}", headers=h).json()
    big = next(i for i in feed if i.get("title") == "Big tent")
    history = client.get(f"{API}/expenses/{big['id']}/history", headers=h).json()
    assert [x["action"] for x in history] == ["expense.create", "expense.update"]
    assert history[-1]["person"]["name"] == "Tricount"

    tc.remove(reg, tent["id"])
    _sync(group_id)
    assert client.get(f"{API}/expenses/{big['id']}", headers=h).json()["deleted_at"] is not None


def test_new_people_on_either_side(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _link(client, h, group_id, reg)
    # Someone new in Tricount becomes a placeholder member here.
    reg["members"].append(tc._member("Neha"))
    tc.add_expense(reg, "Chai", "60.00", "Neha", {"Neha": "30.00", "Ansh": "30.00"})
    _sync(group_id)
    members = client.get(f"{API}/groups/{group_id}", headers=h).json()["members"]
    neha = next(m for m in members if m["user"]["name"] == "Neha")
    assert neha["user"]["is_placeholder"] and neha["placeholder_name"] == "Neha"
    # Someone new here is added to the tricount.
    client.post(f"{API}/groups/{group_id}/members", headers=h, json={"name": "Kiran"})
    _sync(group_id)
    assert "Kiran" in [m["name"] for m in reg["members"] if m["status"] == "ACTIVE"]
    assert {"Ansh", "Aman", "Rahul S", "Neha"} <= {
        m["name"] for m in reg["members"] if m["status"] == "ACTIVE"
    }


def test_names_follow_whoever_renamed(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h, "Trek 2026")
    reg = _trek(tc)
    _link(client, h, group_id, reg)
    assert client.get(f"{API}/groups/{group_id}", headers=h).json()["name"] == "Trek"
    reg["title"] = "Himalaya trek"
    _sync(group_id)
    assert client.get(f"{API}/groups/{group_id}", headers=h).json()["name"] == "Himalaya trek"
    client.patch(f"{API}/groups/{group_id}", headers=h, json={"name": "Spiti"})
    _sync(group_id)
    assert reg["title"] == "Spiti"


def test_income_is_reported_not_synced(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    tc.add_expense(reg, "Refund", "100.00", "Aman", {"Ansh": "100.00"}, kind="INCOME")
    _link(client, h, group_id, reg)
    warnings = _status(client, h, group_id)["link"]["warnings"]
    assert warnings == [
        "1 entry in Tricount with income (₹100) can't be shown in Splitkit, so balances can differ."
    ]


def test_a_mass_disappearance_is_held_back(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    for i in range(6):
        tc.add_expense(reg, f"Item {i}", "10.00", "Ansh", {"Ansh": "10.00"})
    _link(client, h, group_id, reg)
    reg["entries"] = []
    _sync(group_id)
    feed = client.get(f"{API}/feed?group_id={group_id}", headers=h).json()
    assert len(feed) == 9
    assert "no longer has 9 entries" in _status(client, h, group_id)["link"]["warnings"][0]


# ---- conflicts ----


def test_changes_on_both_sides_wait_for_someone_to_pick(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _link(client, h, group_id, reg)
    tent = tc.by_description(reg, "Tent")
    feed = client.get(f"{API}/feed?group_id={group_id}", headers=h).json()
    local = client.get(
        f"{API}/expenses/{next(i for i in feed if i.get('title') == 'Tent')['id']}", headers=h
    ).json()

    tc.edit(reg, tent["id"], description="Tent (Tricount)")
    edit = {
        "description": "Tent (Splitkit)",
        "amount_minor": local["amount_minor"],
        "payer_id": local["payer"]["id"],
        "date": local["date"],
        "version": local["version"],
        "split": {
            "method": "equal",
            "inputs": [{"user_id": s["user"]["id"]} for s in local["splits"]],
        },
    }
    client.put(f"{API}/expenses/{local['id']}", headers=h, json=edit)
    assert _sync(group_id).conflicts == 1
    conflicts = client.get(f"{API}/tricount/conflicts", headers=h).json()
    assert len(conflicts) == 1
    c = conflicts[0]
    assert (c["entity"], c["splitkit"]["title"], c["tricount"]["title"]) == (
        "expense",
        "Tent (Splitkit)",
        "Tent (Tricount)",
    )
    assert c["tricount"]["summary"].startswith("₹3,000 · paid by Ansh · split 3 ways")
    assert _status(client, h, group_id)["link"]["conflicts"][0]["id"] == c["id"]
    # While it's open nothing is sent either way.
    assert _sync(group_id).conflicts == 0
    assert tc.entry(reg, tent["id"])["description"] == "Tent (Tricount)"

    # Someone else in the group can resolve it; outsiders can't.
    assert (
        client.post(
            f"{API}/tricount/conflicts/{c['id']}/resolve",
            headers=login(client, "priya"),
            json={"keep": "splitkit"},
        ).status_code
        == 404
    )
    r = client.post(
        f"{API}/tricount/conflicts/{c['id']}/resolve",
        headers=login(client, "aman"),
        json={"keep": "splitkit"},
    )
    assert r.status_code == 200, r.text
    assert tc.entry(reg, tent["id"])["description"] == "Tent (Splitkit)"
    assert client.get(f"{API}/tricount/conflicts", headers=h).json() == []


def test_keeping_tricounts_version_of_something_deleted_here(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _link(client, h, group_id, reg)
    tent = tc.by_description(reg, "Tent")
    feed = client.get(f"{API}/feed?group_id={group_id}", headers=h).json()
    local_id = next(i for i in feed if i.get("title") == "Tent")["id"]
    client.delete(f"{API}/expenses/{local_id}", headers=h)
    tc.edit(
        reg,
        tent["id"],
        amount="3300.00",
        allocations=[
            {**a, "amount": {"value": "-1100.00", "currency": "INR"}} for a in tent["allocations"]
        ],
    )
    _sync(group_id)
    [c] = client.get(f"{API}/tricount/conflicts", headers=h).json()
    assert c["splitkit"]["deleted"] and c["tricount"]["summary"].startswith("₹3,300")
    client.post(f"{API}/tricount/conflicts/{c['id']}/resolve", headers=h, json={"keep": "tricount"})
    back = client.get(f"{API}/expenses/{local_id}", headers=h).json()
    assert back["deleted_at"] is None and back["amount_minor"] == 330000


# ---- making a new tricount, and imported groups ----


def test_a_new_tricount_from_a_group(client, seeded, tc):
    h = login(client, "ansh")
    r = client.post(f"{API}/groups/{gid('flat')}/tricount", headers=h, json={"create": True})
    assert r.status_code == 201, r.text
    status = _status(client, h, gid("flat"))["link"]
    assert status["state"] == "ok", status
    [reg] = tc.registries.values()
    assert reg["title"] == "Flatmates" and reg["currency"] == "INR"
    assert sorted(m["name"] for m in reg["members"] if m["status"] == "ACTIVE") == [
        "Aman Verma",
        "Ansh C",
        "Vivek Iyer",
    ]
    names = {"Ansh C": "Ansh C", "Aman Verma": "Aman Verma", "Vivek Iyer": "Vivek Iyer"}
    assert {names[k]: v for k, v in _tricount_positions(reg).items()} == _splitkit_positions(
        client, h, gid("flat")
    )


def test_linking_an_imported_group_pairs_entries_instead_of_copying(client, seeded, tc):
    """The seeded Goa Trip came from a Tricount import: linking it to that tricount must not
    duplicate anything."""
    h = login(client, "ansh")
    r = client.post(f"{API}/groups/{gid('goa')}/tricount", headers=h, json={"create": True})
    assert r.status_code == 201
    [reg] = tc.registries.values()
    count = len(reg["entries"])
    # Unlink, then link the same tricount again: everything pairs up.
    assert client.delete(f"{API}/groups/{gid('goa')}/tricount", headers=h).status_code == 204
    before = len(client.get(f"{API}/feed?group_id={gid('goa')}&limit=100", headers=h).json())
    _link(client, h, gid("goa"), reg)
    assert len(reg["entries"]) == count
    after = len(client.get(f"{API}/feed?group_id={gid('goa')}&limit=100", headers=h).json())
    assert after == before


def test_look_alike_entries_pair_up_and_tricounts_words_win(client, seeded, tc):
    """A group imported from a Tricount export has the same entries under other ids."""
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    mine = _expense(client, h, group_id, "dinner at thalassa", 90000)
    reg = tc.make("Trek", "INR", ["Ansh", "Aman", "Rahul S"])
    tc.add_expense(
        reg,
        "Dinner at Thalassa",
        "900.00",
        "Ansh",
        {"Ansh": "300.00", "Aman": "300.00", "Rahul S": "300.00"},
        day="2026-09-25",
    )
    _link(client, h, group_id, reg)
    assert len(reg["entries"]) == 1
    feed = client.get(f"{API}/feed?group_id={group_id}", headers=h).json()
    assert [(i["id"], i["title"]) for i in feed] == [(mine["id"], "Dinner at Thalassa")]


# ---- the worker ----


def test_worker_runs_when_something_changed_or_someone_is_around(client, seeded, tc):
    import uuid as uuidlib

    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    _link(client, h, group_id, reg)
    g = uuidlib.UUID(group_id)
    assert g not in worker.due()
    _expense(client, h, group_id, "Snacks", 30000)
    assert g in worker.due()
    assert worker.tick() == 1 and tc.by_description(reg, "Snacks")
    assert g not in worker.due()
    # Someone is using the app and the last pull is over a minute old: pull again.
    with SessionLocal.begin() as s:
        s.execute(
            update(TricountLink).values(
                last_active_at=datetime.now(UTC),
                last_synced_at=datetime.now(UTC) - timedelta(minutes=2),
            )
        )
    assert g in worker.due()
    # Nobody around: no polling.
    with SessionLocal.begin() as s:
        s.execute(
            update(TricountLink).values(last_active_at=datetime.now(UTC) - timedelta(hours=1))
        )
    assert g not in worker.due()


def test_using_the_app_marks_linked_groups_active(client, seeded, tc):
    from app.modules.tricount_sync import activity

    h = login(client, "ansh")
    group_id = _new_group(client, h)
    _link(client, h, group_id, _trek(tc))
    with SessionLocal.begin() as s:
        s.execute(update(TricountLink).values(last_active_at=None))
    activity.touch(str(uid("aman")))
    with SessionLocal() as s:
        assert s.scalar(select(TricountLink.last_active_at)) is not None


def test_the_tricount_user_is_not_a_person(client, seeded, tc):
    h = login(client, "ansh")
    group_id = _new_group(client, h)
    _link(client, h, group_id, _trek(tc))
    with SessionLocal() as s:
        assert s.get(User, reconcile.SYSTEM_USER_ID).role == "system"
    admin = client.get(f"{API}/admin/users?include_placeholders=true&limit=200", headers=h).json()
    assert "Tricount" not in [u["name"] for u in admin["items"]]


def test_read_only_view_as_cannot_link(client, seeded, tc):
    h = login(client, "ansh")
    session = client.post(
        f"{API}/admin/sessions", headers=h, json={"target_user_id": uid("aman")}
    ).json()
    viewer = {"Authorization": f"Bearer {session['access_token']}"}
    r = client.post(f"{API}/groups/{gid('flat')}/tricount", headers=viewer, json={"create": True})
    assert r.status_code == 403


def test_the_worker_runs_as_its_own_process(client, seeded, tc):
    """It must load every model itself (it doesn't import the app), or writing an expense fails."""
    import os
    import subprocess
    import sys

    from app.core.config import get_settings

    env = {**os.environ, "DATABASE_URL": get_settings().database_url}
    done = subprocess.run(
        [sys.executable, "-m", "app.modules.tricount_sync", "--once"],
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert done.returncode == 0, done.stderr
    probe = subprocess.run(
        [
            sys.executable,
            "-c",
            "import app.modules.tricount_sync.worker as w; "
            "from sqlalchemy.orm import configure_mappers; configure_mappers(); "
            "from app.core.db import Base; Base.metadata.sorted_tables; print('ok')",
        ],
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert probe.stdout.strip() == "ok", probe.stderr


def test_a_placeholder_linked_to_an_account_is_the_same_tricount_person(client, seeded, tc):
    from tests.api.conftest import register

    h = login(client, "ansh")
    group_id = _new_group(client, h)
    reg = _trek(tc)
    reg["members"].append(tc._member("Neha"))
    tc.add_expense(reg, "Chai", "60.00", "Neha", {"Neha": "30.00", "Ansh": "30.00"})
    _link(client, h, group_id, reg)
    members = client.get(f"{API}/groups/{group_id}", headers=h).json()["members"]
    neha = next(m for m in members if m["user"]["name"] == "Neha")
    # Neha signs up, and the placeholder is linked to her account.
    register(client, "Neha Kapoor", "neha.k@example.com")
    r = client.post(
        f"{API}/groups/{group_id}/members/{neha['user']['id']}/link",
        headers=h,
        json={"email": "neha.k@example.com"},
    )
    assert r.status_code == 200, r.text
    tc.writes.clear()
    out = _sync(group_id)
    # Not added to the tricount a second time, and nothing to send: she's the same person.
    active = [m["name"] for m in reg["members"] if m["status"] == "ACTIVE"]
    assert active.count("Neha") == 1 and "Neha Kapoor" not in active
    assert (out.pushed, out.pulled, out.conflicts) == (0, 0, 0)
    assert not [w for w in tc.writes if w[0] != "GET"]
