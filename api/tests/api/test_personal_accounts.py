"""Personal accounts: private to their owner, one per bank SMS label, never deleted while in
use, and synced on the owner's stream."""

from typing import get_args

from sqlalchemy import func, select, text

from app.core.db import SessionLocal
from app.models import ChangeLog, PersonalAccount
from app.modules.personal import ledger_rules
from app.modules.personal.schemas import AccountStatus, AccountType
from app.seed import data
from app.seed.loader import account_id
from tests.api.conftest import login, register, uid
from tests.api.test_admin import start

API = "/api/v1"
URL = f"{API}/personal/accounts"
HDFC_ID = str(account_id(next(a for a in data.ACCOUNTS if a.key == "hdfc")))
CARD_ID = str(account_id(next(a for a in data.ACCOUNTS if a.key == "icici_card")))


def log_rows(user: str, entity: str | None = None) -> list[ChangeLog]:
    with SessionLocal() as s:
        q = select(ChangeLog).where(ChangeLog.stream_id == f"user:{user}")
        if entity:
            q = q.where(ChangeLog.entity == entity)
        return list(s.scalars(q.order_by(ChangeLog.seq)))


def linked(description: str) -> list[str | None]:
    """The account ids of your entries with this description (not in the API until the entry
    schema gains account_id)."""
    with SessionLocal() as s:
        rows = s.execute(
            text("SELECT account_id FROM personal_transactions WHERE description = :d ORDER BY id"),
            {"d": description},
        )
        return [str(a) if a else None for (a,) in rows]


def entry(client, h, description: str, account: str) -> dict:
    body = {
        "type": "expense",
        "amount_minor": 12000,
        "description": description,
        "date": "2026-09-24",
        "account": account,
    }
    r = client.post(f"{API}/personal/transactions", headers=h, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def test_the_schema_matches_the_ledger_rules():
    assert get_args(AccountType) == ledger_rules.ACCOUNT_TYPES
    assert get_args(AccountStatus) == ledger_rules.ACCOUNT_STATUSES


def test_create_list_edit_delete_and_restore(client, seeded):
    h = login(client, "john")
    r = client.post(
        URL, headers=h, json={"name": "  Wallet ", "type": "cash", "opening_balance_minor": 50000}
    )
    assert r.status_code == 201, r.text
    wallet = r.json()
    assert (wallet["name"], wallet["currency"], wallet["status"], wallet["version"]) == (
        "Wallet",
        "INR",
        "active",
        1,
    )
    assert wallet["sms_label"] is None and wallet["deleted_at"] is None
    # Oldest first: the seed's five, then the new one.
    assert [a["name"] for a in client.get(URL, headers=h).json()] == [
        "Zerodha",
        "Emergency savings",
        data.HDFC,
        "Cash",
        data.ICICI_CARD,
        "Wallet",
    ]
    assert client.get(f"{URL}/{wallet['id']}", headers=h).json() == wallet

    # Leaving the opening balance out keeps it.
    r = client.put(
        f"{URL}/{wallet['id']}", headers=h, json={"name": "Pocket", "type": "cash", "version": 1}
    )
    assert r.status_code == 200, r.text
    assert (r.json()["name"], r.json()["opening_balance_minor"], r.json()["version"]) == (
        "Pocket",
        50000,
        2,
    )
    stale = client.put(
        f"{URL}/{wallet['id']}", headers=h, json={"name": "Purse", "type": "cash", "version": 1}
    )
    assert (stale.status_code, stale.json()["error"]["code"]) == (409, "version_conflict")

    gone = client.delete(f"{URL}/{wallet['id']}?version=2", headers=h).json()
    assert gone["deleted_at"] and gone["version"] == 3
    assert wallet["id"] not in {a["id"] for a in client.get(URL, headers=h).json()}
    assert [a["id"] for a in client.get(f"{URL}?deleted=true", headers=h).json()] == [wallet["id"]]
    r = client.put(f"{URL}/{wallet['id']}", headers=h, json={"name": "Purse", "type": "cash"})
    assert (r.status_code, r.json()["error"]["code"]) == (409, "deleted")
    back = client.post(f"{URL}/{wallet['id']}/restore?version=3", headers=h).json()
    assert back["deleted_at"] is None and back["version"] == 4

    actions = [r.action for r in log_rows(uid("john"), "personal_account")]
    assert actions == [
        "personal_account.create",
        "personal_account.update",
        "personal_account.delete",
        "personal_account.restore",
    ]


def test_input_is_checked(client, seeded):
    h = login(client, "john")
    for body, message in [
        ({"name": "   ", "type": "cash"}, "Name can't be empty"),
        ({"name": "Wallet", "type": "wallet"}, None),
        ({"name": "Wallet", "type": "cash", "opening_balance_minor": 10**16}, None),
        ({"name": "Wallet", "type": "cash", "sms_label": "x" * 61}, None),
    ]:
        r = client.post(URL, headers=h, json=body)
        assert (r.status_code, r.json()["error"]["code"]) == (422, "invalid_input"), body
        if message:
            assert r.json()["error"]["message"] == message


def test_the_currency_is_yours(client, seeded):
    h = login(client, "john")
    client.patch(f"{API}/me", headers=h, json={"currency": "USD"})
    r = client.post(URL, headers=h, json={"name": "Chase", "type": "bank", "currency": "EUR"})
    assert r.json()["currency"] == "USD"


def test_one_account_per_label(client, seeded):
    h = login(client, "john")
    r = client.post(URL, headers=h, json={"name": "HDFC", "type": "bank", "sms_label": data.HDFC})
    assert r.status_code == 409
    assert r.json()["error"] == {
        "code": "label_taken",
        "message": f"{data.HDFC} already has that label",
        "account_id": HDFC_ID,
    }
    # Relabelling onto a taken label too.
    cash = next(a for a in client.get(URL, headers=h).json() if a["name"] == "Cash")
    r = client.put(
        f"{URL}/{cash['id']}",
        headers=h,
        json={"name": "Cash", "type": "cash", "sms_label": f"  {data.HDFC} "},
    )
    assert r.json()["error"]["code"] == "label_taken"
    # A deleted account keeps its label.
    sbi = client.post(URL, headers=h, json={"name": "SBI", "type": "bank", "sms_label": "SBI ··1"})
    client.delete(f"{URL}/{sbi.json()['id']}", headers=h)
    r = client.post(URL, headers=h, json={"name": "SBI", "type": "bank", "sms_label": "SBI ··1"})
    assert r.json()["error"]["message"] == "A deleted account has that label. Restore it instead"
    # Labels are per person.
    other, _ = register(client, "Zoya", "zoya@example.com")
    r = client.post(URL, headers=other, json={"name": "H", "type": "bank", "sms_label": data.HDFC})
    assert r.status_code == 201, r.text


def test_a_repeated_create_returns_the_account(client, seeded):
    """A phone that reads HDFC's SMS makes the account with the id every phone (and migration
    0013) gives the label, and gets the seeded one back, unchanged."""
    h = login(client, "john")
    sms_id = str(ledger_rules.sms_account_id(uid("john"), data.HDFC))
    assert sms_id == HDFC_ID
    before = len(log_rows(uid("john")))
    body = {"id": sms_id, "name": data.HDFC, "type": "bank", "sms_label": data.HDFC}
    r = client.post(URL, headers=h, json={**body, "opening_balance_minor": 1})
    assert r.status_code == 201, r.text
    assert (r.json()["id"], r.json()["opening_balance_minor"], r.json()["version"]) == (
        HDFC_ID,
        2_748_000,
        1,
    )
    assert len(log_rows(uid("john"))) == before
    other, _ = register(client, "Zoya", "zoya@example.com")
    r = client.post(URL, headers=other, json=body)
    assert (r.status_code, r.json()["error"]["code"]) == (409, "id_taken")


def test_other_people_cant_see_or_change_an_account(client, seeded):
    other, _ = register(client, "Zoya", "zoya@example.com")
    assert client.get(URL, headers=other).json() == []
    body = {"name": "Mine now", "type": "bank"}
    for method, path in [
        ("GET", f"{URL}/{HDFC_ID}"),
        ("PUT", f"{URL}/{HDFC_ID}"),
        ("DELETE", f"{URL}/{HDFC_ID}"),
        ("POST", f"{URL}/{HDFC_ID}/restore"),
    ]:
        r = client.request(method, path, headers=other, json=body if method == "PUT" else None)
        assert (r.status_code, r.json()["error"]["code"]) == (404, "not_found"), method
    assert client.get(f"{URL}/{HDFC_ID}", headers=login(client, "john")).json()["name"] == (
        data.HDFC
    )


def test_an_account_in_use_cant_be_deleted(client, seeded):
    h = login(client, "john")
    r = client.delete(f"{URL}/{CARD_ID}", headers=h)
    assert r.status_code == 409
    assert r.json()["error"] == {
        "code": "account_in_use",
        "message": "This account has entries, so it can't be deleted. Close it instead",
    }
    # The coffee and the bill payment deleted (the bill's HDFC leg goes with it), it can go: a
    # deleted entry may keep pointing at it.
    items = client.get(f"{API}/personal/transactions?account_id={CARD_ID}", headers=h).json()
    assert sorted(i["description"] for i in items["items"]) == [
        "Blue Tokai coffee",
        "Credit card bill",
    ]
    for i in items["items"]:
        client.delete(f"{API}/personal/transactions/{i['id']}", headers=h)
    assert client.delete(f"{URL}/{CARD_ID}", headers=h).json()["deleted_at"]
    # Its entries can't come back while it's deleted.
    coffee = next(i for i in items["items"] if i["type"] == "expense")
    r = client.post(f"{API}/personal/transactions/{coffee['id']}/restore", headers=h)
    assert (r.status_code, r.json()["error"]["code"]) == (422, "unknown_account")
    client.post(f"{URL}/{CARD_ID}/restore", headers=h)
    r = client.post(f"{API}/personal/transactions/{coffee['id']}/restore", headers=h)
    assert r.status_code == 200 and r.json()["deleted_at"] is None


def test_closing_and_reopening(client, seeded):
    h = login(client, "john")
    hdfc = client.get(f"{URL}/{HDFC_ID}", headers=h).json()
    body = {"name": hdfc["name"], "type": "bank", "sms_label": data.HDFC}
    closed = client.put(f"{URL}/{HDFC_ID}", headers=h, json={**body, "status": "closed"}).json()
    assert closed["status"] == "closed"
    assert HDFC_ID in {a["id"] for a in client.get(URL, headers=h).json()}  # still listed
    # Null keeps the status, and nothing changed, so nothing is recorded.
    same = client.put(f"{URL}/{HDFC_ID}", headers=h, json={**body, "status": None}).json()
    assert (same["status"], same["version"]) == ("closed", closed["version"])
    reopened = client.put(f"{URL}/{HDFC_ID}", headers=h, json={**body, "status": "active"}).json()
    assert reopened["status"] == "active"
    rows = log_rows(uid("john"), "personal_account")
    assert [(r.action, r.version) for r in rows] == [
        ("personal_account.close", 2),
        ("personal_account.reopen", 3),
    ]
    assert rows[0].data["status"] == "closed"


def test_a_label_moves_in_entries_without_an_account(client, seeded):
    h = login(client, "john")
    first = entry(client, h, "Bus pass", "SBI ··0042")
    client.delete(f"{API}/personal/transactions/{first['id']}", headers=h)  # deleted ones too
    entry(client, h, "Bus pass", "SBI ··0042")
    entry(client, h, "Elsewhere", "Axis ··7777")
    assert linked("Bus pass") == [None, None]

    sbi = client.post(
        URL, headers=h, json={"name": "SBI", "type": "bank", "sms_label": "SBI ··0042"}
    ).json()
    assert linked("Bus pass") == [sbi["id"], sbi["id"]]
    assert linked("Elsewhere") == [None]
    rows = log_rows(uid("john"))[-3:]
    assert [(r.entity, r.action) for r in rows] == [
        ("personal_account", "personal_account.create"),
        ("personal_transaction", "personal.update"),
        ("personal_transaction", "personal.update"),
    ]
    assert {r.data["account_id"] for r in rows[1:]} == {sbi["id"]}
    assert {r.version for r in rows[1:]} == {2, 3}  # the deleted one was at 2 already

    # Labelling an existing account does the same, but only while it's open.
    axis = client.post(URL, headers=h, json={"name": "Axis", "type": "bank"}).json()
    labelled = {"name": "Axis", "type": "bank", "sms_label": "Axis ··7777"}
    client.put(f"{URL}/{axis['id']}", headers=h, json={"name": "Axis", "type": "bank"})
    closed = client.put(f"{URL}/{axis['id']}", headers=h, json={**labelled, "status": "closed"})
    assert closed.json()["sms_label"] == "Axis ··7777"
    assert linked("Elsewhere") == [None]
    client.put(f"{URL}/{axis['id']}", headers=h, json={**labelled, "status": "active"})
    assert linked("Elsewhere") == [axis["id"]]
    # Entries already in an account stay there when another account takes the label.
    unlabelled = {"name": "SBI", "type": "bank", "sms_label": None}
    assert client.put(f"{URL}/{sbi['id']}", headers=h, json=unlabelled).json()["sms_label"] is None
    again = {"name": "SBI again", "type": "bank", "sms_label": "SBI ··0042"}
    assert client.post(URL, headers=h, json=again).status_code == 201
    assert linked("Bus pass") == [sbi["id"], sbi["id"]]


def test_accounts_sync_on_the_owners_stream(client, seeded):
    h = login(client, "john")
    wallet = client.post(URL, headers=h, json={"name": "Wallet", "type": "cash"}).json()
    [row] = log_rows(uid("john"), "personal_account")
    assert (str(row.entity_id), row.op, row.version) == (wallet["id"], "upsert", 1)
    snap = client.get(f"{API}/sync/snapshot/user:{uid('john')}", headers=h).json()
    accounts = {e["entity_id"]: e for e in snap["entities"] if e["entity"] == "personal_account"}
    assert len(accounts) == len(data.ACCOUNTS) + 1
    # Snapshot and log entries have the same shape.
    assert accounts[wallet["id"]]["data"] == row.data
    assert row.data["opening_balance_minor"] == 0 and row.data["currency"] == "INR"
    # Not on anyone else's stream.
    with SessionLocal() as s:
        streams = s.scalars(
            select(ChangeLog.stream_id).where(ChangeLog.entity == "personal_account")
        ).all()
    assert set(streams) == {f"user:{uid('john')}"}


def test_read_only_view_as_cant_write_accounts(client, seeded):
    _, as_rahul = start(client, login(client, "john"))
    r = client.post(URL, headers=as_rahul, json={"name": "Wallet", "type": "cash"})
    assert (r.status_code, r.json()["error"]["code"]) == (403, "read_only")
    assert client.get(URL, headers=as_rahul).status_code == 200  # reading is fine
    with SessionLocal() as s:
        assert s.scalar(select(func.count()).select_from(PersonalAccount)) == len(data.ACCOUNTS)


def test_entries_go_in_your_own_open_accounts(client, seeded):
    h = login(client, "john")
    txns = f"{API}/personal/transactions"
    body = {"type": "expense", "amount_minor": 1000, "description": "Tea", "date": "2026-09-24"}
    other, _ = register(client, "Zoya", "zoya@example.com")
    r = client.post(txns, headers=other, json={**body, "account_id": HDFC_ID})
    assert r.json()["error"] == {
        "code": "unknown_account",
        "message": "That account isn't available",
    }

    card = client.get(f"{URL}/{CARD_ID}", headers=h).json()
    client.put(
        f"{URL}/{CARD_ID}",
        headers=h,
        json={"name": card["name"], "type": "credit_card", "status": "closed"},
    )
    r = client.post(txns, headers=h, json={**body, "account_id": CARD_ID})
    assert r.json()["error"] == {"code": "account_closed", "message": "That account is closed"}
    # An entry already in it can still be edited; another can't move in.
    [coffee] = client.get(f"{txns}?account_id={CARD_ID}&type=expense", headers=h).json()["items"]
    edit = {k: coffee[k] for k in ("type", "amount_minor", "date", "account_id", "version")}
    r = client.put(f"{txns}/{coffee['id']}", headers=h, json={**edit, "description": "Coffee"})
    assert r.status_code == 200, r.text
    tea = client.post(txns, headers=h, json=body).json()
    r = client.put(
        f"{txns}/{tea['id']}", headers=h, json={**body, "account_id": CARD_ID, "version": 1}
    )
    assert r.json()["error"]["code"] == "account_closed"

    # Your entries are in your currency, and so must the account be.
    client.patch(f"{API}/me", headers=h, json={"currency": "USD"})
    r = client.post(txns, headers=h, json={**body, "account_id": HDFC_ID})
    assert r.json()["error"] == {
        "code": "currency_mismatch",
        "message": "That account is in INR; this entry is in USD",
    }
