"""Linked accounts and account numbers: an account can be part of another of yours (the same
account under a second SMS label, or a debit card on a bank account), and carry its full
number. Also the label fixes that came with them (ISS-068, ISS-069, ISS-080)."""

from app.modules.personal import accounts
from app.seed import data
from app.seed.loader import account_id
from tests.api.conftest import login, register, uid
from tests.api.test_personal_accounts import linked, log_rows

API = "/api/v1"
URL = f"{API}/personal/accounts"
TXNS = f"{API}/personal/transactions"
HDFC_ID = str(account_id(next(a for a in data.ACCOUNTS if a.key == "hdfc")))
CARD_ID = str(account_id(next(a for a in data.ACCOUNTS if a.key == "icici_card")))
SAVINGS_ID = str(account_id(next(a for a in data.ACCOUNTS if a.key == "savings")))
ZERODHA_ID = str(account_id(next(a for a in data.ACCOUNTS if a.key == "zerodha")))


def make(client, h, name: str, type: str = "bank", **extra) -> dict:
    r = client.post(URL, headers=h, json={"name": name, "type": type, **extra})
    assert r.status_code == 201, r.text
    return r.json()


def put(client, h, a: dict, **changes):
    body = {"name": a["name"], "type": a["type"], "version": a["version"], **changes}
    return client.put(f"{URL}/{a['id']}", headers=h, json=body)


def error(r) -> tuple[int, str, str]:
    return r.status_code, r.json()["error"]["code"], r.json()["error"]["message"]


def test_link_and_unlink(client, seeded):
    h = login(client, "john")
    card = make(client, h, "HDFC Debit card ··3016", sms_label="HDFC Debit card ··3016")
    assert (card["linked_account_id"], card["account_number"]) == (None, None)

    r = put(client, h, card, linked_account_id=HDFC_ID)
    assert r.status_code == 200, r.text
    card = r.json()
    assert (card["linked_account_id"], card["version"]) == (HDFC_ID, 2)
    # Leaving it out keeps it; null unlinks.
    card = put(client, h, card, name="HDFC debit card").json()
    assert card["linked_account_id"] == HDFC_ID
    card = put(client, h, card, linked_account_id=None).json()
    assert card["linked_account_id"] is None

    rows = log_rows(uid("john"), "personal_account")
    assert [r.action for r in rows] == ["personal_account.create"] + ["personal_account.update"] * 3
    assert rows[1].data["linked_account_id"] == HDFC_ID  # devices get it

    # A new account can be made linked.
    other = make(client, h, "HDFC ··787778", sms_label="HDFC ··787778", linked_account_id=HDFC_ID)
    assert other["linked_account_id"] == HDFC_ID


def test_what_can_be_linked(client, seeded):
    h = login(client, "john")
    card = make(client, h, "HDFC Card ··3016")
    part = make(client, h, "HDFC ··787778", linked_account_id=HDFC_ID)
    closed = make(client, h, "Old", status="closed")

    assert error(put(client, h, card, linked_account_id=card["id"])) == (
        422,
        "link_invalid",
        "An account can't be linked to itself",
    )
    assert error(put(client, h, card, linked_account_id=part["id"])) == (
        422,
        "link_invalid",
        f"HDFC ··787778 is part of {data.HDFC}. Link to that one instead",
    )
    assert error(put(client, h, card, linked_account_id=closed["id"])) == (
        422,
        "account_closed",
        "That account is closed",
    )
    assert error(put(client, h, card, linked_account_id=ZERODHA_ID)) == (
        422,
        "link_invalid",
        "Investment accounts can't be linked",
    )
    # Its type can't become investment while linked, nor can the account others are linked to.
    linked_card = put(client, h, card, linked_account_id=CARD_ID).json()
    assert put(client, h, linked_card, type="investment").json()["error"]["code"] == "link_invalid"
    hdfc = client.get(f"{URL}/{HDFC_ID}", headers=h).json()
    assert put(client, h, hdfc, type="investment").json()["error"]["code"] == "link_invalid"

    # An account others are linked to can't be linked itself, and one a goal follows can't be.
    assert error(put(client, h, hdfc, linked_account_id=CARD_ID)) == (
        409,
        "account_in_use",
        "HDFC ··787778 is linked to this account. Unlink it first",
    )
    savings = client.get(f"{URL}/{SAVINGS_ID}", headers=h).json()
    assert error(put(client, h, savings, linked_account_id=HDFC_ID)) == (
        409,
        "account_in_use",
        "A goal follows this account's balance, so it can't be linked to another",
    )
    # Only to your own.
    zoya, _ = register(client, "Zoya", "zoya@example.com")
    mine = make(client, zoya, "Wallet")
    assert error(put(client, zoya, mine, linked_account_id=HDFC_ID))[1] == "unknown_account"


def test_deleting_and_restoring_around_a_link(client, seeded):
    h = login(client, "john")
    bank = make(client, h, "Axis")
    card = make(client, h, "Axis Debit card ··1111", linked_account_id=bank["id"])
    assert error(client.delete(f"{URL}/{bank['id']}", headers=h)) == (
        409,
        "account_in_use",
        "Axis Debit card ··1111 is linked to this account. Unlink it first",
    )
    # Once the card is gone the bank account can go; the card then comes back on its own.
    assert client.delete(f"{URL}/{card['id']}", headers=h).json()["deleted_at"]
    assert client.delete(f"{URL}/{bank['id']}", headers=h).json()["deleted_at"]
    back = client.post(f"{URL}/{card['id']}/restore", headers=h).json()
    assert (back["deleted_at"], back["linked_account_id"]) == (None, None)
    restore = log_rows(uid("john"), "personal_account")[-1]
    assert (restore.action, restore.data["linked_account_id"]) == ("personal_account.restore", None)


def test_no_new_entries_through_a_link_to_a_closed_account(client, seeded):
    h = login(client, "john")
    bank = make(client, h, "Axis")
    card = make(client, h, "Axis Debit card ··1111", linked_account_id=bank["id"])
    body = {"type": "expense", "amount_minor": 1000, "description": "Tea", "date": "2026-09-24"}
    assert client.post(TXNS, headers=h, json={**body, "account_id": card["id"]}).status_code == 201
    put(client, h, bank, status="closed")
    assert error(client.post(TXNS, headers=h, json={**body, "account_id": card["id"]})) == (
        422,
        "account_closed",
        "That account is part of Axis, which is closed",
    )


def test_account_numbers(client, seeded):
    h = login(client, "john")
    sbi = make(client, h, "SBI", account_number=" 3001 2345-678456 ")
    assert sbi["account_number"] == "30012345678456"
    # Leaving it out keeps it; "" and null clear it.
    sbi = put(client, h, sbi, name="SBI savings").json()
    assert sbi["account_number"] == "30012345678456"
    assert put(client, h, sbi, account_number="").json()["account_number"] is None
    for bad in ["12a4", "123", "1" * 21]:
        r = client.post(URL, headers=h, json={"name": "X", "type": "bank", "account_number": bad})
        assert error(r) == (422, "invalid_input", "An account number is 4 to 20 digits"), bad


def test_an_older_app_relabelling_an_entry_moves_it_out(client, seeded):
    # ISS-068: a label with no account takes the entry out of its old one.
    h = login(client, "john")
    sbi = make(client, h, "SBI", sms_label="SBI ··0042")
    r = client.post(
        TXNS,
        headers=h,
        json={
            "type": "expense",
            "amount_minor": 1000,
            "description": "Bus pass",
            "date": "2026-09-24",
            "account": "SBI ··0042",
        },
    )
    t = r.json()
    assert linked("Bus pass") == [sbi["id"]]
    edit = {k: t[k] for k in ("type", "amount_minor", "description", "date", "version")}
    r = client.put(f"{TXNS}/{t['id']}", headers=h, json={**edit, "account": "Axis ··7777"})
    assert r.status_code == 200, r.text
    assert (r.json()["account"], linked("Bus pass")) == ("Axis ··7777", [None])


def test_a_label_taken_while_making_an_account_is_a_409(client, seeded, monkeypatch):
    # ISS-069: two creates racing on one label. The second's check ran before the first's row
    # was committed, so only the unique index sees it.
    h = login(client, "john")
    make(client, h, "SBI", sms_label="SBI ··0042")
    real, calls = accounts._check_label, []

    def late(session, actor, label, account):
        calls.append(label)
        if len(calls) > 1:
            real(session, actor, label, account)

    monkeypatch.setattr(accounts, "_check_label", late)
    r = client.post(
        URL, headers=h, json={"name": "Again", "type": "bank", "sms_label": "SBI ··0042"}
    )
    assert error(r) == (409, "label_taken", "SBI already has that label")


def test_an_account_a_rule_filters_on_cant_be_deleted(client, seeded):
    # ISS-080: the filter would match nothing.
    h = login(client, "john")
    axis = make(client, h, "Axis")
    goals = client.get(f"{API}/personal/goals", headers=h).json()
    goal = next(
        g for g in goals if g["tracking_mode"] == "contribution" and g["status"] == "active"
    )
    r = client.post(
        f"{API}/personal/allocation-rules",
        headers=h,
        json={
            "name": "Axis salary",
            "kind": "percentage",
            "percent_bp": 1000,
            "goal_id": goal["id"],
            "source_account_id": axis["id"],
        },
    )
    assert r.status_code == 201, r.text
    assert error(client.delete(f"{URL}/{axis['id']}", headers=h)) == (
        409,
        "rule_points_here",
        "The rule “Axis salary” only takes incomes into this account. Change or delete it first",
    )


def test_an_accounts_entries_come_with_those_of_accounts_linked_to_it(client, seeded):
    h = login(client, "john")
    card = make(client, h, "HDFC Debit card ··3016", linked_account_id=HDFC_ID)
    body = {"type": "expense", "amount_minor": 1000, "description": "Paddle", "date": "2026-09-24"}
    assert client.post(TXNS, headers=h, json={**body, "account_id": card["id"]}).status_code == 201
    hdfc = client.get(f"{TXNS}?account_id={HDFC_ID}&limit=500", headers=h).json()
    assert "Paddle" in {t["description"] for t in hdfc["items"]}
    own = client.get(f"{TXNS}?account_id={card['id']}", headers=h).json()
    assert [t["description"] for t in own["items"]] == ["Paddle"]
