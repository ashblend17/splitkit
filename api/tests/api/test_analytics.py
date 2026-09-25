from tests.api.conftest import gid, login

API = "/api/v1"


def cards(client, headers, path):
    return {c["type"]: c for c in client.get(f"{API}{path}", headers=headers).json()["cards"]}


def test_personal_dashboard_matches_personal_analytics_mockup(client, seeded):
    c = cards(client, login(client, "ansh"), "/analytics/personal?period=month&on=2026-09-23")
    trend = c["spending_trend"]
    assert (trend["title"], trend["period_label"], trend["headline"]) == (
        "Monthly spending",
        "Last 6 months",
        "₹32,450",
    )
    assert [(b["label"], b["value_minor"] // 100) for b in trend["bars"]] == [
        ("Apr", 24180),
        ("May", 29640),
        ("Jun", 27310),
        ("Jul", 35920),
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


def test_period_switch(client, seeded):
    headers = login(client, "ansh")
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
    headers = login(client, "ansh")
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
    headers = login(client, "ansh")
    layout = client.get(f"{API}/analytics/layout/personal", headers=headers).json()
    assert layout["customised"] is False and len(layout["cards"]) == 4
    reordered = [layout["cards"][3], layout["cards"][0]]  # stat first, drop two cards
    saved = client.put(
        f"{API}/analytics/layout/personal", headers=headers, json={"cards": reordered}
    ).json()
    assert saved["customised"] is True
    dash = client.get(f"{API}/analytics/personal?on=2026-09-23", headers=headers).json()
    assert [c["type"] for c in dash["cards"]] == ["average_daily", "spending_trend"]
    # other people keep the defaults
    assert (
        len(client.get(f"{API}/analytics/personal", headers=login(client, "rahul")).json()["cards"])
        == 4
    )
    reset = client.delete(f"{API}/analytics/layout/personal", headers=headers).json()
    assert reset["customised"] is False and len(reset["cards"]) == 4


def test_unknown_sources_are_rejected(client, seeded):
    r = client.put(
        f"{API}/analytics/layout/personal",
        headers=login(client, "ansh"),
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
