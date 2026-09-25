import random
from decimal import Decimal

import pytest

from app.modules.splits.engine import (
    SplitInput,
    SplitMethod,
    SplitRegistry,
    UnknownSplitMethod,
    distribute,
    registry,
)
from app.modules.splits.engine.methods import EqualSplit


def test_registry_has_the_four_methods_in_selector_order():
    assert registry.keys() == ["equal", "exact", "percent", "shares"]
    assert [m.label for m in registry.all()] == ["Equal", "Exact", "Percent", "Shares"]
    assert [m.symbol for m in registry.all()] == ["=", "₹", "%", "×"]
    assert all(isinstance(m, SplitMethod) for m in registry.all())


def test_registry_rejects_unknown_and_duplicate_keys():
    with pytest.raises(UnknownSplitMethod):
        registry.get("itemised")
    fresh = SplitRegistry()
    fresh.register(EqualSplit())
    with pytest.raises(ValueError):
        fresh.register(EqualSplit())


def test_registry_accepts_plugins():
    class HalfToFirst:
        key, label, symbol, hint = "half", "Half", "½", "First person pays half."

        def validate(self, total_minor, inputs, currency="INR"):
            return registry.get("equal").validate(total_minor, inputs, currency)

        def allocate(self, total_minor, inputs, currency="INR"):
            raise NotImplementedError

    fresh = SplitRegistry()
    fresh.register(HalfToFirst())
    assert fresh.keys() == ["half"]


def test_equal_does_not_store_input_values():
    shares = registry.get("equal").allocate(300, [SplitInput("a", Decimal(9)), SplitInput("b")])
    assert [s.input_value for s in shares] == [None, None]


def test_weighted_methods_keep_input_values():
    shares = registry.get("shares").allocate(
        300, [SplitInput("a", Decimal(2)), SplitInput("b", Decimal(1))]
    )
    assert [(s.share_minor, s.input_value) for s in shares] == [
        (200, Decimal(2)),
        (100, Decimal(1)),
    ]


def test_duplicate_people_are_a_programming_error():
    with pytest.raises(ValueError):
        registry.get("equal").validate(100, [SplitInput("a"), SplitInput("a")])


def test_missing_value_is_a_programming_error():
    with pytest.raises(ValueError):
        registry.get("exact").validate(100, [SplitInput("a")])


def test_fractional_paise_in_exact_is_a_programming_error():
    with pytest.raises(ValueError):
        registry.get("exact").validate(
            100, [SplitInput("a", Decimal("99.5")), SplitInput("b", Decimal("0.5"))]
        )


def test_float_total_is_rejected():
    with pytest.raises(TypeError):
        registry.get("equal").validate(100.0, [SplitInput("a")])  # type: ignore[arg-type]


def test_float_values_are_rejected():
    with pytest.raises(TypeError):
        registry.get("percent").validate(100, [SplitInput("a", 100.0)])  # type: ignore[arg-type]


def test_allocate_is_deterministic():
    inputs = [SplitInput(u, Decimal(w)) for u, w in [("a", "1"), ("b", "1"), ("c", "1")]]
    first = registry.get("shares").allocate(100, inputs)
    assert all(registry.get("shares").allocate(100, inputs) == first for _ in range(20))


@pytest.mark.parametrize("seed", range(200))
def test_weighted_allocations_always_sum_to_total(seed):
    rng = random.Random(seed)
    total = rng.randint(1, 10_000_000)
    people = [f"p{i}" for i in range(rng.randint(1, 12))]

    weights = [Decimal(rng.randint(0, 500)) / Decimal(rng.choice([1, 10, 100])) for _ in people]
    if sum(weights) == 0:
        weights[0] = Decimal(1)
    shares = registry.get("shares").allocate(
        total, [SplitInput(p, w) for p, w in zip(people, weights, strict=True)]
    )
    assert sum(s.share_minor for s in shares) == total
    # Nobody is more than one paisa away from their exact proportional share.
    wsum = sum(weights)
    for s, w in zip(shares, weights, strict=True):
        assert abs(Decimal(s.share_minor) - total * w / wsum) < 1

    equal = registry.get("equal").allocate(total, [SplitInput(p) for p in people])
    parts = [s.share_minor for s in equal]
    assert sum(parts) == total and max(parts) - min(parts) <= 1


def test_distribute_guards():
    with pytest.raises(ValueError):
        distribute(100, [Decimal(0), Decimal(0)])
    with pytest.raises(ValueError):
        distribute(100, [Decimal(1), Decimal(-1)])
    assert distribute(0, [Decimal(1), Decimal(2)]) == [0, 0]
