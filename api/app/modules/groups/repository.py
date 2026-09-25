import uuid
from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.expenses.models import Expense
from app.modules.groups.models import ActivityEvent, Group, GroupMember
from app.modules.users.models import User


def membership(session: Session, group_id: uuid.UUID, user_id: uuid.UUID) -> GroupMember | None:
    return session.get(GroupMember, (group_id, user_id))


def active_members(session: Session, group_id: uuid.UUID) -> list[tuple[GroupMember, User]]:
    rows = session.execute(
        select(GroupMember, User)
        .join(User, User.id == GroupMember.user_id)
        .where(GroupMember.group_id == group_id, GroupMember.left_at.is_(None))
        .order_by(GroupMember.joined_at, User.name)
    )
    return [(m, u) for m, u in rows]


def groups_for_user(
    session: Session, user_id: uuid.UUID, include_left: bool = False
) -> list[Group]:
    query = (
        select(Group)
        .join(GroupMember, GroupMember.group_id == Group.id)
        .where(GroupMember.user_id == user_id)
        .order_by(Group.created_at.desc())
    )
    if not include_left:
        query = query.where(GroupMember.left_at.is_(None))
    return list(session.scalars(query))


def total_spent(session: Session, group_ids: list[uuid.UUID]) -> dict[uuid.UUID, int]:
    rows = session.execute(
        select(Expense.group_id, func.sum(Expense.amount_minor))
        .where(Expense.group_id.in_(group_ids), Expense.deleted_at.is_(None))
        .group_by(Expense.group_id)
    )
    return {gid: int(total) for gid, total in rows}


def last_activity(session: Session, group_ids: list[uuid.UUID]) -> dict[uuid.UUID, datetime]:
    rows = session.execute(
        select(ActivityEvent.group_id, func.max(ActivityEvent.at))
        .where(ActivityEvent.group_id.in_(group_ids))
        .group_by(ActivityEvent.group_id)
    )
    return {gid: at for gid, at in rows}
