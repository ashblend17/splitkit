import uuid
from datetime import UTC, date, datetime
from zoneinfo import ZoneInfo

import pytest

from app.modules.tricount_sync import mapping, wire
from app.modules.tricount_sync.reconcile import LocalState, MapRow, RemoteState, plan_entries


@pytest.mark.parametrize("key", [*mapping.TO_TRICOUNT, "health", "income", "custom"])
def test_category_round_trips_settle_at_once(key):
    # Otherwise an entry would look changed on every pass and bounce between the apps.
    once = mapping.norm(key)
    assert mapping.norm(once) == once
    assert mapping.norm(mapping.from_tricount(mapping.TO_TRICOUNT.get(once, "OTHER"))) == once


@pytest.mark.parametrize("tc", list(mapping.FROM_TRICOUNT))
def test_every_tricount_category_lands_on_a_stable_key(tc):
    key = mapping.from_tricount(tc)
    assert mapping.norm(key) == mapping.norm(mapping.norm(key))


def _entry(amount, allocations, kind=wire.EXPENSE, payer="a"):
    return wire.Entry(
        id=1,
        uuid="u",
        kind=kind,
        description="x",
        amount_minor=amount,
        at=datetime(2026, 9, 1, 6, 30, tzinfo=UTC),
        day=date(2026, 9, 1),
        payer_uuid=payer,
        allocations=[wire.Allocation(*a) for a in allocations],
    )


def test_splits_come_back_as_the_simplest_method_that_fits():
    assert mapping.local_split(_entry(1000, [("a", 334), ("b", 333), ("c", 333)])).method == "equal"
    by_shares = mapping.local_split(_entry(1000, [("a", 500, 2), ("b", 250, 1), ("c", 250, 1)]))
    assert by_shares.method == "shares" and [v for _, v in by_shares.inputs] == [2, 1, 1]
    exact = mapping.local_split(_entry(1000, [("a", 700), ("b", 300)]))
    assert exact.method == "exact" and [int(v) for _, v in exact.inputs] == [700, 300]
    # Tricount's own rounding of a ratio split that would be rounded differently here: exact.
    odd = mapping.local_split(_entry(1000, [("a", 333, 1), ("b", 333, 1), ("c", 334, 1)]))
    assert odd.method == "exact"


def test_unsupported_entries_say_why():
    assert mapping.remote_canon(_entry(100, [("a", 100)], kind=wire.INCOME)).reason == "income"
    bad = mapping.remote_canon(_entry(100, [("a", 60), ("b", 30)]))
    assert bad.reason == "shares that don't add up to the total"
    two = mapping.remote_canon(_entry(100, [("b", 50), ("c", 50)], kind=wire.TRANSFER))
    assert two.reason == "a transfer to more than one person"


def test_wire_amounts_and_dates():
    assert wire.to_minor({"value": "-12.345", "currency": "EUR"}) == 1235
    assert wire.from_minor(1234, "EUR", negative=True) == {"value": "-12.34", "currency": "EUR"}
    assert wire.from_minor(0, "EUR", negative=True) == {"value": "0.00", "currency": "EUR"}


INDIA = ZoneInfo("Asia/Kolkata")


def test_tricount_times_are_utc_and_days_are_local_days():
    """As a real tricount showed (2026-10-24): its app dates an entry 10:20 UTC when it's made
    at 15:50 in India, and lists entries newest first by that."""
    at = wire.to_instant("2026-10-24 10:20:04.761000")
    assert at == datetime(2026, 10, 24, 10, 20, 4, 761000, tzinfo=UTC)
    assert wire.from_instant(at) == "2026-10-24 10:20:04.761000"
    assert wire.local_day(at, INDIA) == date(2026, 10, 24)
    # Past 18:30 UTC it's the next day in India.
    assert wire.local_day(wire.to_instant("2026-10-24 19:00:00.000000"), INDIA) == date(
        2026, 10, 25
    )
    with pytest.raises(wire.WireError):
        wire.to_instant("24/10/2026")


def test_an_entry_is_sent_for_the_moment_it_was_made():
    made = datetime(2026, 10, 24, 10, 20, tzinfo=UTC)  # 15:50 in India
    # Dated the day it was made: that moment, so it's first in Tricount.
    assert wire.entry_time(date(2026, 10, 24), INDIA, made) == made
    # Dated another day: that day, at the time of day it was made there.
    assert wire.entry_time(date(2026, 10, 20), INDIA, made) == datetime(
        2026, 10, 20, 10, 20, tzinfo=UTC
    )
    # Made at 01:00 in India, which is still the day before in UTC.
    late = datetime(2026, 10, 24, 19, 30, tzinfo=UTC)
    assert wire.entry_time(date(2026, 10, 25), INDIA, late) == late
    # An edit on the same day keeps Tricount's moment; moving the day keeps its time of day.
    kept = datetime(2026, 10, 24, 16, 45, 12, 5000, tzinfo=UTC)
    assert wire.entry_time(date(2026, 10, 24), INDIA, made, kept) == kept
    assert wire.entry_time(date(2026, 10, 22), INDIA, made, kept) == datetime(
        2026, 10, 22, 16, 45, 12, 5000, tzinfo=UTC
    )


# ---- the plan ----

E = ("expense", uuid.uuid4())
A = {"kind": "expense", "amount": 100}
B = {"kind": "expense", "amount": 200}
C = {"kind": "expense", "amount": 300}


def _plan(local, remote, base, remote_id=7, force=None):
    row = MapRow(uuid.uuid4(), E[0], E[1], remote_id, base, force=force)
    locals_ = {} if local is ... else {E: LocalState(local is None, local)}
    remotes = {} if remote is None else {7: RemoteState("r", remote)}
    actions = plan_entries([row], locals_, remotes, lambda k, g: "x").actions
    return [a.kind for a in actions]


@pytest.mark.parametrize(
    "local,remote,base,expected",
    [
        (A, A, A, []),
        (A, A, B, ["agree"]),
        (A, B, A, ["pull"]),
        (B, A, A, ["push"]),
        (B, C, A, ["conflict"]),
        (None, A, A, ["push_delete"]),
        (A, None, A, ["pull_delete"]),
        (None, B, A, ["conflict"]),
        (B, None, A, ["conflict"]),
        (None, None, A, ["forget"]),
    ],
)
def test_three_way_decisions(local, remote, base, expected):
    assert _plan(local, remote, base) == expected


def test_a_resolved_conflict_goes_the_chosen_way():
    assert _plan(B, C, A, force="push") == ["push"]
    assert _plan(B, C, A, force="pull") == ["pull"]
    assert _plan(None, C, A, force="pull") == ["pull"]
    assert _plan(B, None, A, force="push") == ["push"]


def test_new_entries_on_each_side():
    local = ("expense", uuid.uuid4())
    plan = plan_entries(
        [], {local: LocalState(False, A)}, {9: RemoteState("r9", B)}, lambda k, g: "mine"
    )
    assert sorted(a.kind for a in plan.actions) == ["pull", "push"]
    # Our own create, found again after a crash, pairs instead of duplicating.
    plan = plan_entries(
        [], {local: LocalState(False, A)}, {9: RemoteState("mine", A)}, lambda k, g: "mine"
    )
    assert [a.kind for a in plan.actions] == ["agree"]
