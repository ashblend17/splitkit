"""Pure date helpers for dashboards: period ranges, trend buckets and human labels."""

import calendar
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Literal

Period = Literal["week", "month", "year"]


@dataclass(frozen=True)
class Span:
    start: date
    end: date
    """Inclusive."""
    label: str

    @property
    def days(self) -> int:
        return (self.end - self.start).days + 1

    def contains(self, d: date) -> bool:
        return self.start <= d <= self.end


def add_months(d: date, months: int) -> date:
    m = d.month - 1 + months
    y, m = d.year + m // 12, m % 12 + 1
    return date(y, m, min(d.day, calendar.monthrange(y, m)[1]))


def month_start(d: date) -> date:
    return d.replace(day=1)


def month_end(d: date) -> date:
    return d.replace(day=calendar.monthrange(d.year, d.month)[1])


def range_label(start: date, end: date) -> str:
    """ "1 – 23 Sep", "28 Aug – 3 Sep", "12 Dec 2025 – 3 Jan 2026"."""
    if start == end:
        return f"{start.day} {start:%b}"
    if (start.year, start.month) == (end.year, end.month):
        return f"{start.day} – {end.day} {end:%b}"
    if start.year == end.year:
        return f"{start.day} {start:%b} – {end.day} {end:%b}"
    return f"{start.day} {start:%b} {start.year} – {end.day} {end:%b} {end.year}"


def current(period: Period, on: date) -> Span:
    """The period containing `on`, up to and including `on`."""
    if period == "week":
        start = on - timedelta(days=6)
        return Span(start, on, range_label(start, on))
    if period == "month":
        return Span(month_start(on), on, f"{on:%B}")
    return Span(date(on.year, 1, 1), on, str(on.year))


def previous(period: Period, on: date) -> Span:
    """The whole period before the current one ("August", "the week before", "2025")."""
    if period == "week":
        end = on - timedelta(days=7)
        return Span(end - timedelta(days=6), end, "The week before")
    if period == "month":
        last = month_start(on) - timedelta(days=1)
        return Span(month_start(last), last, f"{last:%B}")
    return Span(date(on.year - 1, 1, 1), date(on.year - 1, 12, 31), str(on.year - 1))


def trend_buckets(period: Period, on: date) -> list[Span]:
    """Bars for a spending trend: last 7 days, last 6 months, or last 12 months."""
    if period == "week":
        return [Span(d, d, f"{d:%a}") for d in (on - timedelta(days=i) for i in range(6, -1, -1))]
    count = 6 if period == "month" else 12
    months = [add_months(month_start(on), -i) for i in range(count - 1, -1, -1)]
    return [Span(m, min(month_end(m), on), f"{m:%b}") for m in months]


AVERAGE_COUNT = {"week": 8, "month": 6, "year": 12}
"""How many full weeks (Week) or months (Month, Year) a category average looks back over."""


def average_spans(period: Period, on: date) -> tuple[list[Span], Span]:
    """What a category average is worked out over, oldest first, and the week or month under
    way it's set against: on Week, the 8 weeks before the last 7 days; on Month and Year, the
    6 or 12 whole months before this one, against this month so far."""
    count = AVERAGE_COUNT[period]
    if period == "week":
        past = [
            Span(on - timedelta(days=7 * k + 6), on - timedelta(days=7 * k), "")
            for k in range(count, 0, -1)
        ]
        return past, Span(on - timedelta(days=6), on, "Last 7 days")
    start = month_start(on)
    months = [add_months(start, -k) for k in range(count, 0, -1)]
    return [Span(m, month_end(m), f"{m:%b}") for m in months], Span(start, on, f"{on:%B} so far")


def trend_label(period: Period) -> str:
    return {"week": "Last 7 days", "month": "Last 6 months", "year": "Last 12 months"}[period]


MAX_MONTH_BARS = 24


def bucket_kind(start: date, end: date) -> Literal["day", "week", "month", "year"]:
    """What one bar of adaptive_buckets covers for this span."""
    days = (end - start).days + 1
    if days <= 14:
        return "day"
    if days <= 92:
        return "week"
    months = (end.year - start.year) * 12 + end.month - start.month + 1
    return "month" if months <= MAX_MONTH_BARS else "year"


def adaptive_buckets(start: date, end: date) -> list[Span]:
    """Buckets for a group's whole history: days up to 2 weeks, weeks up to ~3 months,
    months up to two years, then whole years (so the chart never gets more than 24 bars)."""
    days = (end - start).days + 1
    kind = bucket_kind(start, end)
    if kind == "day":
        return [Span(d, d, f"{d.day}") for d in (start + timedelta(days=i) for i in range(days))]
    if kind == "week":
        spans, s = [], start
        while s <= end:
            e = min(s + timedelta(days=6), end)
            spans.append(Span(s, e, f"{s.day} {s:%b}"))
            s = e + timedelta(days=1)
        return spans
    if kind == "year":
        return [
            Span(max(date(y, 1, 1), start), min(date(y, 12, 31), end), str(y))
            for y in range(start.year, end.year + 1)
        ]
    # Across a new year, January's bar shows the year ("Nov, Dec, 2026, Feb").
    crosses = start.year != end.year
    spans, m = [], month_start(start)
    while m <= end:
        label = str(m.year) if crosses and m.month == 1 else f"{m:%b}"
        spans.append(Span(max(m, start), min(month_end(m), end), label))
        m = add_months(m, 1)
    return spans
