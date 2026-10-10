"""One comparable form for an entry, whichever side it comes from. Pure.

The sync decides who changed what by comparing three versions of an entry: Splitkit's,
Tricount's, and the one both last agreed on (TricountEntry.base). They are compared in the
form below, which keeps only what both apps can hold:

    {"kind": "expense", "description": "Dinner", "amount": 180000, "date": "2026-09-23",
     "payer": "<member uuid>", "shares": [["<member uuid>", 45000], ...], "category": "food"}
    {"kind": "payment", "amount": 50000, "date": "2026-09-22", "from": "<uuid>",
     "to": "<uuid>", "note": "Cash for the cab"}

People are Tricount member uuids. Shares leave out zeros and are sorted, so the same split
always looks the same. Categories go through `norm`, so a Tricount category Splitkit maps
coarsely ("GROCERIES" is "food") doesn't look like a change on every pass.
"""

import uuid
from collections.abc import Callable
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from app.core.schemas import MAX_AMOUNT_MINOR
from app.modules.splits.engine import SplitInput, registry
from app.modules.tricount_sync import wire

# ---- categories ----

TO_TRICOUNT: dict[str | None, str] = {
    "food": "FOOD_AND_DRINK",
    "transport": "TRANSPORT",
    "shopping": "SHOPPING",
    "entertainment": "ENTERTAINMENT",
    "travel": "TRAVEL",
    "stay": "TRAVEL",
    "rent": "RENT_AND_UTILITIES",
    "bills": "RENT_AND_UTILITIES",
    "other": "OTHER",
    None: "UNCATEGORIZED",
}
"""Splitkit's group categories (system keys) -> Tricount's. Your own categories go as OTHER
with their label as Tricount's custom category."""

FROM_TRICOUNT: dict[str, str | None] = {
    "FOOD_AND_DRINK": "food",
    "GROCERIES": "food",
    "TRANSPORT": "transport",
    "SHOPPING": "shopping",
    "ENTERTAINMENT": "entertainment",
    "TRAVEL": "travel",
    "RENT_AND_UTILITIES": "rent",
    "INSURANCE": "bills",
    "HEALTHCARE": "other",  # Splitkit's health is for personal entries only
    "OTHER": "other",
    "GENERAL": None,
    "UNCATEGORIZED": None,
}


def norm(key: str | None) -> str | None:
    """A category key as both apps can keep it: "stay" and "travel" are both TRAVEL."""
    return FROM_TRICOUNT.get(TO_TRICOUNT.get(key, "OTHER"))


def from_tricount(category: str | None) -> str | None:
    return FROM_TRICOUNT.get(category or "UNCATEGORIZED", "other")


# ---- ids ----

NAMESPACE = uuid.UUID("5d1c3c1e-4f0a-4d39-9a63-7f1e4b7c2a10")


def remote_uuid(entity_id: uuid.UUID, generation: int) -> str:
    """The id a Splitkit entry is created with in Tricount. Creating with the same id twice
    returns the first entry, so a retried push never makes a duplicate."""
    return str(uuid.uuid5(NAMESPACE, f"splitkit:{entity_id}:{generation}"))


def local_id(registry_id: int, entry: wire.Entry) -> uuid.UUID:
    """The id a Tricount entry gets in Splitkit, so a retried pull never makes a duplicate."""
    return uuid.uuid5(NAMESPACE, f"tricount:{registry_id}:{entry.uuid or entry.id}")


def member_uuid(group_id: uuid.UUID, user_id: uuid.UUID) -> str:
    """The member uuid a Splitkit person gets when they're added to the tricount."""
    return str(uuid.uuid5(NAMESPACE, f"member:{group_id}:{user_id}"))


# ---- comparable forms ----

Canon = dict[str, Any]

DESCRIPTION_MAX, NOTE_MAX = 200, 500
"""Splitkit's limits. Longer Tricount titles are cut on both sides, so they still match."""


def _shares(pairs: list[tuple[str, int]]) -> list[list[Any]]:
    return sorted([who, amount] for who, amount in pairs if amount)


def expense_canon(
    *,
    description: str,
    amount_minor: int,
    day: str,
    payer: str,
    shares: list[tuple[str, int]],
    category: str | None,
) -> Canon:
    return {
        "kind": "expense",
        "description": description.strip()[:DESCRIPTION_MAX] or "Tricount expense",
        "amount": amount_minor,
        "date": day,
        "payer": payer,
        "shares": _shares(shares),
        "category": norm(category),
    }


TRANSFER_TITLES = {"reimbursement", "money transfer", "payment", "transfer", "remboursement"}
"""Tricount's default titles for a payment. They mean "no note"."""


def payment_canon(*, amount_minor: int, day: str, frm: str, to: str, note: str | None) -> Canon:
    note = (note or "").strip()[:NOTE_MAX]
    if note.casefold() in TRANSFER_TITLES:
        note = ""
    return {
        "kind": "payment",
        "amount": amount_minor,
        "date": day,
        "from": frm,
        "to": to,
        "note": note,
    }


@dataclass
class Unsupported:
    """A Tricount entry Splitkit can't hold, and why (shown on the link as a warning)."""

    reason: str


def remote_canon(e: wire.Entry) -> Canon | Unsupported:
    if e.amount_minor > MAX_AMOUNT_MINOR:
        return Unsupported("an amount over Splitkit's limit")
    if e.amount_minor <= 0:
        return Unsupported("an entry of zero")
    if e.kind == wire.EXPENSE:
        if not any(a.amount_minor for a in e.allocations):
            return Unsupported("an expense nobody shares")
        people = [a.member_uuid for a in e.allocations]
        if sum(a.amount_minor for a in e.allocations) != e.amount_minor or len(set(people)) < len(
            people
        ):
            return Unsupported("shares that don't add up to the total")
        return expense_canon(
            description=e.description,
            amount_minor=e.amount_minor,
            day=e.day.isoformat(),
            payer=e.payer_uuid,
            shares=[(a.member_uuid, a.amount_minor) for a in e.allocations],
            category=from_tricount(e.category),
        )
    if e.kind == wire.TRANSFER:
        receivers = [a for a in e.allocations if a.amount_minor and a.member_uuid != e.payer_uuid]
        if len(receivers) != 1:
            return Unsupported("a transfer to more than one person")
        return payment_canon(
            amount_minor=e.amount_minor,
            day=e.day.isoformat(),
            frm=e.payer_uuid,
            to=receivers[0].member_uuid,
            note=e.description,
        )
    if e.kind == wire.INCOME:
        return Unsupported("income")
    return Unsupported(f"a {e.kind.lower()} entry")


# ---- Tricount -> Splitkit splits ----


@dataclass
class LocalSplit:
    method: str
    inputs: list[tuple[str, Decimal | None]]
    """(member uuid, value) in Tricount's order; value is None for an equal split."""


def _allocates_to(method: str, total: int, inputs: list[SplitInput], want: list[int]) -> bool:
    try:
        shares = registry.get(method).allocate(total, inputs)
    except (ValueError, TypeError, ArithmeticError):
        return False
    return [s.share_minor for s in shares] == want


def local_split(e: wire.Entry) -> LocalSplit:
    """How Splitkit should store a Tricount expense: by shares or equally when that gives
    exactly Tricount's amounts, else as exact amounts."""
    people = [a for a in e.allocations if a.amount_minor or a.ratio]
    amounts = [a.amount_minor for a in people]
    if people and all(a.ratio is not None and a.ratio > 0 for a in people):
        inputs = [SplitInput(a.member_uuid, Decimal(a.ratio)) for a in people]
        if _allocates_to("shares", e.amount_minor, inputs, amounts):
            return LocalSplit("shares", [(a.member_uuid, Decimal(a.ratio)) for a in people])
    paying = [a for a in people if a.amount_minor]
    equal = [SplitInput(a.member_uuid) for a in paying]
    if paying and _allocates_to("equal", e.amount_minor, equal, [a.amount_minor for a in paying]):
        return LocalSplit("equal", [(a.member_uuid, None) for a in paying])
    return LocalSplit("exact", [(a.member_uuid, Decimal(a.amount_minor)) for a in paying])


# ---- Splitkit -> Tricount bodies ----


def expense_allocations(
    method: str, splits: list[tuple[str, int, Decimal | None]]
) -> list[wire.Allocation]:
    """(member uuid, share, input value) in Splitkit's order -> Tricount allocations. A split
    by whole-number shares stays a split by shares in Tricount."""
    ratios = method == "shares" and all(
        v is not None and v == v.to_integral_value() and v > 0 for _, s, v in splits if s
    )
    return [
        wire.Allocation(who, share, int(value) if ratios and value is not None else None)
        for who, share, value in splits
        if share
    ]


def payment_allocations(frm: str, to: str, amount_minor: int) -> list[wire.Allocation]:
    # Tricount's shape for a transfer: the receiver takes the amount, the payer zero.
    return [wire.Allocation(to, amount_minor), wire.Allocation(frm, 0)]


def keep_remote_category(local_key: str | None, remote: wire.Entry | None) -> bool:
    """Leave Tricount's own category when it says the same thing ("GROCERIES" for food), so
    an unrelated edit in Splitkit doesn't flatten it."""
    return remote is not None and norm(local_key) == from_tricount(remote.category)


Lookup = Callable[[uuid.UUID], str | None]
"""A Splitkit person -> their Tricount member uuid (None if not in the tricount yet)."""
