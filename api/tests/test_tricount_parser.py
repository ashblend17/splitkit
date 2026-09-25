"""The Tricount parser and planner: formats, header aliases, locales and rounding. No DB."""

import uuid
from datetime import date
from decimal import Decimal

import pytest

from app.modules.import_tricount.matching import Candidate, match_people, suggest_category
from app.modules.import_tricount.parser import (
    ParseError,
    day_first,
    parse,
    parse_amount,
    parse_date,
)
from app.modules.import_tricount.plan import plan
from tests.tricount_files import goa_xlsx, read


def planned(content: bytes, name: str, currency: str = "INR"):
    return plan(parse(content, name).rows, currency)


def summary(rows):
    return [(r.line, r.date, r.kind, r.payer, r.amount_minor, r.shares, r.category) for r in rows]


# ---- formats ----


def test_goa_csv_reads_every_row():
    parsed = parse(read("goa_trip.csv"), "goa_trip.csv")
    assert parsed.people == ["John", "Rahul S", "Aman", "Priya", "Vivek", "Kabir M."]
    rows = plan(parsed.rows, "INR")
    assert len(rows) == 20
    train = rows[0]
    assert (train.title, train.date, train.payer, train.amount_minor) == (
        "Train to Goa",
        date(2026, 9, 12),
        "Aman",
        668000,
    )
    assert train.shares == [(p, 133600) for p in ["John", "Rahul S", "Aman", "Priya", "Vivek"]]
    pizza = next(r for r in rows if r.title == "Late-night pizza")
    assert dict(pizza.shares)["Kabir M."] == 12500
    assert [r.title for r in rows if not r.ok] == ["Souvenirs", "Villa deposit back"]
    transfer = rows[-1]
    assert (transfer.kind, transfer.payer, transfer.shares) == (
        "transfer",
        "Aman",
        [("Rahul S", 100000)],
    )


def test_semicolon_csv_and_xlsx_read_the_same_as_the_plain_csv():
    expected = summary(planned(read("goa_trip.csv"), "goa_trip.csv"))
    assert summary(planned(read("goa_trip_semicolon.csv"), "goa.csv")) == expected
    # The XLSX has the tricount's name and a blank row above the header, so lines shift by 2.
    xlsx = parse(goa_xlsx(), "goa.xlsx")
    assert xlsx.title == "Goa Trip"
    shifted = [(line - 2, *rest) for line, *rest in summary(plan(xlsx.rows, "INR"))]
    assert shifted == expected


def test_xlsx_is_detected_by_content_not_name():
    assert len(parse(goa_xlsx(title=None), "export").rows) == 20


def test_paid_by_paid_for_layout():
    rows = planned(read("paid_by_paid_for.csv"), "x.csv")
    assert (rows[0].payer, rows[0].amount_minor, rows[0].shares) == (
        "Rahul S",
        180000,
        [("Rahul S", 90000), ("John", 90000)],
    )
    assert (rows[1].payer, rows[1].amount_minor) == ("John", 62050)
    assert [i.code for i in rows[2].issues] == ["many_payers"]


def test_third_party_exporter_headers():
    """tricount-exporter's human CSV: Description / Who Paid / Total / Share <name>, with
    ratio and local columns that must not become people."""
    content = (
        b"Date;Time;Description;Who Paid;Total;Currency;Local Total;Share Giulia;Share Marco;"
        b"Local Share Giulia;Share Ratio Giulia;Allocation Type Marco;Transaction Type\n"
        b"2026-04-09;18:30;Dinner;Marco;-24.50;EUR;-24.50;-12.25;-12.25;-12.25;1;RATIO;NORMAL\n"
    )
    parsed = parse(content, "t.csv")
    assert parsed.people == ["Giulia", "Marco"]
    [row] = plan(parsed.rows, "EUR")
    # Tricount's API writes expenses as negative amounts; the sign means nothing here.
    assert (row.payer, row.amount_minor, row.shares) == (
        "Marco",
        2450,
        [("Giulia", 1225), ("Marco", 1225)],
    )


def test_tab_delimited_mdy_dates_and_a_totals_line():
    content = (
        b"title\tamount\tdate\tpaid by\tfor A\tfor B\n"
        b"Taxi\t10\t09/13/2026\tA\t5\t5\n"
        b"Total\t10\t\t\t\t\n"
    )
    [row] = planned(content, "t.tsv")
    assert row.date == date(2026, 9, 13)


@pytest.mark.parametrize(
    ("content", "message"),
    [
        (b"", "empty"),
        (b"name,email\nA,a@x\n", "couldn't find Tricount's columns"),
        (b"Title,Amount,Paid by\n", "no expenses"),
        (b"PK\x03\x04garbage", "couldn't be opened"),
    ],
)
def test_unreadable_files(content, message):
    with pytest.raises(ParseError, match=message):
        parse(content, "x.csv")


# ---- cells ----


@pytest.mark.parametrize(
    ("text", "comma", "expected"),
    [
        ("1234.56", None, "1234.56"),
        ("1,234.56", None, "1234.56"),
        ("1.234,56", None, "1234.56"),
        ("1 234,56", True, "1234.56"),
        ("1 234,56", True, "1234.56"),
        ("₹1,50,000", None, "150000"),
        ("€ 12,5", None, "12.5"),
        ("12,50", None, "12.50"),
        ("1,234", None, "1234"),
        ("1,234", True, "1.234"),
        ("1.234", True, "1234"),
        ("(12.50)", None, "-12.50"),
        ("-24.50", None, "-24.50"),
        ("1'234.50", None, "1234.50"),
        (1234.56, None, "1234.56"),
        (0.1, None, "0.1"),
        (7, None, "7"),
    ],
)
def test_amounts(text, comma, expected):
    assert parse_amount(text, comma) == Decimal(expected)


@pytest.mark.parametrize("text", ["abc", "--", "1.2.3,4,5"])
def test_bad_amounts(text):
    with pytest.raises(ValueError):
        parse_amount(text)


def test_blank_amount_is_none():
    assert parse_amount("  ") is None and parse_amount(None) is None


@pytest.mark.parametrize(
    ("text", "dmy", "expected"),
    [
        ("2026-09-12", True, date(2026, 9, 12)),
        ("2026-09-12 07:15:00", True, date(2026, 9, 12)),
        ("2026-04-09 18:30:00.000000", True, date(2026, 4, 9)),
        ("2026-09-12T07:15:00+05:30", True, date(2026, 9, 12)),
        ("2026/09/12", True, date(2026, 9, 12)),
        ("20260912", True, date(2026, 9, 12)),
        ("12/09/2026 07:15", True, date(2026, 9, 12)),
        ("12.09.2026", True, date(2026, 9, 12)),
        ("12-09-26", True, date(2026, 9, 12)),
        ("09/12/2026", False, date(2026, 9, 12)),
        ("12 Sep 2026", True, date(2026, 9, 12)),
        ("12 September 2026, 7:15 PM", True, date(2026, 9, 12)),
        ("Sep 12, 2026", True, date(2026, 9, 12)),
        (46277, True, date(2026, 9, 12)),
    ],
)
def test_dates(text, dmy, expected):
    assert parse_date(text, dmy) == expected


def test_bad_date_is_a_row_error():
    content = b"Title,Amount,Date,Paid by,For A\nTaxi,10,31/31/2026,A,10\n"
    [row] = planned(content, "t.csv")
    assert not row.ok
    assert "The date “31/31/2026” isn't one we can read" in row.issues[0].message


def test_date_order_is_decided_per_file():
    assert day_first(["01/02/2026", "13/02/2026"]) is True
    assert day_first(["01/02/2026", "02/13/2026"]) is False
    assert day_first(["01/02/2026"]) is True  # Tricount's default


# ---- rounding and splits ----


def _one(shares: str, amount: str = "100.00", currency: str = "INR", extra: str = ""):
    names = ["A", "B", "C"][: len(shares.split(","))]
    head = "Title,Amount,Currency,Amount in default currency,Date,Paid by," + ",".join(
        f"Impacted to {n}" for n in names
    )
    body = f"Row,{amount},{currency},{extra},2026-09-12,A,{shares}"
    [row] = planned(f"{head}\n{body}\n".encode(), "t.csv")
    return row


def test_exact_shares_are_kept():
    assert _one("50.00,30.00,20.00").shares == [("A", 5000), ("B", 3000), ("C", 2000)]


def test_tricount_rounding_is_spread_deterministically():
    # 33.33 × 3 is a paisa short; the extra paisa goes to the first person, every time.
    row = _one("33.33,33.33,33.33")
    assert row.ok and row.shares == [("A", 3334), ("B", 3333), ("C", 3333)]
    assert sum(s for _, s in row.shares) == row.amount_minor


def test_sub_paisa_shares_are_spread():
    row = _one("33.333,33.333,33.334")
    assert row.shares == [("A", 3333), ("B", 3333), ("C", 3334)]


def test_a_real_gap_is_an_error_in_human_copy():
    row = _one("50.00,30.00,10.00")
    assert not row.ok
    assert row.issues[0].message == "₹10 still needs to be allocated"
    over = _one("50.00,30.00,30.00")
    assert over.issues[0].message == "₹10 over the total — reduce someone"


def test_converted_rows_spread_the_converted_total():
    row = _one("10,10,10", amount="30", currency="USD", extra="2490.01")
    assert row.ok and row.original == "$30"
    assert row.shares == [("A", 83001), ("B", 83000), ("C", 83000)]
    assert [i.code for i in row.issues] == ["converted"]


def test_unconvertible_currency_is_an_error():
    row = _one("10,10,10", amount="30", currency="THB")
    assert not row.ok
    assert row.issues[0].message == "This one is in THB, and Splitkit can't convert it to INR"


def test_amount_with_too_many_decimals_is_rounded_with_a_warning():
    row = _one("50.005,50", amount="100.005")
    assert row.amount_minor == 10001
    assert "rounded" in [i.code for i in row.issues]


def test_nobody_in_split_and_no_payer():
    assert _one(",,").issues[-1].code == "no_people"
    [row] = planned(b"Title,Amount,Date,Paid by,For A\nTaxi,10,2026-09-12,,10\n", "t.csv")
    assert row.issues[0].code == "no_payer"


def test_unknown_type_imports_as_expense_with_a_note():
    content = b"Title,Amount,Date,Paid by,Type,For A\nTaxi,10,2026-09-12,A,Mystery,10\n"
    [row] = planned(content, "t.csv")
    assert row.ok and row.kind == "expense"
    assert "Mystery" in row.issues[0].message


# ---- matching ----


def test_people_matching():
    me, rahul, rahul_k, kabir = (uuid.uuid4() for _ in range(4))
    candidates = [
        Candidate(me, "John Doe", is_me=True),
        Candidate(rahul, "Rahul Sharma"),
        Candidate(rahul_k, "Rahul Kumar"),
        Candidate(kabir, "Kabir Mehta", placeholder_name="Kabir M."),
    ]
    m = match_people(["John", "Rahul S", "Rahul", "Kabir M.", "Zoe"], candidates)
    assert (m["John"].candidate.id, m["John"].state) == (me, "you")
    assert (m["Rahul S"].candidate.id, m["Rahul S"].state) == (rahul, "suggested")
    assert (m["Rahul"].candidate.id, m["Rahul"].state) == (rahul_k, "suggested")  # Sharma's taken
    assert (m["Kabir M."].candidate.id, m["Kabir M."].state) == (kabir, "matched")
    assert (m["Zoe"].candidate, m["Zoe"].state) == (None, "unmatched")
    # A look-alike that fits two people is left for the user.
    assert match_people(["Rahul"], candidates)["Rahul"].state == "unmatched"


def test_category_suggestions():
    available = {"food": "Food", "transport": "Transport", "stay": "Stay", "other": "Other"}
    assert suggest_category("Food & drinks", available) == "food"
    assert suggest_category("RESTAURANTS_AND_BARS", available) == "food"
    assert suggest_category("Accommodation", available) == "stay"
    assert suggest_category("transport", available) == "transport"
    assert suggest_category("Parking", available) is None
    assert suggest_category("Shopping", available) is None  # not available in this group
