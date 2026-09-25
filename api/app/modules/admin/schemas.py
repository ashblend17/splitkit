import uuid
from datetime import datetime
from typing import Literal

from app.core.schemas import Schema
from app.modules.users.schemas import UserBrief, UserOut

Mode = Literal["read_only", "edit"]


class MoneyTotal(Schema):
    amount_minor: int
    currency: str


class GroupRef(Schema):
    id: uuid.UUID
    name: str


class AuditEntryOut(Schema):
    """One line of the audit log: who did what, and as whom."""

    id: uuid.UUID
    at: datetime
    action: str
    """Dotted key such as `expense.create` or `admin_session.start`."""
    entity: str
    entity_id: uuid.UUID | None
    actor: UserBrief | None
    """Who really did it. None for the system (the Tricount importer)."""
    acting_as: UserBrief | None
    """Set when an admin did it while viewing as this user."""
    done_as: Literal["user", "admin", "system"]
    """The "Done as" chip: `admin` whenever an admin acted as someone else."""
    summary: str
    """Human copy, e.g. "Added “Dinner at Thalassa” · ₹1,800"."""
    group: GroupRef | None
    diff: dict


class AuditPageOut(Schema):
    items: list[AuditEntryOut]
    total: int
    has_more: bool


class SystemOut(Schema):
    api_version: str
    database: str
    """e.g. "PostgreSQL 16.4"."""
    database_bytes: int
    last_import_at: datetime | None
    last_import_source: str | None


class AdminDashboardOut(Schema):
    users: int
    """Accounts that can log in. Placeholders (people without an account) are counted apart."""
    admins: int
    placeholders: int
    groups: int
    """Groups that aren't archived."""
    groups_active_week: int
    """Groups with any activity in the last 7 days."""
    expenses: int
    """Live (not deleted) expenses."""
    expenses_imported: int
    expense_volume: list[MoneyTotal]
    """Sum of live expenses, one entry per currency."""
    settlements: int
    settlement_volume: list[MoneyTotal]
    personal_transactions: int
    personal_users: int
    """How many users have personal transactions."""
    open_sessions: int
    """View-as sessions still open."""
    recent: list[AuditEntryOut]
    system: SystemOut


class AdminUserOut(Schema):
    id: uuid.UUID
    name: str
    email: str | None
    avatar_url: str | None
    role: str
    currency: str
    created_at: datetime
    is_placeholder: bool
    group_count: int
    """Groups they are a current member of."""
    expense_count: int
    """Live expenses they paid for or have a share in."""
    settlement_count: int
    personal_count: int
    balances: list[MoneyTotal]
    """Overall net across their groups, per currency. Positive: they are owed. Empty: square."""
    last_active_at: datetime | None
    """Their latest write as themselves (from the audit log)."""


class AdminUsersPageOut(Schema):
    items: list[AdminUserOut]
    total: int
    has_more: bool


class AdminSessionIn(Schema):
    target_user_id: uuid.UUID
    mode: Mode = "read_only"


class AdminSessionUpdate(Schema):
    mode: Mode


class AdminSessionOut(Schema):
    id: uuid.UUID
    admin: UserBrief
    target: UserBrief
    mode: Mode
    started_at: datetime
    ended_at: datetime | None
    expires_at: datetime | None
    active: bool
    """Open and not expired: its token still works."""


class AdminSessionsPageOut(Schema):
    items: list[AdminSessionOut]
    total: int
    has_more: bool


class AdminSessionStartOut(Schema):
    """Use `access_token` for every request made as `user`. Keep your own token to get back."""

    session: AdminSessionOut
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserOut
