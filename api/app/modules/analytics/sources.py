"""Data sources for dashboard cards: `source` name -> function. Pure functions over rows
already loaded by the service, so each one is easy to test. Add a card type by adding a
source here and a renderer in the app."""

from collections import defaultdict
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import date

from app.core.money import format_minor
from app.modules.analytics.periods import (
    Period,
    Span,
    adaptive_buckets,
    bucket_kind,
    current,
    previous,
    range_label,
    trend_buckets,
    trend_label,
)
from app.modules.analytics.schemas import ChartBar as Bar
from app.modules.analytics.schemas import ChartRow as Row
from app.modules.analytics.schemas import ChartStat as Stat


@dataclass(frozen=True)
class Entry:
    """A dated amount with the labels a breakdown might group by."""

    day: date
    amount_minor: int
    category: str = "Uncategorised"
    person: str = ""
    account: str | None = None
    channel: str | None = None
    merchant: str | None = None
    """As the app names it (the entry's description when the merchant was first seen)."""


CHANNELS = {
    "upi": "UPI",
    "card": "Card",
    "bank": "Bank transfer",
    "atm": "ATM",
    "cash": "Cash",
    "other": "Other",
}
"""Payment modes, as the app labels them (core/copy/copy.dart channelLabels)."""


@dataclass
class Context:
    period: Period
    on: date
    currency: str
    personal: list[Entry] = field(default_factory=list)
    """Your personal expenses."""
    group_shares: list[Entry] = field(default_factory=list)
    """Your shares of group expenses (all groups)."""
    group_expenses: list[Entry] = field(default_factory=list)
    """Every live expense in the group being viewed (person = payer's display name)."""
    my_share_in_group: int = 0
    member_count: int = 0


@dataclass
class CardData:
    period_label: str
    headline: str | None = None
    bars: list[Bar] = field(default_factory=list)
    rows: list[Row] = field(default_factory=list)
    stat: Stat | None = None


def _sum(entries: list[Entry], span: Span) -> int:
    return sum(e.amount_minor for e in entries if span.contains(e.day))


def _whole(minor: int) -> int:
    """Round to the nearest whole unit, for averages ("₹1,411 per day", not "₹1,410.86")."""
    return (minor + 50) // 100 * 100


def _rows(entries: list[Entry], span: Span | None, key: Callable[[Entry], str]) -> list[Row]:
    totals: dict[str, int] = defaultdict(int)
    for e in entries:
        if span is None or span.contains(e.day):
            totals[key(e)] += e.amount_minor
    return [
        Row(label=k, value_minor=v)
        for k, v in sorted(totals.items(), key=lambda kv: (-kv[1], kv[0]))
    ]


def personal_monthly(ctx: Context) -> CardData:
    buckets = trend_buckets(ctx.period, ctx.on)
    bars = [Bar(label=b.label, value_minor=_sum(ctx.personal, b)) for b in buckets]
    if bars:
        bars[-1].highlight = True
    return CardData(
        period_label=trend_label(ctx.period),
        headline=format_minor(bars[-1].value_minor, ctx.currency) if bars else None,
        bars=bars,
    )


def personal_by_category(ctx: Context) -> CardData:
    span = current(ctx.period, ctx.on)
    return CardData(period_label=span.label, rows=_rows(ctx.personal, span, lambda e: e.category))


def scope_split(ctx: Context) -> CardData:
    span = current(ctx.period, ctx.on)
    return CardData(
        period_label=span.label,
        rows=[
            Row(label="Personal", value_minor=_sum(ctx.personal, span)),
            Row(label="Group share", value_minor=_sum(ctx.group_shares, span)),
        ],
    )


def personal_daily_avg(ctx: Context) -> CardData:
    span, before = current(ctx.period, ctx.on), previous(ctx.period, ctx.on)
    now = _whole(_sum(ctx.personal, span) // span.days)
    then = _whole(_sum(ctx.personal, before) // before.days)
    return CardData(
        period_label=range_label(span.start, span.end),
        stat=Stat(
            value_minor=now,
            note=f"{before.label} averaged {format_minor(then, ctx.currency)} per day",
        ),
    )


def _group_span(ctx: Context) -> Span | None:
    if not ctx.group_expenses:
        return None
    days = [e.day for e in ctx.group_expenses]
    return Span(min(days), max(days), range_label(min(days), max(days)))


def group_total(ctx: Context) -> CardData:
    total = sum(e.amount_minor for e in ctx.group_expenses)
    per_person = _whole(total // ctx.member_count) if ctx.member_count else 0
    share = format_minor(ctx.my_share_in_group, ctx.currency)
    note = f"{format_minor(per_person, ctx.currency)} per person · your share {share}"
    return CardData(period_label="All time", stat=Stat(value_minor=total, note=note))


def group_daily(ctx: Context) -> CardData:
    span = _group_span(ctx)
    if span is None:
        return CardData(period_label="No expenses yet")
    buckets = adaptive_buckets(span.start, span.end)
    bars = [Bar(label=b.label, value_minor=_sum(ctx.group_expenses, b)) for b in buckets]
    peak = max(bars, key=lambda b: b.value_minor)
    peak.highlight = True
    peak_span = buckets[bars.index(peak)]
    # "on 12 Sep", "in the week of 29 Jul", "in July", "in 2025": as long as one bar.
    kind = bucket_kind(span.start, span.end)
    first = peak_span.start
    when = {
        "day": f"on {first.day} {first:%b}",
        "week": f"in the week of {first.day} {first:%b}",
        "month": f"in {first:%B}" + (f" {first.year}" if span.start.year != span.end.year else ""),
        "year": f"in {first.year}",
    }[kind]
    return CardData(
        period_label=span.label,
        headline=f"Peak {format_minor(peak.value_minor, ctx.currency)} {when}",
        bars=bars,
    )


def group_by_category(ctx: Context) -> CardData:
    return CardData(
        period_label="All time", rows=_rows(ctx.group_expenses, None, lambda e: e.category)
    )


def group_paid_by(ctx: Context) -> CardData:
    return CardData(
        period_label="All time", rows=_rows(ctx.group_expenses, None, lambda e: e.person)
    )


def personal_by_account(ctx: Context) -> CardData:
    """Spending per account or card, for entries that say which."""
    span = current(ctx.period, ctx.on)
    named = [e for e in ctx.personal if e.account]
    return CardData(period_label=span.label, rows=_rows(named, span, lambda e: e.account or ""))


def personal_by_channel(ctx: Context) -> CardData:
    """Spending by how it was paid."""
    span = current(ctx.period, ctx.on)
    rows = _rows(ctx.personal, span, lambda e: CHANNELS.get(e.channel or "", "Not said"))
    return CardData(period_label=span.label, rows=rows)


def personal_top_merchants(ctx: Context) -> CardData:
    """The five merchants you spent most with (entries from bank SMS name them)."""
    span = current(ctx.period, ctx.on)
    named = [e for e in ctx.personal if e.merchant]
    return CardData(
        period_label=span.label, rows=_rows(named, span, lambda e: e.merchant or "")[:5]
    )


SOURCES: dict[str, Callable[[Context], CardData]] = {
    "personal_monthly": personal_monthly,
    "personal_by_category": personal_by_category,
    "personal_by_account": personal_by_account,
    "personal_by_channel": personal_by_channel,
    "personal_top_merchants": personal_top_merchants,
    "scope_split": scope_split,
    "personal_daily_avg": personal_daily_avg,
    "group_total": group_total,
    "group_daily": group_daily,
    "group_by_category": group_by_category,
    "group_paid_by": group_paid_by,
}


def build(source: str, ctx: Context) -> CardData:
    fn = SOURCES.get(source)
    return fn(ctx) if fn else CardData(period_label="")
