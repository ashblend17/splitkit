import random

import pytest

from app.modules.balances.engine import (
    Flow,
    expense_flows,
    pairwise,
    positions,
    settlement_flow,
    simplify,
)


def test_expense_and_settlement_flows():
    flows = expense_flows("rahul", [("you", 450), ("rahul", 450), ("aman", 450)])
    assert flows == [Flow("you", "rahul", 450), Flow("aman", "rahul", 450)]
    assert settlement_flow("you", "rahul", 500) == Flow("rahul", "you", 500)


def test_pairwise_nets_settlements_against_expenses():
    flows = [
        *expense_flows("rahul", [("you", 1000), ("rahul", 1000)]),
        *expense_flows("you", [("you", 300), ("aman", 300)]),
        settlement_flow("you", "rahul", 400),
    ]
    assert pairwise("you", flows) == {"rahul": -600, "aman": 300}
    assert pairwise("rahul", flows) == {"you": 600}


def test_positions_sum_to_zero():
    flows = [*expense_flows("a", [("a", 5), ("b", 5), ("c", 5)]), settlement_flow("b", "a", 5)]
    nets = positions(flows)
    assert nets == {"a": 5, "b": 0, "c": -5}
    assert sum(nets.values()) == 0


def test_simplify_chain_collapses_to_one_payment():
    # a owes b 100, b owes c 100  ->  a pays c 100
    nets = positions([Flow("a", "b", 100), Flow("b", "c", 100)])
    assert simplify(nets) == [Flow("a", "c", 100)]


def test_simplify_is_deterministic_on_ties():
    nets = {"a": -50, "b": -50, "c": 50, "d": 50}
    assert simplify(nets) == [Flow("a", "c", 50), Flow("b", "d", 50)]


def test_simplify_rejects_unbalanced():
    with pytest.raises(ValueError):
        simplify({"a": 10})


@pytest.mark.parametrize("seed", range(50))
def test_simplify_settles_everyone(seed):
    rng = random.Random(seed)
    people = list("abcdefg")
    flows = [Flow(*rng.sample(people, 2), rng.randint(1, 10_000)) for _ in range(30)]
    nets = positions(flows)
    payments = simplify(nets)
    assert positions([*flows, *(Flow(p.creditor, p.debtor, p.amount) for p in payments)]) == {
        p: 0 for p in nets
    }
    assert len(payments) < len([v for v in nets.values() if v])
