"""Data sources for dashboard cards: `source` name -> function. Pure functions over rows
already loaded by the service, so each one is easy to test. Add a card type by adding a
source here and a renderer in the app."""

from collections import defaultdict
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import date

from app.core.money import MINUS, format_minor
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
    """A dated amount with the labels a breakdown might group by. A refund's amount is
    negative, so it comes off what was spent."""

    day: date
    amount_minor: int
    category: str = "Uncategorised"
    person: str = ""
    account: str | None = None
    channel: str | None = None
    merchant: str | None = None
    """As the app names it (the entry's description when the merchant was first seen)."""
    kind: str | None = None
    """Its category's kind: need or want (income, or None, when it isn't sorted)."""


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
    """Your counted personal spending: expenses, and refunds as negative amounts."""
    income: list[Entry] = field(default_factory=list)
    """Your counted personal income."""
    group_shares: list[Entry] = field(default_factory=list)
    """Your shares of group expenses (all groups), in each expense's category."""
    count_group_share: bool = False
    """Whether your group shares are spending, as the app's cash flow counts them while
    `groupShareInCashFlow` is on: what you used, whoever paid."""
    group_expenses: list[Entry] = field(default_factory=list)
    """Every live expense in the group being viewed (person = payer's display name)."""
    my_share_in_group: int = 0
    member_count: int = 0

    @property
    def spending(self) -> list[Entry]:
        """What the spending cards add up: your personal spending, plus your group shares
        when they count."""
        return self.personal + self.group_shares if self.count_group_share else self.personal


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
    """Round to the nearest whole unit, for averages ("₹1,411 per day", not "₹1,410.86").
    Python's // floors, negatives too (refunds can take a total below zero); the app's port
    uses floorDiv to match."""
    return (minor + 50) // 100 * 100


def _rows(entries: list[Entry], span: Span | None, key: Callable[[Entry], str]) -> list[Row]:
    """Totals per key, largest first. Keys at zero or below (refunded in full, or more than
    was spent in the span) are left out: a breakdown has nothing to show for them."""
    totals: dict[str, int] = defaultdict(int)
    for e in entries:
        if span is None or span.contains(e.day):
            totals[key(e)] += e.amount_minor
    return [
        Row(label=k, value_minor=v)
        for k, v in sorted(totals.items(), key=lambda kv: (-kv[1], kv[0]))
        if v > 0
    ]


def _percent(part: int, whole: int) -> int:
    """part / whole in whole percent, rounded half away from zero (whole > 0). Integer maths,
    the same as the app's CashFlow.savingsRatePercent: (2·part·100 + sign·whole) ~/ (2·whole)."""
    sign = (part > 0) - (part < 0)
    q = 2 * part * 100 + sign * whole
    return sign * (abs(q) // (2 * whole))


def personal_monthly(ctx: Context) -> CardData:
    buckets = trend_buckets(ctx.period, ctx.on)
    totals = [_sum(ctx.spending, b) for b in buckets]
    # Refunds can take a bucket below zero: its bar shows nothing, the headline the real total.
    bars = [Bar(label=b.label, value_minor=max(t, 0)) for b, t in zip(buckets, totals, strict=True)]
    if bars:
        bars[-1].highlight = True
    return CardData(
        period_label=trend_label(ctx.period),
        headline=format_minor(totals[-1], ctx.currency) if totals else None,
        bars=bars,
    )


def personal_by_category(ctx: Context) -> CardData:
    span = current(ctx.period, ctx.on)
    return CardData(period_label=span.label, rows=_rows(ctx.spending, span, lambda e: e.category))


def scope_split(ctx: Context) -> CardData:
    span = current(ctx.period, ctx.on)
    return CardData(
        period_label=span.label,
        rows=[
            Row(label="Personal", value_minor=max(_sum(ctx.personal, span), 0)),
            Row(label="Group share", value_minor=_sum(ctx.group_shares, span)),
        ],
    )


def personal_daily_avg(ctx: Context) -> CardData:
    span, before = current(ctx.period, ctx.on), previous(ctx.period, ctx.on)
    now = _whole(_sum(ctx.spending, span) // span.days)
    then = _whole(_sum(ctx.spending, before) // before.days)
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
    """Spending per account or card, for entries that say which (a group share says none)."""
    span = current(ctx.period, ctx.on)
    named = [e for e in ctx.personal if e.account]
    return CardData(period_label=span.label, rows=_rows(named, span, lambda e: e.account or ""))


def personal_by_channel(ctx: Context) -> CardData:
    """Your own spending by how it was paid (a group share wasn't paid by you)."""
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


def personal_savings_rate(ctx: Context) -> CardData:
    """How much of the period's income you kept: income less spending (refunds come off it,
    group shares count when they do). The headline is the rate, or "—" without income; the stat
    is what was left."""
    span = current(ctx.period, ctx.on)
    income = _sum(ctx.income, span)
    net = income - _sum(ctx.spending, span)
    if income > 0:
        rate = _percent(net, income)
        headline = f"{MINUS if rate < 0 else ''}{abs(rate)}%"
        saved, of = format_minor(net, ctx.currency), format_minor(income, ctx.currency)
        note = f"{saved} saved of {of} income"
    else:
        headline, note = "—", f"No income in {span.label}"
    return CardData(
        period_label=span.label, headline=headline, stat=Stat(value_minor=net, note=note)
    )


def personal_need_want(ctx: Context) -> CardData:
    """Spending by its category's kind: Needs and Wants always, and "Not sorted" (Other, and
    categories you added) when there is some."""
    span = current(ctx.period, ctx.on)
    totals: dict[str | None, int] = defaultdict(int)
    for e in ctx.spending:
        if span.contains(e.day):
            totals[e.kind if e.kind in ("need", "want") else None] += e.amount_minor
    rows = [
        Row(label="Needs", value_minor=max(totals["need"], 0)),
        Row(label="Wants", value_minor=max(totals["want"], 0)),
    ]
    if totals[None] > 0:
        rows.append(Row(label="Not sorted", value_minor=totals[None]))
    return CardData(period_label=span.label, rows=rows)


SOURCES: dict[str, Callable[[Context], CardData]] = {
    "personal_monthly": personal_monthly,
    "personal_by_category": personal_by_category,
    "personal_by_account": personal_by_account,
    "personal_by_channel": personal_by_channel,
    "personal_top_merchants": personal_top_merchants,
    "scope_split": scope_split,
    "personal_daily_avg": personal_daily_avg,
    "personal_savings_rate": personal_savings_rate,
    "personal_need_want": personal_need_want,
    "group_total": group_total,
    "group_daily": group_daily,
    "group_by_category": group_by_category,
    "group_paid_by": group_paid_by,
}


def build(source: str, ctx: Context) -> CardData:
    fn = SOURCES.get(source)
    return fn(ctx) if fn else CardData(period_label="")
