import pytest

from app.modules.settlements.planner import (
    GroupBalance,
    PlannedPayment,
    SettleUpError,
    plan_settle_up,
)

GOA, FLAT, OFFICE = "goa", "flat", "office"


def test_full_settle_zeroes_every_group_in_its_own_direction():
    plan = plan_settle_up([GroupBalance(GOA, 85000), GroupBalance(FLAT, -32000)])
    assert plan == [PlannedPayment(GOA, True, 85000), PlannedPayment(FLAT, False, 32000)]


def test_full_settle_is_also_chosen_when_the_amount_equals_the_net():
    plan = plan_settle_up([GroupBalance(GOA, 85000), GroupBalance(FLAT, 32000)], 117000)
    assert plan == [PlannedPayment(GOA, True, 85000), PlannedPayment(FLAT, True, 32000)]


def test_part_payment_pays_oldest_groups_first_in_its_direction():
    balances = [GroupBalance(FLAT, 32000), GroupBalance(OFFICE, -10000), GroupBalance(GOA, 85000)]
    assert plan_settle_up(balances, 50000) == [
        PlannedPayment(FLAT, True, 32000),
        PlannedPayment(GOA, True, 18000),
    ]


def test_part_payment_when_you_owe():
    plan = plan_settle_up([GroupBalance(GOA, -50000), GroupBalance(FLAT, -20000)], 60000)
    assert plan == [PlannedPayment(GOA, False, 50000), PlannedPayment(FLAT, False, 10000)]


def test_zero_balance_groups_are_skipped():
    assert plan_settle_up([GroupBalance(GOA, 0), GroupBalance(FLAT, 100)]) == [
        PlannedPayment(FLAT, True, 100)
    ]


def test_balances_that_cancel_out_can_still_be_cleared():
    plan = plan_settle_up([GroupBalance(GOA, 500), GroupBalance(FLAT, -500)])
    assert plan == [PlannedPayment(GOA, True, 500), PlannedPayment(FLAT, False, 500)]
    with pytest.raises(SettleUpError):
        plan_settle_up([GroupBalance(GOA, 500), GroupBalance(FLAT, -500)], 100)


@pytest.mark.parametrize(
    ("balances", "amount", "message"),
    [
        ([GroupBalance(GOA, 0)], None, "You're already all square"),
        ([GroupBalance(GOA, 500)], 600, "That's more than the balance between you"),
        ([GroupBalance(GOA, 500)], 0, "Enter an amount above zero"),
    ],
)
def test_errors(balances, amount, message):
    with pytest.raises(SettleUpError, match=message):
        plan_settle_up(balances, amount)
