"""Sample data from the design mockups (Goa Trip, Flatmates, Ansh's personal finances).

Pure data: no DB access. `tests/test_seed_data.py` checks that the balances and totals this
data produces match the numbers shown in the mockups.

Amounts are in rupees here for readability and converted to paise on load.
Expense inputs are (person, value): value is None for equal splits, rupees for exact,
a percentage for percent, and a share count for shares.
"""

from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta, timezone

IST = timezone(timedelta(hours=5, minutes=30))
DEV_PASSWORD = "splitkit-dev"
"""Every seeded account uses this password. Development only."""


def at(d: date, hh: int = 12, mm: int = 0) -> datetime:
    return datetime.combine(d, time(hh, mm), IST)


def sep(day: int) -> date:
    return date(2026, 9, day)


@dataclass(frozen=True)
class SeedUser:
    key: str
    name: str
    email: str
    role: str = "user"


@dataclass(frozen=True)
class SeedCategory:
    key: str
    label: str
    icon: str
    scope: str
    sort: int


@dataclass(frozen=True)
class SeedMember:
    user: str
    role: str = "member"
    joined: datetime | None = None
    placeholder_name: str | None = None


@dataclass(frozen=True)
class SeedGroup:
    key: str
    name: str
    icon: str
    created_by: str
    created: datetime
    members: list[SeedMember]


@dataclass(frozen=True)
class SeedExpense:
    key: str
    group: str
    description: str
    day: date
    category: str
    payer: str
    amount: int
    method: str
    inputs: list[tuple[str, int | None]]
    created: datetime | None = None
    """Defaults to noon on `day` (or the import time for imported expenses)."""
    notes: str | None = None
    imported: bool = False
    created_by: str | None = None
    """Defaults to the payer (or the importing user for imported expenses)."""
    acting_admin: str | None = None
    deleted: datetime | None = None


@dataclass(frozen=True)
class SeedSettlement:
    key: str
    group: str
    from_user: str
    to_user: str
    amount: int
    day: date
    method: str
    created: datetime
    note: str | None = None


@dataclass(frozen=True)
class SeedPersonal:
    user: str
    type: str
    amount: int
    category: str
    day: date
    description: str
    notes: str | None = None
    created: datetime | None = None


@dataclass(frozen=True)
class SeedAnalytics:
    scope: str
    position: int
    type: str
    title: str
    period: str
    source: str
    params: dict = field(default_factory=dict)


USERS = [
    SeedUser("ansh", "Ansh C", "ansh.c@cyware.com", role="admin"),
    SeedUser("rahul", "Rahul Sharma", "rahul.sharma@example.com"),
    SeedUser("aman", "Aman Verma", "aman.v@example.com"),
    SeedUser("priya", "Priya Nair", "priya.nair@example.com"),
    SeedUser("vivek", "Vivek Iyer", "vivek.iyer@example.com"),
    SeedUser("kabir", "Kabir Mehta", "kabir.m@example.com"),
]

# `icon` is a glyph name from designs/Icon.dc.html.
CATEGORIES = [
    SeedCategory("food",          "Food",      "food",          "all",      10),
    SeedCategory("transport",     "Transport", "transport",     "all",      20),
    SeedCategory("shopping",      "Shopping",  "shopping",      "all",      30),
    SeedCategory("entertainment", "Fun",       "entertainment", "all",      40),
    SeedCategory("travel",        "Travel",    "travel",        "group",    50),
    SeedCategory("stay",          "Stay",      "rent",          "group",    60),
    SeedCategory("rent",          "Rent",      "rent",          "all",      70),
    SeedCategory("bills",         "Bills",     "bills",         "all",      80),
    SeedCategory("health",        "Health",    "health",        "personal", 90),
    SeedCategory("income",        "Income",    "income",        "personal", 100),
    SeedCategory("other",         "Other",     "other",         "all",      999),
]

GROUPS = [
    SeedGroup("goa", "Goa Trip", "travel", "ansh", at(sep(10), 20, 0), [
        SeedMember("ansh", "owner"),
        SeedMember("rahul"),
        SeedMember("aman"),
        SeedMember("priya"),
        SeedMember("vivek"),
        # Came in through the Tricount import as "Kabir M.", then joined via invite link.
        SeedMember("kabir", joined=at(sep(21), 10, 5), placeholder_name="Kabir M."),
    ]),
    SeedGroup("flat", "Flatmates", "rent", "ansh", at(date(2026, 6, 28), 19, 0), [
        SeedMember("ansh", "owner"),
        SeedMember("aman"),
        SeedMember("vivek"),
    ]),
]

GOA_FIVE = ["ansh", "rahul", "aman", "priya", "vivek"]
GOA_ALL = [*GOA_FIVE, "kabir"]
FLAT_ALL = ["ansh", "aman", "vivek"]


def eq(people: list[str]) -> list[tuple[str, None]]:
    return [(p, None) for p in people]


IMPORT_BATCH = {
    "group": "goa",
    "file_name": "tricount-goa-trip.xlsx",
    "created_by": "ansh",
    "created": at(sep(22), 10, 0),
}

E = SeedExpense
EXPENSES = [
    # ---- Goa Trip: imported from Tricount (12–20 Sep) ----
    E("goa_train",       "goa", "Train to Goa",               sep(12), "travel",        "aman",  6680,  "equal", eq(GOA_FIVE), imported=True, notes="Kabir came separately"),
    E("goa_villa",       "goa", "Villa in Anjuna",            sep(12), "stay",          "rahul", 11200, "equal", eq(GOA_FIVE), imported=True),
    E("goa_cab",         "goa", "Cab from Madgaon station",   sep(12), "transport",     "priya", 1280,  "equal", eq(GOA_FIVE), imported=True),
    E("goa_breakfast",   "goa", "Breakfast at Artjuna",       sep(13), "food",          "rahul", 1200,  "equal", eq(GOA_ALL),  imported=True),
    E("goa_parasailing", "goa", "Parasailing",                sep(13), "entertainment", "kabir", 3500,  "equal", eq(["ansh", "rahul", "priya", "kabir"]), imported=True),
    E("goa_groceries",   "goa", "Groceries for the villa",    sep(14), "food",          "vivek", 2400,  "equal", eq(GOA_ALL),  imported=True),
    E("goa_thali",       "goa", "Fish thali at Ritz Classic", sep(15), "food",          "priya", 2450,  "equal", eq(GOA_FIVE), imported=True),
    E("goa_chai",        "goa", "Chai and bhajiyas",          sep(16), "food",          "aman",  60,    "equal", eq(GOA_ALL),  imported=True),
    E("goa_drinks",      "goa", "Drinks at Curlies",          sep(16), "food",          "vivek", 1650,  "equal", eq(GOA_ALL),  imported=True),
    E("goa_pizza",       "goa", "Late-night pizza",           sep(17), "food",          "ansh",  1140,  "exact",
      [("ansh", 203), ("rahul", 203), ("aman", 203), ("priya", 203), ("vivek", 203), ("kabir", 125)],
      imported=True, notes="Kabir only had one slice"),
    E("goa_shack",       "goa", "Beach shack lunch",          sep(18), "food",          "aman",  2160,  "equal", eq(GOA_ALL),  imported=True),
    # Category corrected by Ansh in admin mode while viewing as Priya (see AUDIT below).
    E("goa_scooter",     "goa", "Scooter rentals",            sep(19), "transport",     "priya", 2400,  "equal", eq(GOA_ALL),  imported=True, acting_admin="ansh"),
    E("goa_tickets",     "goa", "Return tickets",             sep(20), "travel",        "ansh",  9720,  "exact",
      [("ansh", 3025), ("rahul", 1377), ("aman", 2353), ("priya", 2493), ("vivek", 472)],
      imported=True, notes="Fares depended on when each person booked. Vivek took the overnight bus."),
    # ---- Goa Trip: added in Splitkit ----
    E("goa_uber",        "goa", "Uber to airport",            sep(22), "transport",     "ansh",  620,   "equal", eq(["ansh", "rahul"]), created=at(sep(22), 7, 5)),
    E("goa_dinner",      "goa", "Dinner at Thalassa",         sep(23), "food",          "rahul", 1800,  "equal", eq(["ansh", "rahul", "aman", "vivek"]), created=at(sep(23), 21, 40)),

    # ---- Flatmates ----
    E("flat_rent_jul",    "flat", "Rent — July",                date(2026, 7, 1),  "rent",     "ansh",  15000, "equal", eq(FLAT_ALL)),
    E("flat_wifi",        "flat", "Wi-Fi (Jul–Sep)",            date(2026, 7, 2),  "bills",    "vivek", 2340,  "equal", eq(FLAT_ALL)),
    E("flat_cook_jul",    "flat", "Cook — July",                date(2026, 7, 31), "other",    "aman",  2400,  "equal", eq(FLAT_ALL)),
    E("flat_rent_aug",    "flat", "Rent — August",              date(2026, 8, 1),  "rent",     "aman",  15000, "equal", eq(FLAT_ALL)),
    E("flat_cooker",      "flat", "Pressure cooker",            date(2026, 8, 10), "shopping", "ansh",  680,   "equal", eq(["ansh", "aman"]), notes="Vivek has his own"),
    E("flat_cook_aug",    "flat", "Cook — August",              date(2026, 8, 31), "other",    "vivek", 2400,  "equal", eq(FLAT_ALL)),
    E("flat_rent_sep",    "flat", "Rent — September",           sep(1),            "rent",     "vivek", 15000, "equal", eq(FLAT_ALL)),
    E("flat_cook_sep",    "flat", "Cook — September (advance)", sep(5),            "other",    "ansh",  2400,  "equal", eq(FLAT_ALL)),
    E("flat_purifier",    "flat", "Water purifier service",     sep(14),           "bills",    "aman",  720,   "equal", eq(["aman", "vivek"])),
    E("flat_electricity", "flat", "Electricity bill",           sep(21),           "bills",    "aman",  3200,  "shares",
      [("ansh", 1), ("aman", 2), ("vivek", 1)], created=at(sep(21), 11, 20), notes="Aman's room has the AC, so 2 shares"),
    E("flat_water",       "flat", "Water cans",                 sep(21),           "other",    "aman",  450,   "equal", eq(FLAT_ALL),
      created=at(sep(21), 9, 0), deleted=at(sep(21), 18, 30)),
    E("flat_groceries",   "flat", "Groceries",                  sep(23),           "shopping", "ansh",  2340,  "equal", eq(FLAT_ALL), created=at(sep(23), 18, 15)),
]

SETTLEMENTS = [
    SeedSettlement("goa_pay_rahul", "goa", "ansh", "rahul", 500, sep(22), "upi", at(sep(22), 6, 50)),
]

ADMIN_SESSION = {
    "admin": "ansh",
    "target": "priya",
    "mode": "edit",
    "started": at(sep(23), 21, 10),
    "ended": at(sep(23), 21, 20),
}

# Mirrors the activity table in designs/AdminDashboard.dc.html.
# (at, actor, acting_as, action, entity, entity key, diff). actor None = the importer.
AUDIT = [
    (at(sep(21), 10, 5),       "kabir", None,    "member.join",       "group",        "goa",            {"via": "invite_link"}),
    (at(sep(21), 18, 30),      "aman",  None,    "expense.delete",    "expense",      "flat_water",     {}),
    (IMPORT_BATCH["created"],  None,    None,    "import.complete",   "import_batch", "import",         {"expenses": 13, "flagged": 3}),
    (at(sep(22), 6, 50),       "ansh",  None,    "settlement.create", "settlement",   "goa_pay_rahul",  {"amount_minor": 50000}),
    (at(sep(23), 18, 15),      "ansh",  None,    "expense.create",    "expense",      "flat_groceries", {"amount_minor": 234000}),
    (at(sep(23), 21, 15),      "ansh",  "priya", "expense.update",    "expense",      "goa_scooter",    {"category": {"from": "travel", "to": "transport"}}),
    (at(sep(23), 21, 40),      "rahul", None,    "expense.create",    "expense",      "goa_dinner",     {"amount_minor": 180000}),
]

# ---- Ansh's personal finances ----


def _month(m: int, items: list[tuple[str, int, int, str]]) -> list[SeedPersonal]:
    return [
        SeedPersonal("ansh", "income", 85000, "income", date(2026, m, 1), "Salary", "Bank transfer"),
        SeedPersonal("ansh", "expense", 18000, "rent", date(2026, m, 1), "House rent", "Bank transfer"),
        *(SeedPersonal("ansh", "expense", amt, cat, date(2026, m, d), desc) for cat, amt, d, desc in items),
    ]


# Monthly spend matches PersonalAnalytics: Apr 24,180 · May 29,640 · Jun 27,310 · Jul 35,920 · Aug 30,775
PERSONAL = [
    *_month(4, [("food", 3240, 12, "Groceries"), ("transport", 1450, 9, "Cabs and metro"), ("bills", 1120, 5, "Phone and internet"),
                ("shopping", 370, 20, "Notebook and pens")]),
    *_month(5, [("food", 4120, 14, "Groceries"), ("transport", 1980, 8, "Cabs and metro"), ("bills", 1120, 5, "Phone and internet"),
                ("shopping", 3120, 18, "Running shoes"), ("entertainment", 1300, 24, "Concert tickets")]),
    *_month(6, [("food", 3890, 11, "Groceries"), ("transport", 2210, 16, "Cabs and metro"), ("bills", 1120, 5, "Phone and internet"),
                ("health", 890, 21, "Dentist"), ("entertainment", 1200, 27, "Movies")]),
    *_month(7, [("food", 4630, 13, "Groceries"), ("transport", 2480, 9, "Cabs and metro"), ("bills", 1120, 5, "Phone and internet"),
                ("shopping", 8490, 19, "New headphones"), ("entertainment", 1200, 26, "Movies")]),
    *_month(8, [("food", 5210, 12, "Groceries"), ("transport", 2365, 7, "Cabs and metro"), ("bills", 1120, 5, "Phone and internet"),
                ("shopping", 2580, 15, "Kurta for Diwali"), ("health", 1500, 22, "Annual health check")]),
    # September 1–23: 32,450 spent. Rent 18,000 · Food 5,820 · Transport 2,940 · Shopping 2,310 ·
    # Fun 1,649 · Bills 1,120 · Health 611. The named items are the ones in Personal / PersonalHistory.
    *_month(9, [("transport", 380, 2, "Uber to office"), ("bills", 719, 2, "Mobile recharge"), ("food", 642, 3, "Zomato order"),
                ("shopping", 699, 4, "Phone case"), ("entertainment", 649, 5, "Movie tickets"), ("food", 1212, 6, "Vegetables and fruit"),
                ("health", 611, 6, "Pharmacy"), ("transport", 1660, 7, "Petrol"), ("shopping", 1611, 8, "Decathlon shorts"),
                ("bills", 401, 9, "Netflix"), ("food", 1280, 10, "Office lunch"), ("entertainment", 1000, 11, "Bowling")]),
    SeedPersonal("ansh", "expense", 1860, "food",      sep(19), "Weekend groceries", "UPI", at(sep(19), 11, 30)),
    SeedPersonal("ansh", "expense", 500,  "transport", sep(21), "Metro card top-up", None,  at(sep(21), 9, 10)),
    SeedPersonal("ansh", "expense", 340,  "food",      sep(21), "Blue Tokai coffee", "UPI", at(sep(21), 10, 45)),
    SeedPersonal("ansh", "expense", 400,  "transport", sep(21), "Rapido ride",       "UPI", at(sep(21), 19, 5)),
    SeedPersonal("ansh", "expense", 486,  "food",      sep(23), "Swiggy order",      "UPI", at(sep(23), 13, 10)),
]

# Default dashboards (owner_id NULL). Titles from PersonalAnalytics / GroupAnalytics.
A = SeedAnalytics
ANALYTICS = [
    A("personal", 1, "spending_trend",       "Monthly spending",     "last_6_months", "personal_monthly",     {"bucket": "month"}),
    A("personal", 2, "spending_by_category", "Spending by category", "this_month",    "personal_by_category"),
    A("personal", 3, "personal_vs_group",    "Personal vs group",    "this_month",    "scope_split"),
    A("personal", 4, "average_daily",        "Average per day",      "this_month",    "personal_daily_avg",   {"compare": "previous_month"}),
    A("group",    1, "total_spend",          "Total group spending", "all_time",      "group_total"),
    A("group",    2, "spending_trend",       "Spending per day",     "all_time",      "group_daily",          {"bucket": "day"}),
    A("group",    3, "spending_by_category", "By category",          "all_time",      "group_by_category"),
    A("group",    4, "paid_by_member",       "Who paid",             "all_time",      "group_paid_by"),
]
