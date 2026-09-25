"""Turns parsed rows into what an import would create, in one currency. Pure.

Amounts become integer minor units. Shares must add up to the amount exactly: when they
already do they're used as they are (through the exact split method); when Tricount's own
rounding left them a few paise off, or the row was converted from another currency, the total
is spread in proportion to the shares with the split engine's largest-remainder rounding
(ties to the earlier person, so the same file always gives the same split). Anything further
off is an error on that row, in the engine's words ("₹100 still needs to be allocated").
"""

from dataclasses import dataclass, field
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from app.core.money import SUPPORTED_CURRENCIES, format_minor
from app.modules.splits.engine import SplitInput, distribute, registry

from .parser import RawRow

EXPONENT = 2
"""Minor-unit exponent. Every supported currency (INR, USD, EUR) has two decimals."""


@dataclass
class Issue:
    level: str
    """error: the row is skipped · warning: imported, but worth a look"""
    code: str
    message: str


@dataclass
class PlannedRow:
    line: int
    title: str
    date: date | None
    kind: str
    """expense | transfer | income"""
    payer: str | None
    amount_minor: int
    currency: str
    original: str | None
    """The amount as written in the file, when it was converted ("$12.50")."""
    shares: list[tuple[str, int]]
    """(person, share in minor units). For a transfer: who received how much."""
    category: str | None
    issues: list[Issue] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not any(i.level == "error" for i in self.issues)


def _show(amount: Decimal, currency: str) -> str:
    if currency in SUPPORTED_CURRENCIES:
        minor = int((amount * 10**EXPONENT).to_integral_value(ROUND_HALF_UP))
        return format_minor(minor, currency)
    return f"{currency} {amount.normalize():f}"


def _minor(amount: Decimal) -> int:
    return int((amount.scaleb(EXPONENT)).to_integral_value(ROUND_HALF_UP))


def plan_row(raw: RawRow, currency: str) -> PlannedRow:
    issues = [Issue("error", "unreadable", p) for p in raw.problems]
    issues += [Issue("warning", "note", n) for n in raw.notes]

    def error(code: str, message: str) -> None:
        issues.append(Issue("error", code, message))

    title = raw.title or "Tricount expense"
    if not raw.title:
        issues.append(Issue("warning", "no_title", "No title in the file"))
    if raw.date is None and not raw.problems:
        error("no_date", "No date in the file")
    if raw.kind == "income":
        error("income", "Income isn't supported yet, so this row is skipped")

    payer = raw.payer
    if payer is None:
        paying = [name for name, v in raw.paid_by.items() if v != 0]
        if len(paying) == 1:
            payer = paying[0]
        elif len(paying) > 1:
            error("many_payers", "Paid by more than one person. Add it by hand after importing")
        else:
            error("no_payer", "No one is set as the payer")

    amount = raw.amount
    if amount is None and raw.paid_by:
        amount = sum(raw.paid_by.values(), Decimal(0))
    shares_in = {name: abs(v) for name, v in raw.shares.items() if v != 0}
    row = PlannedRow(
        raw.line, title, raw.date, raw.kind, payer, 0, currency, None, [], raw.category, issues
    )
    if amount is None:
        if not raw.problems:
            error("no_amount", "No amount in the file")
        return row
    # Tricount writes expenses as negative amounts in some exports; the sign carries no
    # meaning once the type is known.
    amount = abs(amount)

    source = raw.currency or currency
    if source == currency:
        total = amount
    elif raw.amount_default:
        total = abs(raw.amount_default)
        row.original = _show(amount, source)
        issues.append(
            Issue("warning", "converted", f"Converted from {row.original} at Tricount's rate")
        )
    else:
        error("currency", f"This one is in {source}, and Splitkit can't convert it to {currency}")
        return row

    total_minor = _minor(total)
    if total.scaleb(EXPONENT) != total_minor:
        issues.append(
            Issue("warning", "rounded", f"Rounded to {format_minor(total_minor, currency)}")
        )
    row.amount_minor = total_minor
    if total_minor <= 0:
        error("zero", "The amount is zero")
        return row

    if raw.kind == "transfer" and payer is not None:
        shares_in.pop(payer, None)
    if not shares_in:
        error("no_people", "Nobody is in this split" if raw.kind != "transfer" else "No recipient")
        return row
    if raw.kind == "transfer" and source == currency:
        # A transfer is what each recipient got; there's nothing to spread.
        total_minor = row.amount_minor = _minor(sum(shares_in.values(), Decimal(0)))

    names = list(shares_in)
    weights = [shares_in[n] for n in names]
    exact = [w.scaleb(EXPONENT) for w in weights]
    if source == currency and all(e == e.to_integral_value() for e in exact):
        inputs = [SplitInput(n, int(e)) for n, e in zip(names, exact, strict=True)]
        check = registry.get("exact").validate(total_minor, inputs, currency)
        if check.ok:
            row.shares = [
                (s.user_id, s.share_minor)
                for s in registry.get("exact").allocate(total_minor, inputs, currency)
            ]
            return row
        # A paisa or two per person is Tricount's own rounding; more is a real gap.
        if abs(check.remaining_minor) > len(names):
            error("split_mismatch", check.message)
            return row
    elif source == currency:
        remaining = total_minor - _minor(sum(weights, Decimal(0)))
        if abs(remaining) > len(names):
            check = registry.get("exact").validate(
                total_minor, [SplitInput("_", total_minor - remaining)], currency
            )
            error("split_mismatch", check.message)
            return row
    row.shares = list(zip(names, distribute(total_minor, weights), strict=True))
    return row


def plan(rows: list[RawRow], currency: str) -> list[PlannedRow]:
    return [plan_row(r, currency) for r in rows]
