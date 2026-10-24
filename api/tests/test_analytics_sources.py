"""The personal sources' rules, which the app's port (core/finance/insights.dart) mirrors:
refunds come off spending, bars and rows never go below zero, and the savings rate rounds half
away from zero."""

from datetime import date

import pytest

from app.modules.analytics.sources import SOURCES, Context, Entry, _percent, build

ON = date(2026, 9, 23)


def ctx(personal=(), income=(), shares=(), period="month") -> Context:
    return Context(
        period=period,
        on=ON,
        currency="INR",
        personal=list(personal),
        income=list(income),
        group_shares=list(shares),
    )


def rows(card) -> list[tuple[str, int]]:
    return [(r.label, r.value_minor) for r in card.rows]


@pytest.mark.parametrize(
    ("part", "whole", "percent"),
    [
        (5_255_000, 8_500_000, 62),
        (4, 800, 1),  # 0.5% rounds up
        (-4, 800, -1),  # and -0.5% down
        (3, 800, 0),
        (-3, 800, 0),
        (0, 100, 0),
        (2, 3, 67),
        (-2, 3, -67),
        (-12_500, 100_000, -13),
    ],
)
def test_percent_rounds_half_away_from_zero(part, whole, percent):
    assert _percent(part, whole) == percent


def test_savings_rate():
    spent = [Entry(date(2026, 9, 2), 1_125_00, "Food", kind="need")]
    salary = [Entry(date(2026, 9, 1), 1_000_00), Entry(date(2026, 8, 1), 9_000_00)]
    card = build("personal_savings_rate", ctx(spent, salary))
    assert (card.period_label, card.headline) == ("September", "−13%")
    assert (card.stat.value_minor, card.stat.note) == (-125_00, "−₹125 saved of ₹1,000 income")

    card = build("personal_savings_rate", ctx(spent))
    assert (card.headline, card.stat.value_minor, card.stat.note) == (
        "—",
        -1_125_00,
        "No income in September",
    )


def test_refunds_never_take_a_bar_or_a_row_below_zero():
    personal = [
        Entry(date(2026, 9, 5), 200_00, "Food", kind="need"),
        Entry(date(2026, 9, 6), -600_00, "Shopping", kind="want"),  # refund of an August spend
        Entry(date(2026, 9, 7), 50_00, "Other"),
        Entry(date(2026, 8, 20), 600_00, "Shopping", kind="want"),
    ]
    c = ctx(personal, shares=[Entry(date(2026, 9, 10), 75_00)])
    trend = build("personal_monthly", c)
    assert [b.value_minor for b in trend.bars][-2:] == [600_00, 0]
    assert trend.headline == "−₹350"  # the real total
    assert rows(build("personal_by_category", c)) == [("Food", 200_00), ("Other", 50_00)]
    assert rows(build("scope_split", c)) == [("Personal", 0), ("Group share", 75_00)]
    assert rows(build("personal_need_want", c)) == [
        ("Needs", 200_00),
        ("Wants", 0),
        ("Not sorted", 50_00),
    ]
    # Group share is never spending here (the app adds it when its setting says so).
    assert build("personal_savings_rate", c).stat.value_minor == 350_00


def test_needs_and_wants_always_show_and_not_sorted_only_when_there_is_some():
    assert rows(build("personal_need_want", ctx())) == [("Needs", 0), ("Wants", 0)]
    personal = [
        Entry(date(2026, 9, 3), 100_00, "Food", kind="need"),
        Entry(date(2026, 9, 4), 40_00, "Other"),
        Entry(date(2026, 9, 5), -40_00, "Other"),
        Entry(date(2026, 9, 6), 10_00, "Salary back", kind="income"),
    ]
    assert rows(build("personal_need_want", ctx(personal))) == [
        ("Needs", 100_00),
        ("Wants", 0),
        ("Not sorted", 10_00),
    ]


def averages(card) -> list[tuple[str, int, int]]:
    return [(r.label, r.average_minor, r.now_minor) for r in card.averages.rows]


def test_category_averages_set_a_usual_month_against_this_one():
    personal = [
        Entry(date(2026, 3, 10), 600_00, "Food"),  # before the six months: not counted
        Entry(date(2026, 5, 4), 300_00, "Food"),
        Entry(date(2026, 7, 9), 900_00, "Food"),
        Entry(date(2026, 8, 1), 1_200_00, "Transport"),
        Entry(date(2026, 8, 2), -200_00, "Transport"),  # a refund comes off
        Entry(date(2026, 9, 5), 450_00, "Food"),
        Entry(date(2026, 9, 6), 80_00, "Shopping"),  # new this month
    ]
    card = build("personal_by_category", ctx(personal))
    a = card.averages
    assert (a.label, a.now_label, a.unit) == ("Average of 6 months", "September so far", "month")
    # Mar–Aug: Food ₹1,800 over 6 months; Transport ₹1,000, so ₹166.67, a whole ₹167.
    assert averages(card) == [
        ("Food", 300_00, 450_00),
        ("Transport", 167_00, 0),
        ("Shopping", 0, 80_00),
    ]
    assert rows(card) == [("Food", 450_00), ("Shopping", 80_00)]  # the totals don't change


def test_category_averages_start_from_your_first_spending():
    personal = [Entry(date(2026, 8, 20), 500_00, "Food"), Entry(date(2026, 9, 1), 100_00, "Food")]
    card = build("personal_by_category", ctx(personal))
    assert card.averages.label == "Average of 1 month"
    assert averages(card) == [("Food", 500_00, 100_00)]
    # Nothing before this month: no average yet.
    card = build("personal_by_category", ctx([Entry(date(2026, 9, 1), 100_00, "Food")]))
    assert (card.averages.label, card.averages.rows) == ("No full month yet", [])


def test_category_averages_on_week_and_year():
    personal = [
        Entry(date(2026, 9, 12), 700_00, "Food"),  # the week of 10 – 16 Sep
        Entry(date(2026, 9, 20), 100_00, "Food"),  # the last 7 days
        Entry(date(2026, 7, 30), 100_00, "Food"),  # the week of 30 Jul – 5 Aug
    ]
    card = build("personal_by_category", ctx(personal, period="week"))
    assert (card.averages.label, card.averages.now_label, card.averages.unit) == (
        "Average of 7 weeks",
        "Last 7 days",
        "week",
    )
    assert averages(card) == [("Food", 114_00, 100_00)]  # ₹800 over 7 weeks
    # Year: the months from July (the first spending) to August, against September so far.
    card = build("personal_by_category", ctx(personal, period="year"))
    assert (card.averages.label, card.averages.unit) == ("Average of 2 months", "month")
    assert averages(card) == [("Food", 50_00, 800_00)]
    # Group shares count when they're spending, as on the other cards.
    shared = ctx(shares=[Entry(date(2026, 8, 3), 600_00, "Travel")])
    assert build("personal_by_category", shared).averages.rows == []
    shared.count_group_share = True
    assert averages(build("personal_by_category", shared)) == [("Travel", 600_00, 0)]


def test_layouts_can_use_the_new_sources():
    assert {"personal_savings_rate", "personal_need_want"} <= SOURCES.keys()
    assert build("made_up", ctx()).period_label == ""
