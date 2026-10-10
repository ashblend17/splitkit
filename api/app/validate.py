"""Checks that the data in the database is consistent. Read-only.

    uv run python -m app.validate            # against DATABASE_URL (the dev database by default)
    uv run python -m app.validate --json     # machine-readable
    docker compose exec api python -m app.validate

Exit code 0: no errors (warnings allowed). 1: at least one error. 2: couldn't run.
Each check says what it means and how to fix it; validation.md has the full runbook.
"""

import argparse
import json
import sys
import uuid
from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.db import SessionLocal

SAMPLE = 5


@dataclass
class Check:
    key: str
    severity: str  # error | warning
    means: str
    fix: str
    run: Callable[[Session], list[dict[str, Any]]]


@dataclass
class Result:
    check: Check
    problems: list[dict[str, Any]] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.problems


def _sql(query: str) -> Callable[[Session], list[dict[str, Any]]]:
    def run(session: Session) -> list[dict[str, Any]]:
        return [dict(r._mapping) for r in session.execute(text(query))]

    return run


# ---- money and splits ----

CHECKS: list[Check] = [
    Check(
        "expense_shares_add_up",
        "error",
        "Every expense's shares add up exactly to its amount.",
        "Edit the expense in the app (or PUT /expenses/{id}) to re-allocate its split.",
        _sql("""
            SELECT e.id, e.amount_minor, COALESCE(SUM(s.share_minor), 0) AS shares_minor
            FROM expenses e LEFT JOIN expense_splits s ON s.expense_id = e.id
            GROUP BY e.id HAVING COALESCE(SUM(s.share_minor), 0) <> e.amount_minor
        """),
    ),
    Check(
        "amounts_positive",
        "error",
        "Expense and payment amounts are above zero; no share is negative.",
        "Fix the row by editing it in the app; amounts are integer minor units (paise).",
        _sql("""
            SELECT 'expense' AS kind, id, amount_minor FROM expenses WHERE amount_minor <= 0
            UNION ALL SELECT 'settlement', id, amount_minor FROM settlements WHERE amount_minor <= 0
            UNION ALL SELECT 'split', expense_id, share_minor FROM expense_splits
                WHERE share_minor < 0
            UNION ALL SELECT 'personal', id, amount_minor FROM personal_transactions
                WHERE amount_minor <= 0
        """),
    ),
    Check(
        "expense_people_are_members",
        "error",
        "The payer and everyone in a split are (or were) members of the expense's group.",
        "Add the person back to the group (they can leave again once square), or edit the expense.",
        _sql("""
            SELECT e.id, s.user_id AS person, 'split' AS role
            FROM expenses e JOIN expense_splits s ON s.expense_id = e.id
            LEFT JOIN group_members m ON m.group_id = e.group_id AND m.user_id = s.user_id
            WHERE m.user_id IS NULL
            UNION ALL
            SELECT e.id, e.payer_id, 'payer' FROM expenses e
            LEFT JOIN group_members m ON m.group_id = e.group_id AND m.user_id = e.payer_id
            WHERE m.user_id IS NULL
        """),
    ),
    Check(
        "settlements_are_between_members",
        "error",
        "A payment is between two different members of its group.",
        "Delete the payment in the app (it can be restored) and record it again.",
        _sql("""
            SELECT s.id, s.from_user, s.to_user FROM settlements s
            LEFT JOIN group_members a ON a.group_id = s.group_id AND a.user_id = s.from_user
            LEFT JOIN group_members b ON b.group_id = s.group_id AND b.user_id = s.to_user
            WHERE s.from_user = s.to_user OR a.user_id IS NULL OR b.user_id IS NULL
        """),
    ),
    Check(
        "currency_matches_group",
        "error",
        "Expenses and payments are in their group's currency (no conversion in the MVP).",
        "Groups can't change currency, so this means a bad import or manual SQL: fix the row.",
        _sql("""
            SELECT 'expense' AS kind, e.id, e.currency, g.currency AS group_currency
            FROM expenses e JOIN groups g ON g.id = e.group_id WHERE e.currency <> g.currency
            UNION ALL
            SELECT 'settlement', s.id, s.currency, g.currency
            FROM settlements s JOIN groups g ON g.id = s.group_id WHERE s.currency <> g.currency
        """),
    ),
    Check(
        "categories_fit_their_use",
        "error",
        "Expenses use group categories; personal entries use personal ones that are built in "
        "or their owner's.",
        "Pick another category for the row in the app.",
        _sql("""
            SELECT 'expense' AS kind, e.id, e.category_id FROM expenses e
            LEFT JOIN categories c ON c.id = e.category_id
            WHERE e.category_id IS NOT NULL AND (c.id IS NULL OR c.scope NOT IN ('group', 'all'))
            UNION ALL
            SELECT 'personal', t.id, t.category_id FROM personal_transactions t
            LEFT JOIN categories c ON c.id = t.category_id
            WHERE t.category_id IS NOT NULL AND (c.id IS NULL OR c.scope NOT IN ('personal', 'all')
                OR (c.owner_id IS NOT NULL AND c.owner_id <> t.user_id))
        """),
    ),
    # ---- people and groups ----
    Check(
        "accounts_are_sane",
        "error",
        "Placeholders (no email) have no password or personal data; emails are unique "
        "ignoring case.",
        "Merge the duplicate accounts, or clear the placeholder's password/personal rows.",
        _sql("""
            SELECT 'placeholder_with_password' AS problem, id FROM users
                WHERE email IS NULL AND password_hash IS NOT NULL
            UNION ALL SELECT 'placeholder_with_personal', t.user_id FROM personal_transactions t
                JOIN users u ON u.id = t.user_id WHERE u.email IS NULL
            UNION ALL SELECT 'duplicate_email', MIN(id::text)::uuid FROM users
                WHERE email IS NOT NULL GROUP BY lower(email) HAVING COUNT(*) > 1
        """),
    ),
    Check(
        "invites_are_open",
        "warning",
        "Invite emails sit only on current placeholder members, in lowercase, and no account "
        "has that email yet (signing up with it would have taken the placeholder's place).",
        "Link the member again in the app (POST /groups/{id}/members/{user_id}/link): with an "
        "account it merges, otherwise it re-saves the invite.",
        _sql("""
            SELECT 'invite_on_account' AS problem, m.group_id, m.user_id FROM group_members m
                JOIN users u ON u.id = m.user_id
                WHERE m.invite_email IS NOT NULL AND u.email IS NOT NULL
            UNION ALL SELECT 'invite_not_lowercase', m.group_id, m.user_id FROM group_members m
                WHERE m.invite_email <> lower(m.invite_email)
            UNION ALL SELECT 'invite_has_account', m.group_id, m.user_id FROM group_members m
                JOIN users a ON lower(a.email) = m.invite_email
                WHERE m.left_at IS NULL
        """),
    ),
    Check(
        "groups_have_members",
        "warning",
        "Every group that isn't archived has at least one current member.",
        "Normal after everyone leaves; archive the group, or add a member back.",
        _sql("""
            SELECT g.id, g.name FROM groups g
            WHERE g.archived_at IS NULL AND NOT EXISTS (
                SELECT 1 FROM group_members m WHERE m.group_id = g.id AND m.left_at IS NULL)
        """),
    ),
    Check(
        "versions_start_at_one",
        "error",
        "Every versioned row has version 1 or more (clients send it back to detect conflicts).",
        "UPDATE the row's version to 1; clients will reload it on their next sync.",
        _sql("""
            SELECT 'expense' AS kind, id FROM expenses WHERE version < 1
            UNION ALL SELECT 'settlement', id FROM settlements WHERE version < 1
            UNION ALL SELECT 'group', id FROM groups WHERE version < 1
            UNION ALL SELECT 'personal', id FROM personal_transactions WHERE version < 1
            UNION ALL SELECT 'user', id FROM users WHERE version < 1
        """),
    ),
    # ---- imports and admin ----
    Check(
        "undone_imports_left_nothing",
        "error",
        "An undone Tricount import leaves no live expense or payment behind.",
        "Undo the batch again (POST /import/batches/{id}/undo is idempotent).",
        _sql("""
            SELECT b.id AS batch, 'expense' AS kind, e.id FROM import_batches b
                JOIN expenses e ON e.import_batch_id = b.id
                WHERE b.undone_at IS NOT NULL AND e.deleted_at IS NULL
            UNION ALL
            SELECT b.id, 'settlement', s.id FROM import_batches b
                JOIN settlements s ON s.import_batch_id = b.id
                WHERE b.undone_at IS NOT NULL AND s.deleted_at IS NULL
        """),
    ),
    Check(
        "admin_sessions_are_closed",
        "warning",
        "View-as sessions end in time; none is open past its expiry, none ends before it starts.",
        "`uv run python -m app.recover end-admin-sessions` closes every open one.",
        _sql("""
            SELECT id, admin_id, target_user_id, started_at, ended_at, expires_at
            FROM admin_sessions
            WHERE (ended_at IS NULL AND expires_at IS NOT NULL AND expires_at < now())
               OR (ended_at IS NOT NULL AND ended_at < started_at)
        """),
    ),
    Check(
        "admin_writes_by_admins",
        "warning",
        "Rows marked as written by an admin point at someone who is an admin.",
        "Expected if an admin was later demoted; otherwise investigate in the audit log.",
        _sql("""
            SELECT 'expense' AS kind, e.id, e.acting_admin_id FROM expenses e
                JOIN users u ON u.id = e.acting_admin_id WHERE u.role <> 'admin'
            UNION ALL SELECT 'settlement', s.id, s.acting_admin_id FROM settlements s
                JOIN users u ON u.id = s.acting_admin_id WHERE u.role <> 'admin'
        """),
    ),
    # ---- sync log ----
    Check(
        "sync_streams_are_gap_free",
        "error",
        "Each stream's kept changes run from oldest_seq+1 to head_seq with no gaps.",
        "`uv run python -m app.recover reset-stream <stream>` makes every device reload it.",
        _sql("""
            SELECT s.id AS stream, s.head_seq, s.oldest_seq,
                   COUNT(c.seq) AS kept, MAX(c.seq) AS max_seq
            FROM sync_streams s
            LEFT JOIN change_log c ON c.stream_id = s.id AND c.seq > s.oldest_seq
            GROUP BY s.id
            HAVING COUNT(c.seq) <> s.head_seq - s.oldest_seq
                OR COALESCE(MAX(c.seq), s.oldest_seq) <> s.head_seq
        """),
    ),
    Check(
        "sync_streams_point_somewhere",
        "error",
        "Every stream is `global`, or names a group or user that exists.",
        "Delete the orphan stream's rows from change_log and sync_streams.",
        _sql("""
            SELECT s.id AS stream FROM sync_streams s
            WHERE s.id <> 'global'
              AND NOT (s.id LIKE 'group:%'
                       AND EXISTS (SELECT 1 FROM groups g WHERE 'group:' || g.id::text = s.id))
              AND NOT (s.id LIKE 'user:%'
                       AND EXISTS (SELECT 1 FROM users u WHERE 'user:' || u.id::text = s.id))
        """),
    ),
]

_TABLES = {
    "expense": "expenses",
    "settlement": "settlements",
    "group": "groups",
    "personal_transaction": "personal_transactions",
    "profile": "users",
}


def _sync_matches_tables(session: Session) -> list[dict[str, Any]]:
    """The newest change for each entity agrees with its table: a delete means the row is gone,
    an upsert means it exists at that version. Rows only the seed wrote have no changes."""
    latest = session.execute(
        text("""
            SELECT DISTINCT ON (c.stream_id, c.entity, c.entity_id)
                   c.stream_id, c.entity, c.entity_id, c.op, c.version
            FROM change_log c JOIN sync_streams s ON s.id = c.stream_id
            WHERE c.entity IN ('expense', 'settlement', 'group', 'personal_transaction', 'profile')
              AND c.seq > s.oldest_seq  -- older entries are superseded by snapshots
            ORDER BY c.stream_id, c.entity, c.entity_id, c.seq DESC
        """)
    )
    rows = list(latest)
    versions: dict[str, dict[uuid.UUID, int]] = {}
    for entity, table in _TABLES.items():
        versions[entity] = {
            r.id: r.version for r in session.execute(text(f"SELECT id, version FROM {table}"))
        }
    problems = []
    for r in rows:
        current = versions[r.entity].get(r.entity_id)
        if r.op == "delete" and current is not None:
            problems.append(
                {**r._mapping, "table_version": current, "problem": "deleted_but_present"}
            )
        elif r.op == "upsert" and current is None:
            problems.append({**r._mapping, "table_version": None, "problem": "missing_row"})
        elif r.op == "upsert" and r.version is not None and r.version != current:
            problems.append({**r._mapping, "table_version": current, "problem": "version_differs"})
    return problems


CHECKS.append(
    Check(
        "sync_log_matches_tables",
        "error",
        "The newest sync entry for each entity matches the table (so devices end up with what "
        "the server has).",
        "A write bypassed record() (manual SQL?). `uv run python -m app.recover reset-stream "
        "<stream>` makes devices reload from the tables.",
        _sync_matches_tables,
    )
)


def run(session: Session) -> list[Result]:
    return [Result(c, c.run(session)) for c in CHECKS]


def _plain(value: Any) -> Any:
    return str(value) if isinstance(value, uuid.UUID) else value


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.validate", description=__doc__)
    parser.add_argument("--json", action="store_true", help="print JSON instead of a report")
    args = parser.parse_args(argv)
    try:
        with SessionLocal() as session:
            results = run(session)
    except Exception as e:  # noqa: BLE001 - report any failure to connect or query
        print(f"Couldn't run the checks: {e}", file=sys.stderr)
        return 2
    errors = sum(1 for r in results if not r.ok and r.check.severity == "error")
    warnings = sum(1 for r in results if not r.ok and r.check.severity == "warning")
    if args.json:
        out = {
            "ok": errors == 0,
            "errors": errors,
            "warnings": warnings,
            "checks": [
                {
                    "key": r.check.key,
                    "severity": r.check.severity,
                    "ok": r.ok,
                    "count": len(r.problems),
                    "sample": [{k: _plain(v) for k, v in p.items()} for p in r.problems[:SAMPLE]],
                    "means": r.check.means,
                    "fix": r.check.fix,
                }
                for r in results
            ],
        }
        print(json.dumps(out, indent=2, default=str))
    else:
        for r in results:
            mark = "ok  " if r.ok else ("FAIL" if r.check.severity == "error" else "WARN")
            print(f"[{mark}] {r.check.key}: {r.check.means}")
            if not r.ok:
                print(f"       {len(r.problems)} found. Fix: {r.check.fix}")
                for p in r.problems[:SAMPLE]:
                    print("       - " + ", ".join(f"{k}={_plain(v)}" for k, v in p.items()))
        print(f"\n{len(results)} checks: {errors} failed, {warnings} warnings.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
