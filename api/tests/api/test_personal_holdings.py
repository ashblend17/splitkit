"""Holdings: kept in your investment accounts with their latest value as typed, never priced or
judged on the server; named by investment entries; never deleted from under one."""

import uuid

import pytest
from sqlalchemy import func, select

from app.core.db import SessionLocal
from app.models import ChangeLog
from app.seed import data
from app.seed.loader import account_id, seed_id
from tests.api.conftest import login, register, uid
from tests.api.test_admin import start

API = "/api/v1"
URL = f"{API}/personal/holdings"
TXNS = f"{API}/personal/transactions"
ACCOUNTS = f"{API}/personal/accounts"
ZERODHA, HDFC = (
    str(account_id(next(a for a in data.ACCOUNTS if a.key == k))) for k in ("zerodha", "hdfc")
)
NIFTY, TATA = (str(seed_id("holding", f"john:{k}")) for k in ("nifty", "tata"))
SIP_SCHEDULE = str(seed_id("reminder_schedule", "john:sip"))


def holding(**extra) -> dict:
    return {
        "account_id": ZERODHA,
        "name": "Gold ETF",
        "asset_type": "gold",
        "quantity": "10.5",
        "cost_basis_minor": 5_000_000,
        "market_value_minor": 5_500_000,
        "valuation_at": "2026-09-30",
        **extra,
    }


def investment(**extra) -> dict:
    return {
        "type": "investment_contribution",
        "amount_minor": 200_000,
        "description": "Top-up",
        "date": "2026-09-24",
        "account_id": HDFC,
        **extra,
    }


def error(r) -> tuple[str, str]:
    assert r.status_code in (409, 422), r.text
    return r.json()["error"]["code"], r.json()["error"]["message"]


def log_count() -> int:
    with SessionLocal() as s:
        return s.scalar(select(func.count()).select_from(ChangeLog))


def test_the_seeded_holdings(client, seeded):
    h = login(client, "john")
    nifty, tata = client.get(f"{URL}?account_id={ZERODHA}", headers=h).json()
    assert (nifty["name"], nifty["quantity"], nifty["cost_basis_minor"]) == (
        "Nifty 50 index fund",
        "412.358",
        6_000_000,
    )
    assert (nifty["market_value_minor"], nifty["valuation_at"], nifty["currency"]) == (
        6_845_000,
        "2026-08-15",
        "INR",
    )
    assert (tata["quantity"], tata["cost_basis_minor"], tata["asset_type"]) == ("18", None, "stock")
    # No gain and no stale flag: the app works those out.
    assert not {"gain_minor", "stale"} & set(nifty)
    [sip] = client.get(f"{TXNS}?type=investment_contribution", headers=h).json()["items"]
    assert (sip["holding_id"], sip["amount_minor"], sip["date"]) == (NIFTY, 500_000, "2026-09-05")


def test_create_revalue_delete_and_restore(client, seeded):
    h = login(client, "john")
    r = client.post(URL, headers=h, json=holding())
    assert r.status_code == 201, r.text
    etf = r.json()
    assert (etf["quantity"], etf["valuation_source"], etf["version"]) == ("10.5", "manual", 1)
    # "Update value": the account, quantity and cost basis stay when left out.
    revalue = {
        "name": "Gold ETF",
        "asset_type": "gold",
        "market_value_minor": 5_800_000,
        "valuation_at": "2026-10-01",
        "version": 1,
    }
    r = client.put(f"{URL}/{etf['id']}", headers=h, json=revalue)
    assert r.status_code == 200, r.text
    assert (r.json()["market_value_minor"], r.json()["quantity"], r.json()["cost_basis_minor"]) == (
        5_800_000,
        "10.5",
        5_000_000,
    )
    # A null cost basis clears it.
    r = client.put(
        f"{URL}/{etf['id']}", headers=h, json={**revalue, "version": 2, "cost_basis_minor": None}
    )
    assert r.json()["cost_basis_minor"] is None
    assert error(client.put(f"{URL}/{etf['id']}", headers=h, json=revalue))[0] == "version_conflict"
    assert client.delete(f"{URL}/{etf['id']}", headers=h).json()["deleted_at"]
    assert [x["id"] for x in client.get(f"{URL}?deleted=true", headers=h).json()] == [etf["id"]]
    assert error(client.put(f"{URL}/{etf['id']}", headers=h, json=revalue))[0] == "deleted"
    assert client.post(f"{URL}/{etf['id']}/restore", headers=h).json()["deleted_at"] is None


@pytest.mark.parametrize(
    ("body", "code", "message"),
    [
        (holding(account_id=None), "account_required", "Pick the investment account it's in"),
        (
            holding(account_id=HDFC),
            "not_investment_account",
            "Holdings go in an investment account",
        ),
        (holding(account_id=str(uuid.uuid4())), "unknown_account", "That account isn't available"),
        (holding(valuation_at="2099-01-01"), "invalid_input", "A value can't be from the future"),
        (holding(market_value_minor=-1), "invalid_input", None),
        (holding(quantity="-1"), "invalid_input", None),
        (holding(quantity="1.1234567"), "invalid_input", None),
        (holding(asset_type="crypto"), "invalid_input", None),
    ],
)
def test_what_a_holding_needs(client, seeded, body, code, message):
    r = client.post(URL, headers=login(client, "john"), json=body)
    assert error(r)[0] == code
    if message:
        assert error(r)[1] == message


def test_investment_entries_name_holdings(client, seeded):
    h = login(client, "john")
    r = client.post(TXNS, headers=h, json=investment(holding_id=NIFTY))
    assert r.status_code == 201, r.text
    assert r.json()["holding_id"] == NIFTY
    withdrawal = investment(type="investment_withdrawal", holding_id=TATA, account_id=HDFC)
    assert client.post(TXNS, headers=h, json=withdrawal).status_code == 201
    r = client.post(TXNS, headers=h, json=investment(type="expense", holding_id=NIFTY))
    assert error(r) == ("holding_invalid", "Only an investment or a withdrawal names a holding")
    r = client.post(TXNS, headers=h, json=investment(holding_id=str(uuid.uuid4())))
    assert error(r) == ("unknown_holding", "That holding isn't available")
    other, _ = register(client, "Zoya", "zoya@example.com")
    r = client.post(TXNS, headers=other, json=investment(account_id=None, holding_id=NIFTY))
    assert error(r)[0] == "unknown_holding"


def test_what_a_holding_and_its_account_guard(client, seeded):
    h = login(client, "john")
    # The SIP entry names the index fund, so it stays; its SIP reminder would go with it.
    assert error(client.delete(f"{URL}/{NIFTY}", headers=h)) == (
        "holding_in_use",
        "An entry names this holding. Change or delete them first",
    )
    [sip] = client.get(f"{TXNS}?type=investment_contribution", headers=h).json()["items"]
    client.delete(f"{TXNS}/{sip['id']}", headers=h)
    assert client.delete(f"{URL}/{NIFTY}", headers=h).status_code == 200
    schedules = f"{API}/personal/reminder-schedules"
    assert client.get(f"{schedules}/{SIP_SCHEDULE}", headers=h).json()["deleted_at"]
    r = client.post(f"{TXNS}/{sip['id']}/restore", headers=h)
    assert error(r) == (
        "unknown_holding",
        "This entry's holding was deleted. Restore the holding first",
    )
    client.post(f"{URL}/{NIFTY}/restore", headers=h)
    assert client.get(f"{schedules}/{SIP_SCHEDULE}", headers=h).json()["deleted_at"] is None
    assert client.post(f"{TXNS}/{sip['id']}/restore", headers=h).status_code == 200

    # An account with holdings can't be deleted, nor stop being an investment account.
    assert error(client.delete(f"{ACCOUNTS}/{ZERODHA}", headers=h)) == (
        "account_in_use",
        "This account has holdings, so it can't be deleted",
    )
    r = client.put(f"{ACCOUNTS}/{ZERODHA}", headers=h, json={"name": "Zerodha", "type": "bank"})
    assert error(r) == (
        "account_in_use",
        "This account has holdings, so it stays an investment account",
    )
    # A holding can't come back to a deleted account, nor go into a closed one.
    groww = client.post(ACCOUNTS, headers=h, json={"name": "Groww", "type": "investment"}).json()
    fund = client.post(URL, headers=h, json=holding(account_id=groww["id"])).json()
    client.delete(f"{URL}/{fund['id']}", headers=h)
    client.delete(f"{ACCOUNTS}/{groww['id']}", headers=h)
    r = client.post(f"{URL}/{fund['id']}/restore", headers=h)
    assert error(r) == (
        "unknown_account",
        "This holding's account was deleted. Restore the account first",
    )
    client.post(f"{ACCOUNTS}/{groww['id']}/restore", headers=h)
    client.put(
        f"{ACCOUNTS}/{groww['id']}",
        headers=h,
        json={"name": "Groww", "type": "investment", "status": "closed"},
    )
    r = client.post(URL, headers=h, json=holding(account_id=groww["id"]))
    assert error(r) == ("account_closed", "That account is closed")


def test_other_people_cant_see_or_use_holdings(client, seeded):
    other, _ = register(client, "Zoya", "zoya@example.com")
    assert client.get(URL, headers=other).json() == []
    for method, path in [
        ("GET", f"{URL}/{NIFTY}"),
        ("PUT", f"{URL}/{NIFTY}"),
        ("DELETE", f"{URL}/{NIFTY}"),
        ("POST", f"{URL}/{NIFTY}/restore"),
    ]:
        r = client.request(method, path, headers=other, json=holding() if method == "PUT" else None)
        assert (r.status_code, r.json()["error"]["code"]) == (404, "not_found"), method
    assert error(client.post(URL, headers=other, json=holding()))[0] == "unknown_account"


def test_an_account_a_holding_and_an_investment_in_one_batch(client, seeded):
    h = login(client, "john")
    kuvera, fund = str(uuid.uuid4()), str(uuid.uuid4())
    items = [
        {
            "kind": "account",
            "op": "create",
            "id": kuvera,
            "account": {"name": "Kuvera", "type": "investment"},
        },
        {"kind": "holding", "op": "create", "id": fund, "holding": holding(account_id=kuvera)},
        {
            "kind": "transaction",
            "op": "create",
            "id": str(uuid.uuid4()),
            "transaction": investment(holding_id=fund),
        },
    ]
    r = client.post(f"{API}/personal/batch", headers=h, json={"items": items})
    assert r.status_code == 201, r.text
    assert [i["kind"] for i in r.json()["items"]] == ["account", "holding", "transaction"]
    before = log_count()
    again = client.post(f"{API}/personal/batch", headers=h, json={"items": items})
    assert (again.json(), log_count()) == (r.json(), before)


def test_holdings_sync_on_the_owners_stream(client, seeded):
    h = login(client, "john")
    etf = client.post(URL, headers=h, json=holding()).json()
    with SessionLocal() as s:
        [row] = s.scalars(select(ChangeLog).where(ChangeLog.entity == "personal_holding")).all()
    assert (row.stream_id, str(row.entity_id), row.data["quantity"]) == (
        f"user:{uid('john')}",
        etf["id"],
        "10.5",
    )
    snap = client.get(f"{API}/sync/snapshot/user:{uid('john')}", headers=h).json()
    held = {
        e["entity_id"]: e["data"] for e in snap["entities"] if e["entity"] == "personal_holding"
    }
    assert len(held) == len(data.HOLDINGS) + 1 and held[etf["id"]] == row.data


def test_read_only_view_as_cant_write_holdings(client, seeded):
    _, as_rahul = start(client, login(client, "john"))
    r = client.post(URL, headers=as_rahul, json=holding())
    assert (r.status_code, r.json()["error"]["code"]) == (403, "read_only")
