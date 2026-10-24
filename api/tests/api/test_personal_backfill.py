"""Migration 0013: the accounts it backfills from entry labels, the transfer trigger, and the
downgrade that refuses while entries of the new types exist."""

import json
import uuid
from datetime import date, datetime
from pathlib import Path
from types import SimpleNamespace

import pytest
from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import CheckConstraint, text
from sqlalchemy.exc import IntegrityError

from app.core.db import SessionLocal
from app.models import PersonalAccount, PersonalTransaction
from app.modules.personal import ledger_rules
from app.seed import data
from app.seed.loader import account_id, rupees
from tests.api.conftest import uid
from tests.api.test_reference_data import _migration

ROOT = Path(__file__).parents[2]
VECTORS = json.loads((ROOT.parent / "shared" / "ledger_vectors.json").read_text(encoding="utf-8"))
MIGRATION = _migration("0013_personal_ledger")


def _cfg() -> Config:
    return Config(str(ROOT / "alembic.ini"))


def _accounts(session) -> dict[str, dict]:
    rows = session.execute(text("SELECT * FROM personal_accounts")).mappings()
    return {r["sms_label"]: dict(r) for r in rows}


def _clear_new_rows(session) -> None:
    """What stops a downgrade to 0012: reminder decisions and schedules (0017), holdings
    (0016), allocation rules (0015), goals (0014) and entries of the new types (0013)."""
    for table in (
        "personal_reminder_states",
        "personal_reminder_schedules",
        "personal_allocation_plans",
        "personal_allocation_rules",
        "personal_goal_contributions",
        "personal_goals",
    ):
        session.execute(text(f"DELETE FROM {table}"))
    session.execute(
        text("DELETE FROM personal_transactions WHERE type NOT IN ('income', 'expense')")
    )
    session.execute(text("DELETE FROM personal_holdings"))


def _seed_account(key: str) -> data.SeedAccount:
    return next(a for a in data.ACCOUNTS if a.key == key)


def test_the_backfill_makes_an_account_per_label(seeded):
    with SessionLocal.begin() as s:
        # Downgrading refuses while entries of the new types exist.
        _clear_new_rows(s)
        versions = dict(s.execute(text("SELECT id, version FROM personal_transactions")).all())
    command.downgrade(_cfg(), "0012_category_rules")
    command.upgrade(_cfg(), "head")

    with SessionLocal() as s:
        accounts = _accounts(s)
        assert {(k, a["type"], a["opening_balance_minor"]) for k, a in accounts.items()} == {
            (data.HDFC, "bank", 2_748_000),  # ₹1,12,480 reported after the ₹85,000 salary
            (data.ICICI_CARD, "credit_card", 0),  # a card reports a limit, not what's owed
        }
        for label, a in accounts.items():
            assert a["id"] == ledger_rules.sms_account_id(uid("john"), label)
            assert (a["name"], a["currency"], a["status"], a["version"]) == (
                label,
                "INR",
                "active",
                1,
            )
            first = s.scalar(
                text("SELECT min(created_at) FROM personal_transactions WHERE account = :l"),
                {"l": label},
            )
            assert a["created_at"] == first
        # The seed's own accounts have the same ids, and HDFC the same opening.
        assert accounts[data.HDFC]["id"] == account_id(_seed_account("hdfc"))
        assert accounts[data.ICICI_CARD]["id"] == account_id(_seed_account("icici_card"))
        assert rupees(_seed_account("hdfc").opening) == 2_748_000

        links = s.execute(
            text(
                "SELECT account, account_id, count(*) FROM personal_transactions "
                "GROUP BY account, account_id"
            )
        ).all()
        assert {(label, n) for label, _, n in links if label} == {
            (data.HDFC, 6),
            (data.ICICI_CARD, 1),
        }
        for label, linked, _ in links:
            assert linked == (accounts[label]["id"] if label else None)

        directions = s.execute(
            text("SELECT DISTINCT type, direction FROM personal_transactions")
        ).all()
        assert set(directions) == {("income", "in"), ("expense", "out")}
        # The rows didn't change for anyone, so devices aren't told they did.
        assert dict(s.execute(text("SELECT id, version FROM personal_transactions")).all()) == (
            versions
        )

        # HDFC's derived balance right after its first report is what the bank said.
        rows = s.execute(
            text(
                "SELECT direction, amount_minor, balance_minor FROM personal_transactions "
                "WHERE account_id = :a AND deleted_at IS NULL "
                "ORDER BY date, COALESCE(sms_at, created_at), created_at, id::text"
            ),
            {"a": accounts[data.HDFC]["id"]},
        ).all()
        balance = accounts[data.HDFC]["opening_balance_minor"]
        for direction, amount, reported in rows:
            balance += amount if direction == "in" else -amount
            if reported is not None:
                assert balance == reported
                break
        else:
            pytest.fail("HDFC has no reported balance")


def test_deleted_entries_other_currencies_and_padded_labels(seeded):
    """Deleted entries are linked but don't set the opening; entries in a currency other than
    the user's are neither; a label's surrounding spaces don't count."""
    with SessionLocal.begin() as s:
        _clear_new_rows(s)
        s.execute(
            text(
                "UPDATE personal_transactions SET deleted_at = now() "
                "WHERE account = :l AND type = 'income'"
            ),
            {"l": data.HDFC},
        )
        s.execute(
            text(
                "INSERT INTO personal_transactions (user_id, type, direction, amount_minor, "
                "currency, date, description, account, balance_minor) VALUES "
                "(:u, 'expense', 'out', 100, 'USD', '2026-08-01', 'Abroad', :l, 999), "
                "(:u, 'expense', 'out', 200, 'INR', '2026-09-30', 'Only report', '  SBI ··0042 ', "
                "5000)"
            ),
            {"u": uid("john"), "l": data.HDFC},
        )
    command.downgrade(_cfg(), "0012_category_rules")
    command.upgrade(_cfg(), "head")
    with SessionLocal() as s:
        accounts = _accounts(s)
        # Without the salary, HDFC's first live report is the Rapido ride (₹43,882 after ₹400).
        assert accounts[data.HDFC]["opening_balance_minor"] == 4_388_200 + 40_000
        assert accounts["SBI ··0042"]["opening_balance_minor"] == 5000 + 200
        sbi = s.scalar(
            text("SELECT account_id FROM personal_transactions WHERE description = 'Only report'")
        )
        assert (
            sbi
            == accounts["SBI ··0042"]["id"]
            == ledger_rules.sms_account_id(uid("john"), "SBI ··0042")
        )
        rows = s.execute(
            text("SELECT description, account_id FROM personal_transactions WHERE account = :l"),
            {"l": data.HDFC},
        ).all()
        assert {d: a for d, a in rows}["Abroad"] is None
        assert {a for d, a in rows if d != "Abroad"} == {accounts[data.HDFC]["id"]}
        salary = s.scalar(
            text(
                "SELECT account_id FROM personal_transactions "
                "WHERE account = :l AND deleted_at IS NOT NULL"
            ),
            {"l": data.HDFC},
        )
        assert salary == accounts[data.HDFC]["id"]


def _transfer(session, amount_out: int = 200_000, amount_in: int = 200_000) -> uuid.UUID:
    """HDFC → Cash, the seed's accounts. Returns the group id."""
    group = uuid.uuid4()
    legs = [
        ("out", amount_out, account_id(_seed_account("hdfc"))),
        ("in", amount_in, account_id(_seed_account("cash"))),
    ]
    for direction, amount, account in legs:
        session.execute(
            text(
                "INSERT INTO personal_transactions (user_id, type, direction, amount_minor, "
                "currency, date, description, account_id, transfer_group_id) VALUES "
                "(:u, 'transfer', :d, :amount, 'INR', '2026-09-12', 'Cash withdrawal', :a, :g)"
            ),
            {"u": uid("john"), "d": direction, "amount": amount, "a": account, "g": group},
        )
    return group


def test_a_transfer_is_two_matching_legs(seeded):
    # Checked at commit, so the first leg can be written before the second.
    with SessionLocal.begin() as s:
        group = _transfer(s)
    with pytest.raises(IntegrityError, match="not two matching halves"):
        with SessionLocal.begin() as s:
            _transfer(s, amount_in=150_000)
    # Deleting a leg deletes the transfer: both go together.
    with pytest.raises(IntegrityError, match="not two matching halves"):
        with SessionLocal.begin() as s:
            s.execute(
                text(
                    "UPDATE personal_transactions SET deleted_at = now() "
                    "WHERE transfer_group_id = :g AND direction = 'out'"
                ),
                {"g": group},
            )
    with SessionLocal.begin() as s:
        s.execute(
            text(
                "UPDATE personal_transactions SET deleted_at = now() WHERE transfer_group_id = :g"
            ),
            {"g": group},
        )


def test_downgrade_refuses_while_any_new_rows_exist(seeded):
    """Each migration refuses while its rows exist: 0017 reminder decisions and schedules, 0016
    holdings, 0015 allocation rules, 0014 goals, then 0013 transfers and the like. Each time the
    whole downgrade rolls back."""

    def refused(message: str) -> None:
        with pytest.raises(RuntimeError, match=f"Can't downgrade: {message}"):
            command.downgrade(_cfg(), "0012_category_rules")

    def clear(*statements: str) -> None:
        with SessionLocal.begin() as s:
            for statement in statements:
                s.execute(text(statement))

    reminders = len(data.REMINDER_STATES) + len(data.SCHEDULES)
    refused(f"{reminders} reminder decisions and schedules")
    clear("DELETE FROM personal_reminder_states", "DELETE FROM personal_reminder_schedules")
    refused(f"{len(data.HOLDINGS)} personal holdings")
    clear(
        "UPDATE personal_transactions SET holding_id = NULL WHERE holding_id IS NOT NULL",
        "DELETE FROM personal_holdings",
    )
    refused(f"{len(data.RULES)} allocation rules")
    clear("DELETE FROM personal_allocation_plans", "DELETE FROM personal_allocation_rules")
    refused(f"{len(data.GOALS)} personal goals")
    clear("DELETE FROM personal_goal_contributions", "DELETE FROM personal_goals")
    with SessionLocal.begin() as s:
        _transfer(s)
        n = s.scalar(
            text(
                "SELECT count(*) FROM personal_transactions WHERE type NOT IN ('income', 'expense')"
            )
        )
    refused(f"{n} personal entries")
    head = ScriptDirectory.from_config(_cfg()).get_current_head()
    with SessionLocal() as s:
        assert s.scalar(text("SELECT version_num FROM alembic_version")) == head
        assert s.scalar(text("SELECT count(*) FROM personal_accounts")) == len(data.ACCOUNTS)


def test_the_model_and_the_migration_agree():
    """`alembic check` doesn't compare check constraints, so this does."""

    def checks(model) -> dict[str, str]:
        return {
            c.name: str(c.sqltext)
            for c in model.__table__.constraints
            if isinstance(c, CheckConstraint)
        }

    txn = checks(PersonalTransaction)
    assert txn["ck_personal_transactions_type"] == MIGRATION.TYPE_CHECK
    for name, condition in MIGRATION.CHECKS:
        assert txn[f"ck_personal_transactions_{name}"] == condition
    accounts = checks(PersonalAccount)
    assert accounts["ck_personal_accounts_type"] == MIGRATION.ACCOUNT_TYPE_CHECK
    assert accounts["ck_personal_accounts_status"] == MIGRATION.ACCOUNT_STATUS_CHECK
    assert MIGRATION._ACCOUNT_NAMESPACE == ledger_rules.ACCOUNT_NAMESPACE
    assert uuid.UUID(VECTORS["namespace"]) == ledger_rules.ACCOUNT_NAMESPACE
    assert set(MIGRATION._LIABILITIES) == ledger_rules.LIABILITY_TYPES


@pytest.mark.parametrize("case", VECTORS["opening_balance"], ids=lambda c: c["name"])
def test_opening_balance_vectors(case):
    rows = []
    for e in case["entries"]:
        assert ledger_rules.implied_direction(e["type"]) == e["direction"]
        rows.append(
            SimpleNamespace(
                date=date.fromisoformat(e["day"]),
                at=datetime.fromisoformat(e["at"]),
                created_at=datetime.fromisoformat(e["created_at"]),
                id_text=e["id"],
                direction=e["direction"],
                amount_minor=e["amount_minor"],
                balance_minor=e["balance_minor"],
            )
        )
    liability = case["account_type"] in ledger_rules.LIABILITY_TYPES
    assert MIGRATION.opening_balance(rows, liability) == case["opening_minor"]


@pytest.mark.parametrize("case", VECTORS["account_ids"], ids=lambda c: c["label"])
def test_account_id_vectors(case):
    expected = uuid.UUID(case["id"])
    assert ledger_rules.sms_account_id(case["user_id"], case["label"]) == expected
    assert ledger_rules.sms_account_id(uuid.UUID(case["user_id"]), case["label"]) == expected
    assert MIGRATION.account_id(uuid.UUID(case["user_id"]), case["label"]) == expected


@pytest.mark.parametrize("case", VECTORS["account_types"], ids=lambda c: c["label"])
def test_account_type_vectors(case):
    assert ledger_rules.account_type_for_label(case["label"]) == case["type"]
    assert MIGRATION.account_type(case["label"]) == case["type"]
