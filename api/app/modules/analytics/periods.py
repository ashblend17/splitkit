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


def trend_label(period: Period) -> str:
    return {"week": "Last 7 days", "month": "Last 6 months", "year": "Last 12 months"}[period]


def adaptive_buckets(start: date, end: date) -> list[Span]:
    """Buckets for a group's whole history: days up to 2 weeks, weeks up to ~3 months,
    months beyond that."""
    days = (end - start).days + 1
    if days <= 14:
        return [Span(d, d, f"{d.day}") for d in (start + timedelta(days=i) for i in range(days))]
    if days <= 92:
        spans, s = [], start
        while s <= end:
            e = min(s + timedelta(days=6), end)
            spans.append(Span(s, e, f"{s.day} {s:%b}"))
            s = e + timedelta(days=1)
        return spans
    spans, m = [], month_start(start)
    while m <= end:
        spans.append(Span(max(m, start), min(month_end(m), end), f"{m:%b}"))
        m = add_months(m, 1)
    return spans
