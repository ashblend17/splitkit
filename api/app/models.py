"""Imports every module's models so SQLAlchemy metadata (and Alembic) sees all tables."""

from app.modules.admin.models import AdminSession, AuditLog
from app.modules.analytics.models import AnalyticsConfiguration
from app.modules.categories.models import Category
from app.modules.expenses.models import Expense, ExpenseSplit
from app.modules.groups.models import ActivityEvent, Group, GroupMember
from app.modules.import_tricount.models import ImportBatch
from app.modules.personal.models import PersonalTransaction
from app.modules.settlements.models import Settlement
from app.modules.sync.models import ChangeLog, SyncStream
from app.modules.users.models import User

__all__ = [
    "ActivityEvent",
    "ChangeLog",
    "AdminSession",
    "AnalyticsConfiguration",
    "AuditLog",
    "Category",
    "Expense",
    "ExpenseSplit",
    "Group",
    "GroupMember",
    "ImportBatch",
    "PersonalTransaction",
    "Settlement",
    "SyncStream",
    "User",
]
