"""personal ledger: accounts, entry types, transfers and refunds; category kinds

Personal becomes a small ledger. An account (cash, bank, credit card, loan, investment or other
asset) has an opening balance; its balance is derived on the device from the entries that use
it and never stored. Entries gain:
- `account_id`, the account they moved;
- `direction` (in or out), implied by the type except for transfer legs and corrections;
- `transfer_group_id`: a transfer is two legs, one out and one in, of the same amount between two
  of your accounts. A deferred trigger refuses a commit that leaves a group with anything else,
  as the split-sum trigger does for expenses (0001). `alembic check` doesn't see triggers;
- `refund_of_id`, the spend a refund gives money back for.
The type check widens to transfer, refund, investment_contribution, investment_withdrawal and
adjustment (a balance correction). The account and refund foreign keys include `user_id`, so an
entry can only use its owner's account and refund its owner's spend. System categories get a
`kind` (need, want or income).

Backfill. `direction` comes from the type (only income and expense exist before this). Each
distinct account label on a user's entries ("HDFC ··4821", from bank SMS) becomes an account
with the id the app makes for that label (ledger_rules.sms_account_id), so a phone that reads
the label later finds this row instead of making another. A label with "credit card" in it is a
credit_card, any other a bank account. The opening balance makes the derived balance right
after the first entry with a bank-reported balance equal that balance; it is 0 for cards (their
SMS report a limit, not what's owed) and for labels that never reported one. Entries, deleted
ones too, are linked to their label's account when they're in its currency. Nothing bumps
`version`: these rows didn't change for anyone.

Migrations bypass the sync log, so devices learn about the accounts and the new columns only
from a snapshot: a new app build reloads its copy (local schema version 2), and running
`python -m app.recover reset-stream` for every user stream and `global` makes builds that
loaded a snapshot before this ran reload too.

Downgrading refuses while any entry has a new type: silently deleting financial records is
worse than refusing.

Revision ID: 0013_personal_ledger
Revises: 0012_category_rules
Create Date: 2026-10-17
"""

import uuid
from collections import defaultdict
from collections.abc import Iterable, Sequence
from typing import Any

import sqlalchemy as sa
from alembic import op

revision: str = "0013_personal_ledger"
down_revision: str | Sequence[str] | None = "0012_category_rules"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TXN = "personal_transactions"
ACCOUNTS = "personal_accounts"

# app.modules.personal.ledger_rules.ACCOUNT_NAMESPACE; copied so this migration never changes
# with the app.
_ACCOUNT_NAMESPACE = uuid.UUID("e90fe153-8f9c-5d42-8516-3ac04850d447")
_LIABILITIES = ("credit_card", "loan")

# System category key -> kind. The seed's CATEGORIES carry the same (test_reference_data.py).
KINDS = {
    "food": "need",
    "transport": "need",
    "shopping": "want",
    "entertainment": "want",
    "travel": "want",
    "stay": "want",
    "rent": "need",
    "bills": "need",
    "health": "need",
    "income": "income",
    "other": None,
}

ACCOUNT_TYPE_CHECK = "type IN ('cash', 'bank', 'credit_card', 'loan', 'investment', 'other_asset')"
ACCOUNT_STATUS_CHECK = "status IN ('active', 'closed')"
OLD_TYPE_CHECK = "type IN ('income', 'expense')"
TYPE_CHECK = (
    "type IN ('income', 'expense', 'transfer', 'refund', 'investment_contribution', "
    "'investment_withdrawal', 'adjustment')"
)
# name (after ck_personal_transactions_), condition. The model has the same text.
CHECKS = [
    ("direction", "direction IN ('in', 'out')"),
    (
        "direction_matches_type",
        "(type IN ('income', 'refund', 'investment_withdrawal') AND direction = 'in') "
        "OR (type IN ('expense', 'investment_contribution') AND direction = 'out') "
        "OR type IN ('transfer', 'adjustment')",
    ),
    (
        "transfer_complete",
        "type <> 'transfer' OR (transfer_group_id IS NOT NULL AND account_id IS NOT NULL)",
    ),
    ("group_only_transfers", "transfer_group_id IS NULL OR type = 'transfer'"),
    ("adjustment_account", "type <> 'adjustment' OR account_id IS NOT NULL"),
    ("refund_of_only_refunds", "refund_of_id IS NULL OR type = 'refund'"),
    (
        "links_only_income_expense",
        "(expense_id IS NULL AND settlement_id IS NULL) OR type IN ('income', 'expense')",
    ),
    ("no_category_on_moves", "category_id IS NULL OR type NOT IN ('transfer', 'adjustment')"),
]
INDEXED = ("account_id", "transfer_group_id", "refund_of_id")

# The live legs of a transfer are none, or one out and one in: same amount and currency, two
# different accounts, one owner. Checked at COMMIT (deferred), so both legs can be written, or
# rewritten, in any order inside one transaction.
TRANSFER_CHECK = """
CREATE FUNCTION check_personal_transfer() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    g uuid;
    n int;
    amounts int;
    currencies int;
    ins int;
    outs int;
    accts int;
    owners int;
BEGIN
    FOREACH g IN ARRAY ARRAY[
        CASE WHEN TG_OP <> 'INSERT' THEN OLD.transfer_group_id END,
        CASE WHEN TG_OP <> 'DELETE' THEN NEW.transfer_group_id END
    ] LOOP
        CONTINUE WHEN g IS NULL;
        SELECT count(*), count(DISTINCT amount_minor), count(DISTINCT currency),
               count(*) FILTER (WHERE direction = 'in'), count(*) FILTER (WHERE direction = 'out'),
               count(DISTINCT account_id), count(DISTINCT user_id)
          INTO n, amounts, currencies, ins, outs, accts, owners
          FROM personal_transactions
         WHERE transfer_group_id = g AND deleted_at IS NULL;
        IF n <> 0 AND NOT (n = 2 AND amounts = 1 AND currencies = 1 AND ins = 1 AND outs = 1
                           AND accts = 2 AND owners = 1) THEN
            RAISE EXCEPTION 'transfer % is not two matching halves', g
                USING ERRCODE = 'check_violation';
        END IF;
    END LOOP;
    RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER personal_transfer_pairs
    AFTER INSERT OR UPDATE OR DELETE ON personal_transactions
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION check_personal_transfer();
"""


def account_id(user_id: Any, label: str) -> uuid.UUID:
    """= ledger_rules.sms_account_id()."""
    return uuid.uuid5(_ACCOUNT_NAMESPACE, f"{user_id}|{label}")


def account_type(label: str) -> str:
    """= ledger_rules.account_type_for_label()."""
    return "credit_card" if "credit card" in label.lower() else "bank"


def opening_balance(rows: Iterable[Any], liability: bool) -> int:
    """The opening balance that makes an account's derived balance, right after its first entry
    with a reported balance, equal that balance. 0 for a liability, or when no entry reported
    one.

    `rows` are the account's live entries in its currency, each with `date`, `at` (sms_at, else
    created_at), `created_at`, `id_text`, `direction`, `amount_minor` and `balance_minor`. The
    app's openingFromFirstReport() is the same rule (shared/ledger_vectors.json)."""
    if liability:
        return 0
    running = 0
    for r in sorted(rows, key=lambda r: (r.date, r.at, r.created_at, r.id_text)):
        running += r.amount_minor if r.direction == "in" else -r.amount_minor
        if r.balance_minor is not None:
            return r.balance_minor - running
    return 0


def _backfill_accounts(conn: sa.Connection) -> None:
    rows = conn.execute(
        sa.text(
            "SELECT t.user_id, btrim(t.account) AS label, t.id::text AS id_text, t.date, "
            "COALESCE(t.sms_at, t.created_at) AS at, t.created_at, t.direction, t.amount_minor, "
            "t.balance_minor, t.deleted_at IS NULL AS live, u.currency, "
            "t.currency = u.currency AS same_currency "
            "FROM personal_transactions t JOIN users u ON u.id = t.user_id "
            "WHERE btrim(coalesce(t.account, '')) <> ''"
        )
    ).all()
    by_label: dict[tuple[uuid.UUID, str], list[Any]] = defaultdict(list)
    for r in rows:
        by_label[(r.user_id, r.label)].append(r)
    accounts = []
    for user_id, label in sorted(by_label, key=lambda k: (str(k[0]), k[1])):
        entries = by_label[(user_id, label)]
        type_ = account_type(label)
        counted = [e for e in entries if e.live and e.same_currency]
        accounts.append(
            {
                "id": account_id(user_id, label),
                "user_id": user_id,
                "name": label[:60],
                "type": type_,
                "currency": entries[0].currency,
                "opening": opening_balance(counted, type_ in _LIABILITIES),
                "label": label,
                "created_at": min(e.created_at for e in entries),
            }
        )
    if accounts:
        conn.execute(
            sa.text(
                "INSERT INTO personal_accounts "
                "(id, user_id, name, type, currency, opening_balance_minor, sms_label, created_at) "
                "VALUES (:id, :user_id, :name, :type, :currency, :opening, :label, :created_at)"
            ),
            accounts,
        )
    conn.execute(
        sa.text(
            "UPDATE personal_transactions t SET account_id = a.id FROM personal_accounts a "
            "WHERE a.user_id = t.user_id AND a.sms_label = btrim(t.account) "
            "AND t.currency = a.currency"
        )
    )


def upgrade() -> None:
    conn = op.get_bind()
    op.create_table(
        ACCOUNTS,
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("type", sa.Text(), nullable=False),
        sa.Column("currency", sa.CHAR(length=3), nullable=False),
        sa.Column("opening_balance_minor", sa.BigInteger(), server_default="0", nullable=False),
        sa.Column("sms_label", sa.Text(), nullable=True),
        sa.Column("status", sa.Text(), server_default="active", nullable=False),
        sa.Column("acting_admin_id", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
        sa.CheckConstraint(ACCOUNT_TYPE_CHECK, name=op.f("ck_personal_accounts_type")),
        sa.CheckConstraint(ACCOUNT_STATUS_CHECK, name=op.f("ck_personal_accounts_status")),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_personal_accounts_user_id_users")
        ),
        sa.ForeignKeyConstraint(
            ["acting_admin_id"],
            ["users.id"],
            name=op.f("fk_personal_accounts_acting_admin_id_users"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_personal_accounts")),
        sa.UniqueConstraint("id", "user_id", name=op.f("uq_personal_accounts_id")),
    )
    op.create_index(op.f("ix_personal_accounts_user_id"), ACCOUNTS, ["user_id"])
    op.create_index(
        "uq_personal_accounts_user_sms_label",
        ACCOUNTS,
        ["user_id", "sms_label"],
        unique=True,
        postgresql_where=sa.text("sms_label IS NOT NULL"),
    )

    for column in ("account_id", "transfer_group_id", "refund_of_id"):
        op.add_column(TXN, sa.Column(column, sa.Uuid(), nullable=True))
    op.add_column(TXN, sa.Column("direction", sa.Text(), nullable=True))
    op.execute(
        "UPDATE personal_transactions "
        "SET direction = CASE WHEN type = 'income' THEN 'in' ELSE 'out' END"
    )
    op.alter_column(TXN, "direction", nullable=False)

    _backfill_accounts(conn)

    op.create_unique_constraint(op.f("uq_personal_transactions_id"), TXN, ["id", "user_id"])
    op.create_foreign_key(
        op.f("fk_personal_transactions_account_id_personal_accounts"),
        TXN,
        ACCOUNTS,
        ["account_id", "user_id"],
        ["id", "user_id"],
    )
    op.create_foreign_key(
        op.f("fk_personal_transactions_refund_of_id_personal_transactions"),
        TXN,
        TXN,
        ["refund_of_id", "user_id"],
        ["id", "user_id"],
    )
    op.drop_constraint(op.f("ck_personal_transactions_type"), TXN, type_="check")
    op.create_check_constraint(op.f("ck_personal_transactions_type"), TXN, TYPE_CHECK)
    for name, condition in CHECKS:
        op.create_check_constraint(op.f(f"ck_personal_transactions_{name}"), TXN, condition)
    for column in INDEXED:
        op.create_index(
            op.f(f"ix_personal_transactions_{column}"),
            TXN,
            [column],
            postgresql_where=sa.text(f"{column} IS NOT NULL"),
        )
    op.execute(TRANSFER_CHECK)

    op.add_column("categories", sa.Column("kind", sa.Text(), nullable=True))
    op.create_check_constraint(
        op.f("ck_categories_kind"), "categories", "kind IN ('need', 'want', 'income')"
    )
    for key, kind in KINDS.items():
        if kind is not None:
            conn.execute(
                sa.text("UPDATE categories SET kind = :kind WHERE owner_id IS NULL AND key = :key"),
                {"kind": kind, "key": key},
            )


def downgrade() -> None:
    conn = op.get_bind()
    n = conn.scalar(
        sa.text("SELECT count(*) FROM personal_transactions WHERE type NOT IN ('income', 'expense')")
    )
    if n:
        raise RuntimeError(
            f"Can't downgrade: {n} personal entries (deleted ones included) are transfers, "
            "refunds, investments or corrections. Remove them first."
        )
    op.execute("DROP TRIGGER personal_transfer_pairs ON personal_transactions")
    op.execute("DROP FUNCTION check_personal_transfer()")

    op.drop_constraint(op.f("ck_categories_kind"), "categories", type_="check")
    op.drop_column("categories", "kind")

    for column in INDEXED:
        op.drop_index(op.f(f"ix_personal_transactions_{column}"), table_name=TXN)
    for name, _ in CHECKS:
        op.drop_constraint(op.f(f"ck_personal_transactions_{name}"), TXN, type_="check")
    op.drop_constraint(
        op.f("fk_personal_transactions_refund_of_id_personal_transactions"),
        TXN,
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_personal_transactions_account_id_personal_accounts"), TXN, type_="foreignkey"
    )
    op.drop_constraint(op.f("uq_personal_transactions_id"), TXN, type_="unique")
    for column in ("refund_of_id", "transfer_group_id", "direction", "account_id"):
        op.drop_column(TXN, column)
    op.drop_constraint(op.f("ck_personal_transactions_type"), TXN, type_="check")
    op.create_check_constraint(op.f("ck_personal_transactions_type"), TXN, OLD_TYPE_CHECK)

    op.drop_index("uq_personal_accounts_user_sms_label", table_name=ACCOUNTS)
    op.drop_index(op.f("ix_personal_accounts_user_id"), table_name=ACCOUNTS)
    op.drop_table(ACCOUNTS)
