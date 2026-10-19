from sqlalchemy import text

from app.core.db import SessionLocal
from tests.api.conftest import cat, gid, login, register, uid

API = "/api/v1"
TXNS = f"{API}/personal/transactions"


def cards(client, headers, path):
    return {c["type"]: c for c in client.get(f"{API}{path}", headers=headers).json()["cards"]}


def test_personal_dashboard_matches_personal_analytics_mockup(client, seeded):
    """The mockup's figures are your own spending: group shares left out."""
    path = "/analytics/personal?period=month&on=2026-09-23&group_share=false"
    c = cards(client, login(client, "john"), path)
    trend = c["spending_trend"]
    assert (trend["title"], trend["period_label"], trend["headline"]) == (
        "Spending over time",
        "Last 6 months",
        "₹32,450",
    )
    assert [(b["label"], b["value_minor"] // 100) for b in trend["bars"]] == [
        ("Apr", 24180),
        ("May", 29640),
        ("Jun", 27310),
        ("Jul", 34430),  # ₹35,920 spent (the mockup), less the ₹1,490 price-drop refund
        ("Aug", 30775),
        ("Sep", 32450),
    ]
    assert [b["highlight"] for b in trend["bars"]] == [False] * 5 + [True]
    by_cat = c["spending_by_category"]
    assert by_cat["period_label"] == "September"
    assert [(r["label"], r["value_minor"] // 100) for r in by_cat["rows"]] == [
        ("Rent", 18000),
        ("Food", 5820),
        ("Transport", 2940),
        ("Shopping", 2310),
        ("Fun", 1649),
        ("Bills", 1120),
        ("Health", 611),
    ]
    split = c["personal_vs_group"]
    assert [r["label"] for r in split["rows"]] == ["Personal", "Group share"]
    assert split["rows"][0]["value_minor"] == 3245000
    avg = c["average_daily"]
    assert (avg["period_label"], avg["stat"]) == (
        "1 – 23 Sep",
        {"value_minor": 141100, "note": "August averaged ₹993 per day"},
    )


def test_savings_rate_and_needs_and_wants(client, seeded):
    """September: ₹85,000 salary, ₹32,450 spent (transfers and the SIP aren't spending), group
    shares left out."""
    h = login(client, "john")
    c = cards(client, h, "/analytics/personal?period=month&on=2026-09-23&group_share=false")
    rate = c["savings_rate"]
    assert (rate["title"], rate["period_label"], rate["headline"], rate["stat"]) == (
        "Savings rate",
        "September",
        "62%",
        {"value_minor": 5_255_000, "note": "₹52,550 saved of ₹85,000 income"},
    )
    needs = c["need_vs_want"]
    assert (needs["title"], needs["period_label"]) == ("Needs and wants", "September")
    # Rent, food, transport, bills and health are needs; shopping and fun are wants.
    assert [(r["label"], r["value_minor"] // 100) for r in needs["rows"]] == [
        ("Needs", 28491),
        ("Wants", 3959),
    ]
    # July: the refund comes off shopping, a want.
    july = cards(client, h, "/analytics/personal?period=month&on=2026-07-31&group_share=false")
    assert july["savings_rate"]["headline"] == "59%"  # 50,570 of 85,000
    assert [(r["label"], r["value_minor"] // 100) for r in july["need_vs_want"]["rows"]] == [
        ("Needs", 26230),
        ("Wants", 8200),
    ]
    week = cards(client, h, "/analytics/personal?period=week&on=2026-09-23&group_share=false")
    assert (week["savings_rate"]["headline"], week["savings_rate"]["stat"]) == (
        "—",
        {"value_minor": -358_600, "note": "No income in 17 – 23 Sep"},
    )


def test_refunds_count_and_never_go_below_zero(client, seeded):
    h, _ = register(client, "Zoya", "zoya@example.com")

    def add(type_: str, amount: int, day: str, category: str | None, **extra) -> dict:
        body = {
            "type": type_,
            "amount_minor": amount,
            "description": f"{type_} {amount}",
            "date": day,
            "category_id": cat(category) if category else None,
            **extra,
        }
        r = client.post(TXNS, headers=h, json=body)
        assert r.status_code == 201, r.text
        return r.json()

    jacket = add("expense", 100_000, "2026-08-20", "shopping")
    add("refund", 60_000, "2026-09-05", "shopping", refund_of_id=jacket["id"])
    add("expense", 20_000, "2026-09-06", "food")
    add("expense", 5_000, "2026-09-07", "other")
    add("expense", 1_000, "2026-09-08", None)
    c = cards(client, h, "/analytics/personal?period=month&on=2026-09-23")
    trend = c["spending_trend"]
    assert [b["value_minor"] for b in trend["bars"]][-2:] == [100_000, 0]
    assert trend["headline"] == "−₹340"
    assert [(r["label"], r["value_minor"]) for r in c["spending_by_category"]["rows"]] == [
        ("Food", 20_000),
        ("Other", 5_000),
        ("Uncategorised", 1_000),
    ]
    assert c["personal_vs_group"]["rows"][0] == {"label": "Personal", "value_minor": 0}
    assert [(r["label"], r["value_minor"]) for r in c["need_vs_want"]["rows"]] == [
        ("Needs", 20_000),
        ("Wants", 0),
        ("Not sorted", 6_000),
    ]
    rate = c["savings_rate"]
    assert (rate["headline"], rate["stat"]["value_minor"]) == ("—", 34_000)
    add("income", 200_000, "2026-09-01", "income")
    rate = cards(client, h, "/analytics/personal?period=month&on=2026-09-23")["savings_rate"]
    assert (rate["headline"], rate["stat"]["note"]) == ("117%", "₹2,340 saved of ₹2,000 income")


def test_what_isnt_spending_stays_out(client, seeded):
    """A refund of a split spend belongs to the group, like the spend; transfers, investments
    and adjustments are never spending or income."""
    h = login(client, "john")
    before = cards(client, h, "/analytics/personal?period=month&on=2026-09-23")
    items = client.get(f"{TXNS}?start=2026-09-23&end=2026-09-23&limit=50", headers=h).json()
    [groceries] = [i for i in items["items"] if i["description"] == "Groceries"]
    assert groceries["counted"] is False
    refund = {
        "type": "refund",
        "amount_minor": 50_000,
        "description": "Short delivery",
        "date": "2026-09-23",
        "category_id": cat("food"),
        "refund_of_id": groceries["id"],
    }
    assert client.post(TXNS, headers=h, json=refund).status_code == 201
    after = cards(client, h, "/analytics/personal?period=month&on=2026-09-23")
    # The groceries count once, through john's share of the group expense.
    assert after["spending_trend"]["headline"] == before["spending_trend"]["headline"] == "₹50,660"
    assert after["savings_rate"] == before["savings_rate"]
    assert after["need_vs_want"] == before["need_vs_want"]


def test_a_group_you_left_drops_out_of_your_group_share(client, seeded):
    """ISS-039: Insights and the summary count your shares only in groups you're still in, as
    your device does (it no longer has a group you've left)."""
    h = login(client, "john")
    path = "/analytics/personal?period=month&on=2026-09-23"
    assert cards(client, h, path)["personal_vs_group"]["rows"][1]["value_minor"] == 1_821_000
    summary = f"{API}/personal/summary?month=2026-09-01"
    assert client.get(summary, headers=h).json()["group_share_minor"] == 1_821_000
    with SessionLocal.begin() as s:
        s.execute(
            text("UPDATE group_members SET left_at = now() WHERE user_id = :u"), {"u": uid("john")}
        )
    c = cards(client, h, path)
    assert c["personal_vs_group"]["rows"][1]["value_minor"] == 0
    personal = c["personal_vs_group"]["rows"][0]["value_minor"]
    assert c["spending_trend"]["bars"][-1]["value_minor"] == personal
    assert client.get(summary, headers=h).json()["group_share_minor"] == 0


def test_group_shares_count_as_spending(client, seeded):
    """By default your share of group expenses is spending, as the app's cash flow counts it,
    in its expense's category; the cards about your own entries stay as they were."""
    h = login(client, "john")
    path = "/analytics/personal?period=month&on=2026-09-23"
    c, own = cards(client, h, path), cards(client, h, f"{path}&group_share=false")
    [personal, share] = [r["value_minor"] for r in c["personal_vs_group"]["rows"]]
    assert (personal, share) == (3_245_000, 1_821_000)
    spent = personal + share
    assert c["spending_trend"]["headline"] == "₹50,660"
    assert c["spending_trend"]["bars"][-1]["value_minor"] == spent
    rows = c["spending_by_category"]["rows"]
    assert sum(r["value_minor"] for r in rows) == spent
    assert {r["label"] for r in rows} > {r["label"] for r in own["spending_by_category"]["rows"]}
    assert c["average_daily"]["stat"]["value_minor"] == (spent // 23 + 50) // 100 * 100
    assert c["savings_rate"]["stat"]["value_minor"] == 8_500_000 - spent
    assert sum(r["value_minor"] for r in c["need_vs_want"]["rows"]) == spent
    for card in (
        "spending_by_account",
        "spending_by_channel",
        "top_merchants",
        "personal_vs_group",
    ):
        assert c[card] == own[card], card


def test_by_account_names_the_account(client, seeded):
    """An entry in one of your accounts goes under the account's name, else under the label it
    came with."""
    h = login(client, "john")
    accounts = {a["name"]: a for a in client.get(f"{API}/personal/accounts", headers=h).json()}
    hdfc, cash = accounts["HDFC ··4821"], accounts["Cash"]
    r = client.put(
        f"{API}/personal/accounts/{hdfc['id']}",
        headers=h,
        json={"name": "HDFC salary", "type": "bank"},
    )
    assert r.status_code == 200, r.text
    chai = {
        "type": "expense",
        "amount_minor": 3_000,
        "description": "Chai",
        "date": "2026-09-22",
        "account_id": cash["id"],
    }
    assert client.post(TXNS, headers=h, json=chai).status_code == 201
    c = cards(client, h, "/analytics/personal?period=month&on=2026-09-23")
    assert [(r["label"], r["value_minor"] // 100) for r in c["spending_by_account"]["rows"]] == [
        ("HDFC salary", 886),
        ("ICICI Credit card ··9012", 340),
        ("Cash", 30),
    ]


def test_personal_cards_from_what_entries_say(client, seeded):
    """By account, by payment mode and top merchants: September's SMS entries (the ones split
    in a group, or that were a payment, don't count)."""
    c = cards(client, login(client, "john"), "/analytics/personal?period=month&on=2026-09-23")

    def rows(card):
        return [(r["label"], r["value_minor"] // 100) for r in c[card]["rows"]]

    assert rows("spending_by_account") == [("HDFC ··4821", 886), ("ICICI Credit card ··9012", 340)]
    assert rows("spending_by_channel") == [
        ("Bank transfer", 18000),
        ("Not said", 11364),
        ("UPI", 2746),
        ("Card", 340),
    ]
    assert rows("top_merchants") == [
        ("Swiggy order", 486),
        ("Rapido ride", 400),
        ("Blue Tokai coffee", 340),
    ]
    assert c["top_merchants"]["title"] == "Top merchants"


def test_period_switch(client, seeded):
    headers = login(client, "john")
    week = cards(client, headers, "/analytics/personal?period=week&on=2026-09-23")
    assert (
        week["spending_trend"]["period_label"] == "Last 7 days"
        and len(week["spending_trend"]["bars"]) == 7
    )
    assert week["spending_by_category"]["period_label"] == "17 – 23 Sep"
    year = cards(client, headers, "/analytics/personal?period=year&on=2026-09-23")
    assert len(year["spending_trend"]["bars"]) == 12 and year["average_daily"]["stat"][
        "note"
    ].startswith("2025 averaged")


def test_group_dashboard_matches_group_analytics_mockup(client, seeded):
    headers = login(client, "john")
    r = client.get(f"{API}/analytics/groups/{gid('goa')}?on=2026-09-23", headers=headers).json()
    assert r["subtitle"] == "12 – 23 Sep · 6 members"
    c = {x["type"]: x for x in r["cards"]}
    assert c["total_spend"]["stat"] == {
        "value_minor": 4826000,
        "note": "₹8,043 per person · your share ₹10,830",
    }
    assert c["spending_trend"]["headline"] == "Peak ₹19,160 on 12 Sep"
    assert [(x["label"], x["value_minor"] // 100) for x in c["spending_by_category"]["rows"]] == [
        ("Travel", 16400),
        ("Food", 12860),
        ("Stay", 11200),
        ("Transport", 4300),
        ("Fun", 3500),
    ]
    assert [(x["label"], x["value_minor"] // 100) for x in c["paid_by_member"]["rows"]] == [
        ("Rahul", 14200),
        ("You", 11480),
        ("Aman", 8900),
        ("Priya", 6130),
        ("Vivek", 4050),
        ("Kabir", 3500),
    ]


def test_layout_is_config_driven(client, seeded):
    headers = login(client, "john")
    layout = client.get(f"{API}/analytics/layout/personal", headers=headers).json()
    assert layout["customised"] is False and len(layout["cards"]) == 9
    # stat first, then the trend and the savings rate; drop the rest
    reordered = [layout["cards"][3], layout["cards"][0], layout["cards"][7]]
    saved = client.put(
        f"{API}/analytics/layout/personal", headers=headers, json={"cards": reordered}
    ).json()
    assert saved["customised"] is True
    dash = client.get(f"{API}/analytics/personal?on=2026-09-23", headers=headers).json()
    assert [c["type"] for c in dash["cards"]] == ["average_daily", "spending_trend", "savings_rate"]
    # other people keep the defaults
    assert (
        len(client.get(f"{API}/analytics/personal", headers=login(client, "rahul")).json()["cards"])
        == 9
    )
    reset = client.delete(f"{API}/analytics/layout/personal", headers=headers).json()
    assert reset["customised"] is False and len(reset["cards"]) == 9


def test_unknown_sources_are_rejected(client, seeded):
    r = client.put(
        f"{API}/analytics/layout/personal",
        headers=login(client, "john"),
        json={
            "cards": [
                {
                    "type": "spending_trend",
                    "title": "x",
                    "period": "this_month",
                    "source": "made_up",
                }
            ]
        },
    )
    assert r.status_code == 422 and r.json()["error"]["code"] == "unknown_source"
