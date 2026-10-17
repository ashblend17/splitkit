"""Personal entries from bank SMS, and entries linked to the split or payment they became."""

import uuid

from app.seed.loader import seed_id
from tests.api.conftest import cat, eid, gid, login, register
from tests.api.test_sync import log_rows

API = "/api/v1"
PAY_RAHUL = str(seed_id("settlement", "goa_pay_rahul"))


def entry(**overrides):
    return {
        "type": "expense",
        "amount_minor": 62000,
        "description": "Uber",
        "date": "2026-09-22",
        "category_id": cat("transport"),
        **overrides,
    }


def post(client, headers, **overrides):
    return client.post(f"{API}/personal/transactions", headers=headers, json=entry(**overrides))


def summary(client, headers):
    return client.get(f"{API}/personal/summary?month=2026-09-23", headers=headers).json()


def test_a_split_entry_is_listed_but_not_counted(client, seeded):
    h = login(client, "john")
    before = summary(client, h)
    r = post(client, h, expense_id=eid("goa_tickets"))  # John paid the return tickets
    assert r.status_code == 201, r.text
    assert (r.json()["expense_id"], r.json()["counted"]) == (eid("goa_tickets"), False)
    after = summary(client, h)
    assert (after["spent_minor"], after["by_category"]) == (
        before["spent_minor"],
        before["by_category"],
    )
    listed = client.get(
        f"{API}/personal/transactions?start=2026-09-22&end=2026-09-22", headers=h
    ).json()
    assert r.json()["id"] in {i["id"] for i in listed["items"]}
    assert listed["spent_minor"] == 0  # the seed's Uber and Rahul rows that day are linked too


def test_links_are_checked(client, seeded):
    h = login(client, "john")

    def refused(**links):
        r = post(client, h, **links)
        assert r.status_code == 422, r.text
        return r.json()["error"]["code"], r.json()["error"]["message"]

    assert refused(expense_id=eid("goa_dinner")) == ("link_invalid", "Link a split you paid for")
    assert refused(expense_id=str(uuid.uuid4()))[0] == "unknown_expense"
    assert refused(type="income", expense_id=eid("goa_tickets")) == (
        "link_invalid",
        "Only spending can be split",
    )
    assert refused(expense_id=eid("goa_tickets"), settlement_id=PAY_RAHUL)[0] == "link_invalid"
    # John paid Rahul: spending can be that payment, income can't.
    assert post(client, h, settlement_id=PAY_RAHUL).status_code == 201
    assert refused(type="income", settlement_id=PAY_RAHUL) == (
        "link_invalid",
        "Link a payment you received",
    )
    rahul = login(client, "rahul")
    r = client.post(
        f"{API}/personal/transactions",
        headers=rahul,
        json=entry(type="income", category_id=None, settlement_id=PAY_RAHUL),
    )
    assert r.status_code == 201, r.text
    assert r.json()["counted"] is False
    # Someone outside the group can't link its expenses, even by id.
    other, _ = register(client, "Outsider", "outsider@example.com")
    r = client.post(
        f"{API}/personal/transactions",
        headers=other,
        json=entry(category_id=None, expense_id=eid("goa_tickets")),
    )
    assert r.json()["error"]["code"] == "unknown_expense"


def test_deleting_the_split_counts_the_entry_again(client, seeded):
    h = login(client, "john")
    spent = summary(client, h)["spent_minor"]
    t = post(client, h, expense_id=eid("goa_tickets")).json()
    assert summary(client, h)["spent_minor"] == spent
    expense = client.get(f"{API}/expenses/{eid('goa_tickets')}", headers=h).json()
    client.delete(f"{API}/expenses/{eid('goa_tickets')}?version={expense['version']}", headers=h)
    assert summary(client, h)["spent_minor"] == spent + 62000
    assert client.get(f"{API}/personal/transactions/{t['id']}", headers=h).json()["counted"] is True
    # The link stays (it points at a deleted expense), and other edits still go through.
    edited = client.put(
        f"{API}/personal/transactions/{t['id']}",
        headers=h,
        json={
            **entry(expense_id=t["expense_id"]),
            "description": "Tickets",
            "version": t["version"],
        },
    )
    assert edited.status_code == 200, edited.text


def test_leaving_the_group_counts_the_entry_again(client, seeded):
    h, me = register(client, "Solo", "solo@example.com")
    group = client.post(f"{API}/groups", headers=h, json={"name": "Just me"}).json()
    expense = client.post(
        f"{API}/groups/{group['id']}/expenses",
        headers=h,
        json={
            "description": "Taxi",
            "amount_minor": 30000,
            "payer_id": me["id"],
            "date": "2026-09-20",
            "split": {"method": "equal", "inputs": [{"user_id": me["id"]}]},
        },
    ).json()
    t = post(client, h, amount_minor=30000, expense_id=expense["id"]).json()
    assert t["counted"] is False
    assert (
        client.delete(f"{API}/groups/{group['id']}/members/{me['id']}", headers=h).status_code
        == 204
    )
    assert client.get(f"{API}/personal/transactions/{t['id']}", headers=h).json()["counted"] is True


def test_an_update_keeps_what_it_leaves_out_and_never_changes_where_it_came_from(client, seeded):
    h = login(client, "john")
    t = post(
        client,
        h,
        source="sms",
        merchant="  UBER  ",
        account="HDFC ··4821",
        channel="upi",
        reference="426502281146",
        balance_minor=4200000,
        sms_at="2026-09-22T07:05:00+05:30",
        reviewed=False,
        expense_id=eid("goa_tickets"),
    ).json()
    assert (t["merchant"], t["source"], t["reviewed"], t["balance_minor"]) == (
        "UBER",
        "sms",
        False,
        4200000,
    )
    # An older app's edit: just the basics.
    r = client.put(
        f"{API}/personal/transactions/{t['id']}",
        headers=h,
        json={**entry(), "description": "Uber to airport", "version": t["version"]},
    ).json()
    assert r["description"] == "Uber to airport"
    assert (r["merchant"], r["channel"], r["account"], r["expense_id"], r["reviewed"]) == (
        "UBER",
        "upi",
        "HDFC ··4821",
        eid("goa_tickets"),
        False,
    )
    # Looks right, unlinked, and a try at rewriting where it came from (ignored).
    r = client.put(
        f"{API}/personal/transactions/{t['id']}",
        headers=h,
        json={
            **entry(),
            "version": r["version"],
            "reviewed": True,
            "expense_id": None,
            "source": "manual",
            "reference": "x",
            "balance_minor": 1,
        },
    ).json()
    assert (r["reviewed"], r["expense_id"], r["counted"]) == (True, None, True)
    assert (r["source"], r["reference"], r["balance_minor"]) == ("sms", "426502281146", 4200000)


def test_filters_by_account_mode_source_and_review(client, seeded):
    h = login(client, "john")

    def descriptions(query):
        r = client.get(f"{API}/personal/transactions?start=2026-09-19&{query}", headers=h).json()
        return [i["description"] for i in r["items"]]

    assert descriptions("source=sms&reviewed=false") == ["Swiggy order"]  # "Just in"
    assert descriptions("account=ICICI Credit card ··9012") == ["Blue Tokai coffee"]
    assert descriptions("channel=card") == ["Blue Tokai coffee"]
    assert "Weekend groceries" in descriptions("channel=upi")  # entered by hand, paid by UPI
    assert "Weekend groceries" not in descriptions("source=sms")


def test_accounts_have_their_latest_balance(client, seeded):
    accounts = client.get(f"{API}/personal/accounts/reported", headers=login(client, "john")).json()
    assert [(a["account"], a["balance_minor"], a["count"]) for a in accounts] == [
        ("HDFC ··4821", 3993600, 6),  # after the groceries on 23 Sep
        ("ICICI Credit card ··9012", None, 1),  # cards report a limit, not a balance
    ]
    assert accounts[0]["balance_at"].startswith("2026-09-23T")
    other, _ = register(client, "Someone", "someone@example.com")
    assert client.get(f"{API}/personal/accounts/reported", headers=other).json() == []


def test_sync_entries_carry_the_new_fields(client, seeded):
    h = login(client, "john")
    t = post(
        client, h, source="sms", merchant="UBER", reviewed=False, expense_id=eid("goa_tickets")
    ).json()
    data = log_rows(f"user:{seed_id('user', 'john')}")[-1].data
    assert (data["id"], data["source"], data["reviewed"], data["expense_id"]) == (
        t["id"],
        "sms",
        False,
        eid("goa_tickets"),
    )
    # Bank details stay out of the group's stream.
    assert all("reviewed" not in r.data for r in log_rows(f"group:{gid('goa')}"))


def test_a_repeated_create_of_a_deleted_entry_stays_deleted(client, seeded):
    """The app gives each bank SMS a fixed id, so reading the inbox again can't bring back an
    entry you deleted ("Not mine")."""
    h = login(client, "john")
    t = post(client, h, id=str(uuid.uuid4()), source="sms").json()
    client.delete(f"{API}/personal/transactions/{t['id']}?version={t['version']}", headers=h)
    again = post(client, h, id=t["id"], source="sms")
    assert again.status_code == 201
    assert again.json()["deleted_at"] is not None
