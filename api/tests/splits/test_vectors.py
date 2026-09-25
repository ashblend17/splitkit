"""Runs the language-neutral vectors in shared/split_vectors.json against the Python engine."""

import json
from decimal import Decimal
from pathlib import Path

import pytest

from app.modules.splits.engine import SplitInput, SplitValidationError, registry

VECTORS = json.loads(
    (Path(__file__).parents[3] / "shared" / "split_vectors.json").read_text(encoding="utf-8")
)["cases"]


def _inputs(case):
    return [SplitInput(uid, None if v is None else Decimal(v)) for uid, v in case["inputs"]]


@pytest.mark.parametrize("case", VECTORS, ids=[c["name"] for c in VECTORS])
def test_vector(case):
    method = registry.get(case["method"])
    total, inputs, expect = case["total_minor"], _inputs(case), case["expect"]

    v = method.validate(total, inputs)
    assert (v.ok, v.remaining_minor, v.message) == (
        expect["ok"],
        expect["remaining_minor"],
        expect["message"],
    )
    if "remaining_percent" in expect:
        assert v.remaining_percent == Decimal(expect["remaining_percent"])

    if expect["ok"]:
        shares = method.allocate(total, inputs)
        assert [s.user_id for s in shares] == [i.user_id for i in inputs]
        assert {s.user_id: s.share_minor for s in shares} == expect["shares"]
        assert sum(s.share_minor for s in shares) == total
    else:
        with pytest.raises(SplitValidationError) as err:
            method.allocate(total, inputs)
        assert err.value.validation == v
