"""Tricount's JSON, read into plain dataclasses and written back. Pure.

Every quirk of the API lives here: responses are {"Response": [{"Key": {...}}, ...]}; list
items are wrapped in one-key objects ({"RegistryMembershipNonUser": {...}}); expenses carry
negative amounts; responses nest members ("membership_owned") where requests send flat uuids
("membership_uuid_owner"); timestamps look like "2026-03-02 12:00:00.000000" and are UTC.

An entry's "date" is a moment, not a day: Tricount's app writes when the entry was made, in UTC,
lists entries newest first by it and shows it in the phone's zone. The app has only the day, in
the server's zone (TRICOUNT_TIME_ZONE): `local_day` turns one into the other and `entry_time`
picks the moment to send.
"""

from dataclasses import dataclass, field
from datetime import UTC, date, datetime, tzinfo
from decimal import ROUND_HALF_UP, Decimal
from typing import Any

EXPONENT = 2
"""Minor units per major unit, as a power of ten. Every currency the app supports has two."""

EXPENSE = "NORMAL"
INCOME = "INCOME"
TRANSFER = "BALANCE"
"""Tricount's kinds of entry ("type_transaction"): an expense, money received on the group's
behalf, and a payment from one member to another (a "reimbursement")."""

TIME_FORMAT = "%Y-%m-%d %H:%M:%S.%f"


class WireError(ValueError):
    """Tricount answered with something this module can't read."""


@dataclass
class Member:
    uuid: str
    id: int | None
    name: str
    active: bool = True


@dataclass
class Allocation:
    member_uuid: str
    amount_minor: int
    """Always positive (or zero)."""
    ratio: int | None = None
    """Set for "RATIO" allocations (split by shares)."""


@dataclass
class Entry:
    id: int
    uuid: str
    kind: str
    description: str
    amount_minor: int
    """In the tricount's currency, always positive."""
    at: datetime
    """When it happened, as Tricount keeps it (UTC)."""
    day: date
    """That moment's day here's zone."""
    payer_uuid: str
    allocations: list[Allocation]
    category: str | None = None
    category_custom: str | None = None
    attachment_ids: list[int] = field(default_factory=list)
    foreign: dict[str, Any] | None = None
    """amount_local and exchange_rate, for an entry paid in another currency."""


@dataclass
class Registry:
    id: int
    uuid: str
    title: str
    currency: str
    status: str
    public_token: str
    members: list[Member]
    """Active and deleted alike (see Member.active)."""
    entries: list[Entry]
    active_member_uuid: str | None = None
    """Whom this device counts as in this tricount: who Tricount says added what it sends."""

    def active_members(self) -> list[Member]:
        return [m for m in self.members if m.active]


# ---- amounts and times ----


def to_minor(amount: dict[str, Any] | None) -> int:
    """{"value": "-12.34", "currency": "EUR"} -> 1234."""
    if not amount or amount.get("value") in (None, ""):
        return 0
    try:
        value = Decimal(str(amount["value"]))
    except ArithmeticError:
        raise WireError(f"Not an amount: {amount!r}") from None
    if not value.is_finite():
        raise WireError(f"Not an amount: {amount!r}")
    return int(abs(value).scaleb(EXPONENT).to_integral_value(ROUND_HALF_UP))


def from_minor(minor: int, currency: str, negative: bool = False) -> dict[str, str]:
    value = Decimal(minor).scaleb(-EXPONENT)
    if negative and minor:
        value = -value
    return {"value": f"{value:.{EXPONENT}f}", "currency": currency}


def to_instant(text: str | None) -> datetime:
    """ "2026-03-02 12:00:00.000000" (UTC) -> an aware datetime."""
    if not text:
        raise WireError("An entry has no date")
    try:
        return datetime.fromisoformat(text.replace(" ", "T")).replace(tzinfo=UTC)
    except ValueError:
        raise WireError(f"Not a date: {text!r}") from None


def from_instant(at: datetime) -> str:
    return at.astimezone(UTC).strftime(TIME_FORMAT)


def local_day(at: datetime, zone: tzinfo) -> date:
    return at.astimezone(zone).date()


def entry_time(day: date, zone: tzinfo, made: datetime, kept: datetime | None = None) -> datetime:
    """The moment to send for an entry the app dates `day` (in `zone`). `made` is when it was
    made here; `kept` is the moment Tricount has for it now, if it has it.

    An edit that keeps the day keeps Tricount's moment, so the entry doesn't move. Otherwise it
    goes on `day` at the time of day it was made (or had in Tricount): one made today is the
    moment it was made, so it comes first in Tricount, as one added in its app would."""
    if kept is not None and local_day(kept, zone) == day:
        return kept
    clock = (kept or made).astimezone(zone)
    return datetime.combine(day, clock.time(), tzinfo=zone).astimezone(UTC)


# ---- responses ----


def items(body: dict[str, Any], key: str) -> list[dict[str, Any]]:
    """The `key` objects of a {"Response": [{key: {...}}, ...]} reply."""
    response = body.get("Response")
    if not isinstance(response, list):
        raise WireError("Tricount's reply has no Response list")
    return [r[key] for r in response if isinstance(r, dict) and isinstance(r.get(key), dict)]


def first(body: dict[str, Any], key: str) -> dict[str, Any]:
    found = items(body, key)
    if not found:
        raise WireError(f"Tricount's reply has no {key}")
    return found[0]


def _unwrap(wrapper: Any) -> dict[str, Any]:
    """{"RegistryMembershipNonUser": {...}} -> {...}."""
    if isinstance(wrapper, dict) and len(wrapper) == 1:
        inner = next(iter(wrapper.values()))
        if isinstance(inner, dict):
            return inner
    return wrapper if isinstance(wrapper, dict) else {}


def _member(raw: dict[str, Any]) -> Member:
    alias = raw.get("alias") or {}
    name = alias.get("display_name") or (alias.get("pointer") or {}).get("name") or "Someone"
    status = raw.get("status") or "ACTIVE"
    return Member(uuid=raw["uuid"], id=raw.get("id"), name=name.strip(), active=status == "ACTIVE")


def _entry(raw: dict[str, Any], zone: tzinfo) -> Entry:
    payer = raw.get("membership_uuid_owner") or _unwrap(raw.get("membership_owned")).get("uuid")
    allocations = []
    for a in raw.get("allocations") or []:
        who = a.get("membership_uuid") or _unwrap(a.get("membership")).get("uuid")
        if not who:
            raise WireError(f"Entry {raw.get('id')} has an allocation with no member")
        ratio = a.get("share_ratio") if a.get("type") == "RATIO" else None
        allocations.append(Allocation(who, to_minor(a.get("amount")), ratio))
    if not payer:
        raise WireError(f"Entry {raw.get('id')} has no payer")
    at = to_instant(raw.get("date"))
    foreign = None
    if raw.get("amount_local"):
        foreign = {"amount_local": raw["amount_local"], "exchange_rate": raw.get("exchange_rate")}
    return Entry(
        id=int(raw["id"]),
        uuid=raw.get("uuid") or "",
        kind=raw.get("type_transaction") or EXPENSE,
        description=(raw.get("description") or "").strip(),
        amount_minor=to_minor(raw.get("amount")),
        at=at,
        day=local_day(at, zone),
        payer_uuid=payer,
        allocations=allocations,
        category=raw.get("category") or None,
        category_custom=raw.get("category_custom") or None,
        attachment_ids=[int(a["id"]) for a in raw.get("attachment") or [] if "id" in a],
        foreign=foreign,
    )


def registry(raw: dict[str, Any], zone: tzinfo) -> Registry:
    """A Registry object (the inside of {"Registry": {...}}). Entries' days are in `zone`."""
    try:
        return Registry(
            id=int(raw["id"]),
            uuid=raw.get("uuid") or "",
            title=(raw.get("title") or "").strip(),
            currency=raw.get("currency") or "",
            status=raw.get("status") or "READ_WRITE",
            public_token=raw.get("public_identifier_token") or "",
            members=[_member(_unwrap(m)) for m in raw.get("memberships") or []],
            entries=[
                _entry(_unwrap(e), zone)
                for e in raw.get("all_registry_entry") or []
                if (_unwrap(e).get("status") or "ACTIVE") == "ACTIVE"
            ],
            active_member_uuid=raw.get("membership_uuid_active") or None,
        )
    except (KeyError, TypeError) as e:
        raise WireError(f"Tricount sent a tricount this module can't read ({e})") from None


# ---- requests ----


def entry_body(
    *,
    uuid: str,
    kind: str,
    description: str,
    amount_minor: int,
    currency: str,
    at: datetime,
    payer_uuid: str,
    allocations: list[Allocation],
    category: str | None,
    category_custom: str | None = None,
    attachment_ids: list[int] | None = None,
) -> dict[str, Any]:
    """A registry-entry request. Updates replace the whole entry, so callers carry over what
    the app doesn't track (attachments, a custom category). Tricount's own "type" field is
    left out: it's refused as superfluous."""
    negative = kind == EXPENSE
    body: dict[str, Any] = {
        "uuid": uuid,
        "description": description,
        "amount": from_minor(amount_minor, currency, negative),
        "membership_uuid_owner": payer_uuid,
        "allocations": [
            {
                "membership_uuid": a.member_uuid,
                "amount": from_minor(a.amount_minor, currency, negative),
                "type": "RATIO" if a.ratio is not None else "AMOUNT",
                **({"share_ratio": a.ratio} if a.ratio is not None else {}),
            }
            for a in allocations
        ],
        "type_transaction": kind,
        "status": "ACTIVE",
        "date": from_instant(at),
    }
    if category_custom:
        body["category"], body["category_custom"] = "OTHER", category_custom
    elif category:
        body["category"] = category
    if attachment_ids:
        body["attachment"] = [{"id": i} for i in attachment_ids]
    return body


def membership(uuid: str, name: str, active: bool = True) -> dict[str, Any]:
    """A member in the request form (flat alias), for PUT /registry/{id}."""
    return {
        "uuid": uuid,
        "status": "ACTIVE" if active else "DELETED",
        "auto_add_card_transaction": "",
        "setting": None,
        "alias": {"type": "UUID", "value": uuid, "name": name},
    }
