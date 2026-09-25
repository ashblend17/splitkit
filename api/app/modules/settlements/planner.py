"""Pure planning for "settle up with a friend" across groups. No I/O.

Balances stay group-scoped: settling with a friend creates one settlement per group, so
every group's own balance is right. The rules:

- Full settle (the default): every group with a balance gets a settlement in that group's
  own direction, so all of them end at zero. Money actually changing hands is the net.
- Part payment: the amount pays down only the groups owed in the payment's direction,
  oldest group first. Groups owed the other way are left alone.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class GroupBalance:
    group_id: object
    net_minor: int
    """Positive: the friend owes you in this group. Negative: you owe them."""


@dataclass(frozen=True)
class PlannedPayment:
    group_id: object
    friend_pays: bool
    amount_minor: int


class SettleUpError(ValueError):
    pass


def plan_settle_up(
    balances: list[GroupBalance], amount_minor: int | None = None
) -> list[PlannedPayment]:
    """`balances` must be in paying-down order (oldest group first)."""
    owing = [b for b in balances if b.net_minor != 0]
    if not owing:
        raise SettleUpError("You're already all square")
    total = sum(b.net_minor for b in owing)

    if amount_minor is None or (total != 0 and amount_minor == abs(total)):
        return [PlannedPayment(b.group_id, b.net_minor > 0, abs(b.net_minor)) for b in owing]

    if total == 0:
        raise SettleUpError("Your balances cancel out; settle the full amount to clear them")
    if amount_minor <= 0:
        raise SettleUpError("Enter an amount above zero")
    if amount_minor > abs(total):
        raise SettleUpError("That's more than the balance between you")

    friend_pays = total > 0
    plan, remaining = [], amount_minor
    for b in owing:
        if (b.net_minor > 0) != friend_pays or remaining == 0:
            continue
        pay = min(remaining, abs(b.net_minor))
        plan.append(PlannedPayment(b.group_id, friend_pays, pay))
        remaining -= pay
    return plan
