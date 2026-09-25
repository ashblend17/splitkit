"""Pure balance maths. Balances are always derived: expense splits minus settlements.

A Flow means "debtor owes creditor amount" (minor units). An expense produces one flow per
participant other than the payer. A settlement from A to B produces the flow "B owes A",
which cancels A's debt to B.
"""

from collections import defaultdict
from collections.abc import Hashable, Iterable
from dataclasses import dataclass


@dataclass(frozen=True)
class Flow[P: Hashable]:
    debtor: P
    creditor: P
    amount: int


def expense_flows[P: Hashable](payer: P, shares: Iterable[tuple[P, int]]) -> list[Flow[P]]:
    return [Flow(user, payer, share) for user, share in shares if user != payer and share]


def settlement_flow[P: Hashable](from_user: P, to_user: P, amount: int) -> Flow[P]:
    return Flow(to_user, from_user, amount)


def pairwise[P: Hashable](me: P, flows: Iterable[Flow[P]]) -> dict[P, int]:
    """Net with each other person. Positive: they owe me. Negative: I owe them."""
    net: dict[P, int] = defaultdict(int)
    for f in flows:
        if f.creditor == me:
            net[f.debtor] += f.amount
        elif f.debtor == me:
            net[f.creditor] -= f.amount
    return dict(net)


def positions[P: Hashable](flows: Iterable[Flow[P]]) -> dict[P, int]:
    """Each person's overall position. Positive: owed money overall. Sums to zero."""
    net: dict[P, int] = defaultdict(int)
    for f in flows:
        net[f.creditor] += f.amount
        net[f.debtor] -= f.amount
    return dict(net)


def simplify[P: Hashable](nets: dict[P, int]) -> list[Flow[P]]:
    """Fewest-ish payments that settle everyone: repeatedly pay the largest creditor from the
    largest debtor. Deterministic: ties are broken by str(person). Returns flows meaning
    "debtor should pay creditor amount"."""
    if sum(nets.values()) != 0:
        raise ValueError("positions must sum to zero")
    debtors = [[-v, str(p), p] for p, v in nets.items() if v < 0]
    creditors = [[v, str(p), p] for p, v in nets.items() if v > 0]
    payments: list[Flow[P]] = []
    while debtors and creditors:
        debtors.sort(key=lambda x: (-x[0], x[1]))
        creditors.sort(key=lambda x: (-x[0], x[1]))
        d, c = debtors[0], creditors[0]
        amount = min(d[0], c[0])
        payments.append(Flow(d[2], c[2], amount))
        d[0] -= amount
        c[0] -= amount
        debtors = [x for x in debtors if x[0]]
        creditors = [x for x in creditors if x[0]]
    return payments
