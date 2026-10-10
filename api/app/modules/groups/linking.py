"""Linking a placeholder member to a real account.

- The account exists: `merge()` moves the placeholder's place in each of its groups to the
  account (membership, expenses paid, shares, payments). Everyone's balance stays the same; the
  account's becomes its own plus the placeholder's.
- No account yet: the email is kept on the membership (`invite_email`). Signing up with it calls
  `claim()`, which turns the placeholder into the new account, so nothing has to move.

A merged placeholder is retired, not deleted: its memberships end and nothing points at it any
more except payments between it and the account, which are deleted (they net to zero).
"""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.events import record
from app.modules.auth.deps import Actor
from app.modules.expenses.models import Expense, ExpenseSplit
from app.modules.groups.models import GroupMember
from app.modules.settlements.models import Settlement
from app.modules.users.models import User


def merge(session: Session, actor: Actor, placeholder: User, account: User) -> None:
    """Give `placeholder`'s place in every group it is in to `account`. Doesn't commit."""
    assert placeholder.email is None and account.email is not None
    now = datetime.now(UTC)
    memberships = session.scalars(
        select(GroupMember).where(GroupMember.user_id == placeholder.id)
    ).all()
    for old in memberships:
        changed = [
            *_move_expenses(session, old.group_id, placeholder.id, account.id, now),
            *_move_settlements(session, old.group_id, placeholder.id, account.id, now),
        ]
        new = session.get(GroupMember, (old.group_id, account.id))
        if new is None:
            new = GroupMember(
                group_id=old.group_id,
                user_id=account.id,
                role=old.role,
                joined_at=old.joined_at,
                left_at=old.left_at,
                placeholder_name=old.placeholder_name or placeholder.name,
                import_batch_id=old.import_batch_id,
            )
            session.add(new)
        else:
            if old.left_at is None:
                new.left_at = None
            new.placeholder_name = new.placeholder_name or old.placeholder_name or placeholder.name
        if old.left_at is None:
            old.left_at = now
        old.invite_email = None
        record(
            session,
            actor,
            "member.link",
            "group",
            old.group_id,
            old.group_id,
            {"placeholder_id": str(placeholder.id), "user_id": str(account.id)},
            obj=[*changed, old, new],
        )


def _move_expenses(
    session: Session, group_id: uuid.UUID, old: uuid.UUID, new: uuid.UUID, now: datetime
) -> list[Expense]:
    """Deleted expenses too, so restoring one later still works."""
    shared = select(ExpenseSplit.expense_id).where(ExpenseSplit.user_id == old)
    expenses = session.scalars(
        select(Expense)
        .options(selectinload(Expense.splits))
        .where(Expense.group_id == group_id, or_(Expense.payer_id == old, Expense.id.in_(shared)))
        .order_by(Expense.created_at)
    ).all()
    for e in expenses:
        if e.payer_id == old:
            e.payer_id = new
        theirs = next((s for s in e.splits if s.user_id == old), None)
        mine = next((s for s in e.splits if s.user_id == new), None)
        if theirs is not None and mine is None:
            theirs.user_id = new
        elif theirs is not None:
            # Both were in the split: one share now. The method's inputs no longer describe
            # it (two equal shares aren't "equal" any more), so it becomes an exact split.
            mine.share_minor += theirs.share_minor
            e.splits.remove(theirs)
            e.split_method = "exact"
            for s in e.splits:
                s.input_value = Decimal(s.share_minor)
        e.updated_at = now  # bumps the version, so a stale edit from a device gets a 409
    return list(expenses)


def _move_settlements(
    session: Session, group_id: uuid.UUID, old: uuid.UUID, new: uuid.UUID, now: datetime
) -> list[Settlement]:
    settlements = session.scalars(
        select(Settlement).where(
            Settlement.group_id == group_id,
            or_(Settlement.from_user == old, Settlement.to_user == old),
        )
    ).all()
    for s in settlements:
        if new in (s.from_user, s.to_user):
            # A payment between the two would be from someone to themselves. It moved nothing
            # once they are one person, so it goes (it keeps pointing at the placeholder).
            s.deleted_at = s.deleted_at or now
            continue
        if s.from_user == old:
            s.from_user = new
        else:
            s.to_user = new
    return list(settlements)


def invited(session: Session, email: str) -> list[GroupMember]:
    """Current placeholder memberships waiting for an account with this email, oldest first."""
    return list(
        session.scalars(
            select(GroupMember)
            .join(User, User.id == GroupMember.user_id)
            .where(
                GroupMember.invite_email == email.lower(),
                GroupMember.left_at.is_(None),
                User.email.is_(None),
            )
            .order_by(GroupMember.joined_at, GroupMember.group_id)
        )
    )


def claim(session: Session, user: User, waiting: list[GroupMember]) -> None:
    """`user` (a placeholder with the new account's details already set) signed up with an
    invited email. Other placeholders invited with the same email merge into it. Doesn't
    commit."""
    actor = Actor(user=user)
    mine = session.scalars(select(GroupMember).where(GroupMember.user_id == user.id)).all()
    for m in mine:
        m.invite_email = None
    session.flush()
    record(session, actor, "user.claim", "user", user.id, obj=[user, *mine])
    for other_id in dict.fromkeys(m.user_id for m in waiting if m.user_id != user.id):
        merge(session, actor, session.get(User, other_id), user)
