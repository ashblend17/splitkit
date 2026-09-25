"""Runs shared/balance_vectors.json against the Python balance engine and settle-up planner.

The Dart port (app/lib/core/local/balance_engine.dart) runs the same file. To add a case, add its
inputs to the JSON with any expected values, then rewrite them from the Python code:
  uv run python -m tests.test_balance_vectors --regenerate
"""

import json
import sys
from pathlib import Path

import pytest

from app.modules.balances.engine import (
    expense_flows,
    pairwise,
    positions,
    settlement_flow,
    simplify,
)
from app.modules.settlements.planner import GroupBalance, SettleUpError, plan_settle_up

PATH = Path(__file__).parents[2] / "shared" / "balance_vectors.json"
VECTORS = json.loads(PATH.read_text(encoding="utf-8"))


def expected_balances(case: dict) -> dict:
    flows = [
        f for e in case["expenses"] for f in expense_flows(e["payer"], map(tuple, e["shares"]))
    ]
    flows += [settlement_flow(s["from"], s["to"], s["amount"]) for s in case["settlements"]]
    pos = positions(flows)
    return {
        "pairwise": dict(sorted(pairwise(case["me"], flows).items())),
        "positions": dict(sorted(pos.items())),
        "simplified": [
            [f.debtor, f.creditor, f.amount] for f in simplify({p: n for p, n in pos.items() if n})
        ],
    }


def expected_plan(case: dict) -> dict:
    try:
        plan = plan_settle_up(
            [GroupBalance(g, n) for g, n in case["balances"]], case["amount_minor"]
        )
    except SettleUpError as e:
        return {"error": str(e)}
    return {"plan": [[p.group_id, p.friend_pays, p.amount_minor] for p in plan]}


@pytest.mark.parametrize("case", VECTORS["cases"], ids=lambda c: c["name"])
def test_balance_vector(case):
    assert {k: case[k] for k in ("pairwise", "positions", "simplified")} == expected_balances(case)


@pytest.mark.parametrize("case", VECTORS["settle_up"], ids=lambda c: c["name"])
def test_settle_up_vector(case):
    assert {k: case[k] for k in ("plan", "error") if k in case} == expected_plan(case)


if __name__ == "__main__" and "--regenerate" in sys.argv:
    for c in VECTORS["cases"]:
        c.update(expected_balances(c))
    for c in VECTORS["settle_up"]:
        c.pop("plan", None)
        c.pop("error", None)
        c.update(expected_plan(c))
    PATH.write_text(json.dumps(VECTORS, indent=1) + "\n", encoding="utf-8")
    print(f"Rewrote {PATH}")
