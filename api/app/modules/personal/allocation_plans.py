"""Allocation plans: what a rule set aside from one income. A plan is an intention, never money
(spec §4.3): nothing here moves a goal or a balance.

The app makes a plan with its income, in the same request, with the id
ledger_rules.plan_id(income, rule), and recomputes it when the income changes. The server stores
what the app worked out without redoing the maths: it checks only that the income is a live
income of yours, that the rule is yours and not deleted, that the plan goes where the rule sends
money, and that there's one plan per income and rule, ever. Deleting or restoring an income takes
its plans with it (the same `deleted_at`, as for goal contributions); deleting a rule leaves them.
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy import exists, select
from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.versioning import check_version, client_id, replayed_create
from app.modules.auth.deps import Actor
from app.modules.personal.models import (
    PersonalAllocationPlan,
    PersonalAllocationRule,
    PersonalTransaction,
)
from app.modules.personal.schemas import PersonalAllocationPlanIn, PersonalAllocationPlanOut

ENTITY = "personal_allocation_plan"
FIXED = ("source_transaction_id", "rule_id", "goal_id", "account_id")
"""Set when a plan is made, never changed."""


def _state(p: PersonalAllocationPlan) -> dict:
    return {
        "snapshot_kind": p.snapshot_kind,
        "snapshot_percent_bp": p.snapshot_percent_bp,
        "snapshot_amount_minor": p.snapshot_amount_minor,
        "planned_minor": p.planned_minor,
    }


def list_plans(
    session: Session,
    actor: Actor,
    *,
    source_transaction_id: uuid.UUID | None = None,
    rule_id: uuid.UUID | None = None,
    goal_id: uuid.UUID | None = None,
    account_id: uuid.UUID | None = None,
    deleted: bool = False,
) -> list[PersonalAllocationPlanOut]:
    """Oldest first, which is the order contributions fill them in; with `deleted`, only the
    deleted ones (cancelled with their income, or deleted)."""
    gone = PersonalAllocationPlan.deleted_at.isnot(None)
    q = select(PersonalAllocationPlan).where(
        PersonalAllocationPlan.user_id == actor.user_id, gone if deleted else ~gone
    )
    for column, value in (
        (PersonalAllocationPlan.source_transaction_id, source_transaction_id),
        (PersonalAllocationPlan.rule_id, rule_id),
        (PersonalAllocationPlan.goal_id, goal_id),
        (PersonalAllocationPlan.account_id, account_id),
    ):
        if value is not None:
            q = q.where(column == value)
    q = q.order_by(PersonalAllocationPlan.created_at, PersonalAllocationPlan.id)
    return [PersonalAllocationPlanOut.model_validate(p) for p in session.scalars(q)]


def _load(session: Session, actor: Actor, plan_id: uuid.UUID) -> PersonalAllocationPlan:
    p = session.get(PersonalAllocationPlan, plan_id)
    if p is None or p.user_id != actor.user_id:
        raise not_found("Plan")
    return p


def get_plan(session: Session, actor: Actor, plan_id: uuid.UUID) -> PersonalAllocationPlanOut:
    return PersonalAllocationPlanOut.model_validate(_load(session, actor, plan_id))


def _check_snapshot(body: PersonalAllocationPlanIn) -> None:
    percentage = body.snapshot_kind == "percentage"
    if percentage != (body.snapshot_percent_bp is not None) or percentage == (
        body.snapshot_amount_minor is not None
    ):
        raise ApiError(
            422,
            "snapshot_invalid",
            "A percentage plan records the percentage, and a fixed one the amount",
        )


def _check_income(session: Session, actor: Actor, txn_id: uuid.UUID) -> PersonalTransaction:
    t = session.get(PersonalTransaction, txn_id)
    if t is None or t.user_id != actor.user_id or t.deleted_at is not None or t.type != "income":
        raise ApiError(422, "unknown_income", "That income isn't available")
    if t.currency != actor.user.currency:
        raise ApiError(
            422,
            "currency_mismatch",
            f"That income is in {t.currency}; your entries are in {actor.user.currency}",
        )
    return t


def create(
    session: Session,
    actor: Actor,
    body: PersonalAllocationPlanIn,
    plan_id: uuid.UUID | None = None,
) -> PersonalAllocationPlan:
    """Recorded but not committed: the one a repeated create already made (deleted or not,
    unchanged), or a new one in the income's currency."""
    plan_id = plan_id or body.id
    replay = replayed_create(
        session, PersonalAllocationPlan, plan_id, lambda p: p.user_id == actor.user_id
    )
    if replay is not None:
        return replay
    if (
        body.source_transaction_id is None
        or body.rule_id is None
        or (body.goal_id is None) == (body.account_id is None)
    ):
        raise ApiError(
            422, "plan_incomplete", "A plan needs its income, its rule and one destination"
        )
    income = _check_income(session, actor, body.source_transaction_id)
    rule = session.get(PersonalAllocationRule, body.rule_id)
    if rule is None or rule.user_id != actor.user_id:
        raise ApiError(422, "unknown_rule", "That rule isn't available")
    if rule.deleted_at is not None:
        raise ApiError(422, "unknown_rule", "That rule was deleted, so it makes no new plans")
    if (body.goal_id, body.account_id) != (rule.goal_id, rule.account_id):
        raise ApiError(422, "destination_mismatch", "A plan goes where its rule sends money")
    existing = session.scalar(
        select(PersonalAllocationPlan).where(
            PersonalAllocationPlan.source_transaction_id == income.id,
            PersonalAllocationPlan.rule_id == rule.id,
        )
    )
    if existing is not None:
        raise ApiError(
            409,
            "plan_exists",
            "This income already has a plan from that rule",
            plan_id=str(existing.id),
        )
    _check_snapshot(body)
    p = PersonalAllocationPlan(
        **client_id(plan_id),
        user_id=actor.user_id,
        source_transaction_id=income.id,
        rule_id=rule.id,
        snapshot_kind=body.snapshot_kind,
        snapshot_percent_bp=body.snapshot_percent_bp,
        snapshot_amount_minor=body.snapshot_amount_minor,
        planned_minor=body.planned_minor,
        currency=income.currency,
        goal_id=body.goal_id,
        account_id=body.account_id,
        acting_admin_id=actor.admin_id,
    )
    session.add(p)
    session.flush()
    diff = {
        "source_transaction_id": str(p.source_transaction_id),
        "rule_id": str(p.rule_id),
        "planned_minor": p.planned_minor,
    }
    record(session, actor, f"{ENTITY}.create", ENTITY, p.id, diff=diff, obj=p)
    return p


def update(
    session: Session, actor: Actor, plan_id: uuid.UUID, body: PersonalAllocationPlanIn
) -> PersonalAllocationPlan:
    """A recomputed snapshot and amount. The income, rule and destination stay. Recorded but
    not committed."""
    p = _load(session, actor, plan_id)
    if p.deleted_at is not None:
        raise ApiError(409, "deleted", "Restore this plan before editing it")
    check_version(p, body.version)
    for key in FIXED:
        if key in body.model_fields_set and getattr(body, key) != getattr(p, key):
            raise ApiError(422, "plan_fixed", "A plan's income, rule and destination don't change")
    _check_snapshot(body)
    before = _state(p)
    p.snapshot_kind, p.snapshot_percent_bp = body.snapshot_kind, body.snapshot_percent_bp
    p.snapshot_amount_minor, p.planned_minor = body.snapshot_amount_minor, body.planned_minor
    after = _state(p)
    diff = {k: {"from": before[k], "to": after[k]} for k in before if before[k] != after[k]}
    if not diff:
        return p
    p.updated_at, p.acting_admin_id = datetime.now(UTC), actor.admin_id
    record(session, actor, f"{ENTITY}.update", ENTITY, p.id, diff=diff, obj=p)
    return p


def change_deleted(
    session: Session, actor: Actor, plan_id: uuid.UUID, deleted: bool, version: int | None
) -> PersonalAllocationPlan:
    """Restoring needs its income to be a live income again. Recorded but not committed."""
    p = _load(session, actor, plan_id)
    if (p.deleted_at is not None) == deleted:
        return p
    check_version(p, version)
    if not deleted:
        income = session.get(PersonalTransaction, p.source_transaction_id)
        if income.deleted_at is not None or income.type != "income":
            raise ApiError(
                422,
                "unknown_income",
                "This plan's income was deleted or changed. Restore it first",
            )
    now = datetime.now(UTC)
    p.deleted_at = now if deleted else None
    p.updated_at, p.acting_admin_id = now, actor.admin_id
    action = "delete" if deleted else "restore"
    record(session, actor, f"{ENTITY}.{action}", ENTITY, p.id, obj=p)
    return p


def follow_income(
    session: Session, actor: Actor, t: PersonalTransaction, deleted: bool, at: datetime
) -> None:
    """The entry was just deleted at `at`, or is being restored from a delete at `at`: its live
    plans are cancelled with it, or the ones cancelled with it come back."""
    q = select(PersonalAllocationPlan).where(PersonalAllocationPlan.source_transaction_id == t.id)
    q = q.where(
        PersonalAllocationPlan.deleted_at.is_(None)
        if deleted
        else PersonalAllocationPlan.deleted_at == at
    )
    for p in session.scalars(q).all():
        p.deleted_at = at if deleted else None
        p.updated_at, p.acting_admin_id = datetime.now(UTC), actor.admin_id
        action = "delete" if deleted else "restore"
        record(session, actor, f"{ENTITY}.{action}", ENTITY, p.id, obj=p)


def has_live_plans(session: Session, t: PersonalTransaction) -> bool:
    return bool(
        session.scalar(
            select(
                exists().where(
                    PersonalAllocationPlan.source_transaction_id == t.id,
                    PersonalAllocationPlan.deleted_at.is_(None),
                )
            )
        )
    )


def create_plan(
    session: Session, actor: Actor, body: PersonalAllocationPlanIn
) -> PersonalAllocationPlanOut:
    actor.require_write()
    p = create(session, actor, body)
    session.commit()
    return PersonalAllocationPlanOut.model_validate(p)


def update_plan(
    session: Session, actor: Actor, plan_id: uuid.UUID, body: PersonalAllocationPlanIn
) -> PersonalAllocationPlanOut:
    actor.require_write()
    p = update(session, actor, plan_id, body)
    session.commit()
    return PersonalAllocationPlanOut.model_validate(p)


def set_deleted(
    session: Session, actor: Actor, plan_id: uuid.UUID, deleted: bool, version: int | None = None
) -> PersonalAllocationPlanOut:
    actor.require_write()
    p = change_deleted(session, actor, plan_id, deleted, version)
    session.commit()
    return PersonalAllocationPlanOut.model_validate(p)
