"""The seed data must reproduce the numbers shown in the design mockups."""

from collections import defaultdict

import pytest

from app.seed import data as d
from app.seed.loader import compute_splits


def live(group: str) -> list[d.SeedExpense]:
    return [e for e in d.EXPENSES if e.group == group and not e.deleted]


def owes_me(group: str, me: str = "ansh") -> dict[str, int]:
    """Pairwise net with `me` in rupees: positive means that person owes me."""
    net: dict[str, int] = defaultdict(int)
    for e in live(group):
        for s in compute_splits(e):
            if s.user_id == e.payer:
                continue
            if e.payer == me:
                net[s.user_id] += s.share_minor
            elif s.user_id == me:
                net[e.payer] -= s.share_minor
    for st in d.SETTLEMENTS:
        if st.group == group and me in (st.from_user, st.to_user):
            other = st.to_user if st.from_user == me else st.from_user
            net[other] += st.amount * 100 if st.from_user == me else -st.amount * 100
    assert all(v % 100 == 0 for v in net.values()), "mockup balances are whole rupees"
    return {k: v // 100 for k, v in net.items()}


def test_every_expense_splits_exactly():
    for e in d.EXPENSES:
        assert sum(s.share_minor for s in compute_splits(e)) == e.amount * 100, e.key


def test_goa_balances_match_group_balances_mockup():
    # designs/GroupBalances: you owe Rahul ₹500 and Kabir ₹750;
    # Priya owes you ₹1,550, Aman ₹850; Vivek is square.
    assert owes_me("goa") == {"rahul": -500, "kabir": -750, "priya": 1550, "aman": 850, "vivek": 0}
    # designs/GroupList: "you are owed ₹1,150"
    assert sum(owes_me("goa").values()) == 1150


def test_flatmates_balance_matches_group_list_mockup():
    assert sum(owes_me("flat").values()) == 320


def test_group_totals_match_group_list_mockup():
    assert sum(e.amount for e in live("goa")) == 48260
    assert sum(e.amount for e in live("flat")) == 61480


def test_goa_analytics_match_group_analytics_mockup():
    paid, by_cat = defaultdict(int), defaultdict(int)
    for e in live("goa"):
        paid[e.payer] += e.amount
        by_cat[e.category] += e.amount
    assert paid == {
        "rahul": 14200,
        "ansh": 11480,
        "aman": 8900,
        "priya": 6130,
        "vivek": 4050,
        "kabir": 3500,
    }
    assert by_cat == {
        "travel": 16400,
        "food": 12860,
        "stay": 11200,
        "transport": 4300,
        "entertainment": 3500,
    }


@pytest.mark.parametrize(
    ("key", "shares"),
    [
        (
            "goa_dinner",
            {"ansh": 450, "rahul": 450, "aman": 450, "vivek": 450},
        ),  # Home: you owe ₹450
        ("goa_uber", {"ansh": 310, "rahul": 310}),  # Home: Rahul owes you ₹310
        ("goa_scooter", dict.fromkeys(d.GOA_ALL, 400)),  # GroupDetail: you owe ₹400
        ("goa_shack", dict.fromkeys(d.GOA_ALL, 360)),  # GroupDetail: your share ₹360
        ("flat_groceries", {"ansh": 780, "aman": 780, "vivek": 780}),  # Home: your share ₹780
        ("flat_electricity", {"ansh": 800, "aman": 1600, "vivek": 800}),  # Home: your share ₹800
    ],
)
def test_expenses_shown_in_mockups(key, shares):
    e = next(e for e in d.EXPENSES if e.key == key)
    assert {s.user_id: s.share_minor // 100 for s in compute_splits(e)} == shares


def test_personal_matches_personal_analytics_mockup():
    monthly, sep_by_cat = defaultdict(int), defaultdict(int)
    for p in d.PERSONAL:
        if p.type != "expense":
            continue
        monthly[p.day.month] += p.amount
        if p.day.month == 9:
            sep_by_cat[p.category] += p.amount
    assert dict(monthly) == {4: 24180, 5: 29640, 6: 27310, 7: 35920, 8: 30775, 9: 32450}
    assert sep_by_cat == {
        "rent": 18000,
        "food": 5820,
        "transport": 2940,
        "shopping": 2310,
        "entertainment": 1649,
        "bills": 1120,
        "health": 611,
    }
    assert round(monthly[9] / 23) == 1411 and round(monthly[8] / 31) == 993


def test_personal_history_days_match_mockup():
    days = defaultdict(int)
    for p in d.PERSONAL:
        if p.type == "expense" and p.day.month == 9 and p.day.day >= 19:
            days[p.day.day] += p.amount
    assert dict(days) == {23: 486, 21: 1240, 19: 1860}


def test_category_keys_exist():
    keys = {c.key for c in d.CATEGORIES}
    assert {e.category for e in d.EXPENSES} <= keys
    assert {p.category for p in d.PERSONAL} <= keys
