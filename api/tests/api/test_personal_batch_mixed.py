"""POST /personal/batch: accounts and entries in order, all or none; and how older apps' bodies
(no direction, no account_id) are read."""

import uuid

from sqlalchemy import func, select

from app.core.db import SessionLocal
from app.models import ChangeLog, PersonalAccount
from app.seed import data
from app.seed.loader import account_id
from tests.api.conftest import login

API = "/api/v1"
TXNS = f"{API}/personal/transactions"
BATCH = f"{API}/personal/batch"
HDFC = str(account_id(next(a for a in data.ACCOUNTS if a.key == "hdfc")))


def spend(**extra) -> dict:
    return {
        "type": "expense",
        "amount_minor": 34000,
        "description": "Coffee",
        "date": "2026-09-24",
        **extra,
    }


def txn(body: dict, id: str | None = None, op: str = "create", version: int | None = None):
    return {
        "kind": "transaction",
        "op": op,
        "id": id or str(uuid.uuid4()),
        "version": version,
        "transaction": body,
    }


def account(id: str, name: str = "Wallet", op: str = "create", version: int | None = None):
    return {
        "kind": "account",
        "op": op,
        "id": id,
        "version": version,
        "account": {"name": name, "type": "cash"},
    }


def log_count() -> int:
    with SessionLocal() as s:
        return s.scalar(select(func.count()).select_from(ChangeLog))


def test_an_account_and_an_entry_that_uses_it(client, seeded):
    h = login(client, "john")
    wallet = str(uuid.uuid4())
    r = client.post(
        BATCH, headers=h, json={"items": [account(wallet), txn(spend(account_id=wallet))]}
    )
    assert r.status_code == 201, r.text
    made, entry = r.json()["items"]
    assert (made["kind"], made["account"]["id"], made["transaction"]) == ("account", wallet, None)
    assert (entry["kind"], entry["transaction"]["account_id"]) == ("transaction", wallet)
    assert entry["transaction"]["direction"] == "out"


def test_a_refusal_keeps_nothing_and_names_the_item(client, seeded):
    h = login(client, "john")
    before = log_count()
    items = [
        account(str(uuid.uuid4())),
        txn(spend()),
        txn(spend()),
        txn(spend(category_id=str(uuid.uuid4()))),
    ]
    r = client.post(BATCH, headers=h, json={"items": items})
    assert r.status_code == 422
    assert r.json()["error"] == {
        "code": "unknown_category",
        "message": "That category isn't available",
        "item": 3,
    }
    assert log_count() == before
    with SessionLocal() as s:
        assert s.scalar(select(func.count()).select_from(PersonalAccount)) == len(data.ACCOUNTS)
    assert client.get(f"{TXNS}/{items[1]['id']}", headers=h).status_code == 404


def test_sending_a_batch_again_changes_nothing(client, seeded):
    h = login(client, "john")
    wallet = str(uuid.uuid4())
    body = {"items": [account(wallet), txn(spend(account_id=wallet))]}
    first = client.post(BATCH, headers=h, json=body).json()
    before = log_count()
    again = client.post(BATCH, headers=h, json=body)
    assert again.status_code == 201
    assert again.json() == first
    assert log_count() == before


def test_a_stale_update_applies_nothing(client, seeded):
    h = login(client, "john")
    [swiggy] = client.get(f"{TXNS}?source=sms&reviewed=false", headers=h).json()["items"]
    fresh = txn(spend())
    stale = txn(spend(description="Swiggy"), id=swiggy["id"], op="update", version=99)
    r = client.post(BATCH, headers=h, json={"items": [fresh, stale]})
    assert r.status_code == 409
    assert (r.json()["error"]["code"], r.json()["error"]["item"]) == ("version_conflict", 1)
    assert client.get(f"{TXNS}/{fresh['id']}", headers=h).status_code == 404
    # The right version goes through, and so does an account update.
    ok = txn(spend(description="Swiggy"), id=swiggy["id"], op="update", version=swiggy["version"])
    hdfc = account(HDFC, name="HDFC savings", op="update", version=1)
    hdfc["account"]["type"] = "bank"
    r = client.post(BATCH, headers=h, json={"items": [ok, hdfc]})
    assert r.status_code == 201, r.text
    entry, acct = r.json()["items"]
    assert entry["transaction"]["description"] == "Swiggy"
    assert (acct["account"]["name"], acct["account"]["version"]) == ("HDFC savings", 2)


def test_an_entry_cant_use_an_account_made_later(client, seeded):
    h = login(client, "john")
    wallet = str(uuid.uuid4())
    r = client.post(
        BATCH, headers=h, json={"items": [txn(spend(account_id=wallet)), account(wallet)]}
    )
    assert r.status_code == 422
    assert (r.json()["error"]["code"], r.json()["error"]["item"]) == ("unknown_account", 0)


def test_the_batch_size_and_item_shapes_are_checked(client, seeded):
    h = login(client, "john")
    for items in ([], [txn(spend()) for _ in range(101)]):
        r = client.post(BATCH, headers=h, json={"items": items})
        assert (r.status_code, r.json()["error"]["code"]) == (422, "invalid_input")
    wrong = {"kind": "account", "op": "create", "id": str(uuid.uuid4()), "transaction": spend()}
    deleting = {**txn(spend()), "op": "delete"}
    for item, message in [
        (wrong, "Each item needs the details for its kind"),
        (deleting, "Each item needs the details for its kind"),
        (txn({**spend(), "id": str(uuid.uuid4())}), "An item's details can't have a different id"),
    ]:
        r = client.post(BATCH, headers=h, json={"items": [item]})
        assert r.status_code == 422
        assert r.json()["error"]["message"] == message


def test_the_old_batch_and_old_bodies(client, seeded):
    """An older app sends no direction and no account_id: the direction follows from the type,
    and the account from the label, when you have an open account with it."""
    h = login(client, "john")
    r = client.post(
        f"{TXNS}/batch",
        headers=h,
        json={
            "items": [
                spend(account=data.HDFC),
                spend(type="income", description="Refund from a friend", account="Unknown ··1"),
            ]
        },
    )
    assert r.status_code == 201, r.text
    hdfc, other = r.json()["items"]
    assert (hdfc["direction"], hdfc["account_id"]) == ("out", HDFC)
    assert (other["direction"], other["account_id"]) == ("in", None)
    # A newer app says which account, even none.
    r = client.post(TXNS, headers=h, json=spend(account=data.HDFC, account_id=None))
    assert r.json()["account_id"] is None

    # An older app relabelling an entry moves it to that label's account.
    body = {k: other[k] for k in ("type", "amount_minor", "description", "date", "version")}
    r = client.put(f"{TXNS}/{other['id']}", headers=h, json={**body, "account": data.HDFC})
    assert r.json()["account_id"] == HDFC
    # And an edit that leaves the account out keeps it.
    body["version"] = r.json()["version"]
    r = client.put(f"{TXNS}/{other['id']}", headers=h, json={**body, "description": "Repaid"})
    assert (r.json()["account_id"], r.json()["account"]) == (HDFC, data.HDFC)
