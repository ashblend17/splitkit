"""Allocation rules: what to set aside from each income, for a goal or an account. Only you see
them.

The server keeps rules and checks them; the app turns them into plans when you record an income
(allocation_plans.py) and warns when active percentages add up to more than 100%, never
rescaling them. A live rule always points somewhere money can go: a goal that counts
contributions (not archived) or an open account. So such a goal or account can't be deleted,
archived, switched to another mode or closed while a live rule points at it: the rule has to
change first (409 `rule_points_here`).
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ApiError, not_found
from app.core.events import record
from app.core.money import format_minor
from app.core.versioning import check_version, client_id, replayed_create
from app.modules.auth.deps import Actor
from app.modules.categories import repository as categories
from app.modules.personal.models import PersonalAccount, PersonalAllocationRule, PersonalGoal
from app.modules.personal.schemas import PersonalAllocationRuleIn, PersonalAllocationRuleOut

ENTITY = "personal_allocation_rule"
# Kept as they are when a PUT leaves them out (the destination and amounts are resolved apart).
KEPT = ("trigger", "source_category_id", "source_account_id", "active", "priority")


def describe(r: PersonalAllocationRule) -> str:
    """Its name, or what it does: "10% of each income"."""
    if r.name:
        return r.name
    if r.kind == "percentage":
        return f"{r.percent_bp / 100:g}% of each income"
    return f"{format_minor(r.amount_minor, r.currency)} from each income"


def _text(value: str | None) -> str | None:
    return (value or "").strip() or None


def _state(r: PersonalAllocationRule) -> dict:
    ids = ("source_category_id", "source_account_id", "goal_id", "account_id")
    return {
        "name": r.name,
        "trigger": r.trigger,
        "kind": r.kind,
        "percent_bp": r.percent_bp,
        "amount_minor": r.amount_minor,
        "active": r.active,
        "priority": r.priority,
        **{k: str(getattr(r, k)) if getattr(r, k) else None for k in ids},
    }


def list_rules(
    session: Session, actor: Actor, deleted: bool = False
) -> list[PersonalAllocationRuleOut]:
    """By priority, then oldest first; with `deleted`, only the deleted ones."""
    gone = PersonalAllocationRule.deleted_at.isnot(None)
    rows = session.scalars(
        select(PersonalAllocationRule)
        .where(PersonalAllocationRule.user_id == actor.user_id, gone if deleted else ~gone)
        .order_by(
            PersonalAllocationRule.priority,
            PersonalAllocationRule.created_at,
            PersonalAllocationRule.id,
        )
    )
    return [PersonalAllocationRuleOut.model_validate(r) for r in rows]


def load(session: Session, actor: Actor, rule_id: uuid.UUID) -> PersonalAllocationRule:
    r = session.get(PersonalAllocationRule, rule_id)
    if r is None or r.user_id != actor.user_id:
        raise not_found("Rule")
    return r


def get_rule(session: Session, actor: Actor, rule_id: uuid.UUID) -> PersonalAllocationRuleOut:
    return PersonalAllocationRuleOut.model_validate(load(session, actor, rule_id))


def _check_destination(
    session: Session,
    actor: Actor,
    goal_id: uuid.UUID | None,
    account_id: uuid.UUID | None,
    currency: str,
) -> None:
    """Somewhere money can go: a goal that counts contributions, or an open account. Plans
    are fulfilled by money reaching them, which a goal that follows a balance or is typed in
    never records."""
    if goal_id is not None:
        g = session.get(PersonalGoal, goal_id)
        if g is None or g.user_id != actor.user_id or g.deleted_at is not None:
            raise ApiError(422, "unknown_goal", "That goal isn't available")
        if g.status == "archived":
            raise ApiError(422, "goal_archived", f"{g.name} is archived")
        if g.tracking_mode == "linked_balance":
            raise ApiError(
                422,
                "goal_tracks_balance",
                f"{g.name} follows an account's balance: send the money to that account instead",
            )
        if g.tracking_mode == "manual":
            raise ApiError(
                422, "goal_is_manual", f"{g.name} is tracked by hand, so money can't go to it"
            )
        if g.currency != currency:
            raise ApiError(
                422,
                "currency_mismatch",
                f"That goal is in {g.currency}; this rule is in {currency}",
            )
        return
    a = session.get(PersonalAccount, account_id)
    if a is None or a.user_id != actor.user_id or a.deleted_at is not None:
        raise ApiError(422, "unknown_account", "That account isn't available")
    if a.status == "closed":
        raise ApiError(422, "account_closed", "That account is closed")
    if a.currency != currency:
        raise ApiError(
            422, "currency_mismatch", f"That account is in {a.currency}; this rule is in {currency}"
        )


def _check_sources(
    session: Session, actor: Actor, category_id: uuid.UUID | None, account_id: uuid.UUID | None
) -> None:
    if category_id and not categories.get_visible(session, category_id, actor.user_id, "personal"):
        raise ApiError(422, "unknown_category", "That category isn't available")
    if account_id is not None:
        a = session.get(PersonalAccount, account_id)
        if a is None or a.user_id != actor.user_id or a.deleted_at is not None:
            raise ApiError(422, "unknown_account", "That account isn't available")


def _given(body: PersonalAllocationRuleIn, r: PersonalAllocationRule | None) -> set[str]:
    return body.model_fields_set if r is not None else set(type(body).model_fields)


def _amounts(
    body: PersonalAllocationRuleIn, r: PersonalAllocationRule | None
) -> tuple[int | None, int | None]:
    """(percent_bp, amount_minor) for the body's kind: that kind's field is required; a value
    kept from the other kind is dropped, and one the body gives for it is refused."""
    given = _given(body, r)
    percent = body.percent_bp if "percent_bp" in given else r.percent_bp
    amount = body.amount_minor if "amount_minor" in given else r.amount_minor
    if body.kind == "percentage":
        if percent is None:
            raise ApiError(422, "percent_required", "Give the percentage")
        if amount is not None and "amount_minor" in given:
            raise ApiError(422, "amount_not_used", "A percentage rule has no fixed amount")
        return percent, None
    if amount is None:
        raise ApiError(422, "amount_required", "Give the amount")
    if percent is not None and "percent_bp" in given:
        raise ApiError(422, "percent_not_used", "A fixed rule has no percentage")
    return None, amount


def _destination(
    body: PersonalAllocationRuleIn, r: PersonalAllocationRule | None
) -> tuple[uuid.UUID | None, uuid.UUID | None]:
    """Exactly one of a goal and an account. On an update, giving one replaces the other."""
    given = _given(body, r)
    goal = body.goal_id if "goal_id" in given else r.goal_id
    account = body.account_id if "account_id" in given else r.account_id
    if goal is not None and account is not None:
        if "goal_id" in given and "account_id" not in given:
            account = None
        elif "account_id" in given and "goal_id" not in given:
            goal = None
        else:
            raise ApiError(
                422, "destination_invalid", "A rule sends money to a goal or an account, not both"
            )
    if goal is None and account is None:
        raise ApiError(422, "destination_required", "Pick the goal or account the money goes to")
    return goal, account


def create(
    session: Session,
    actor: Actor,
    body: PersonalAllocationRuleIn,
    rule_id: uuid.UUID | None = None,
) -> PersonalAllocationRule:
    """Recorded but not committed: the one a repeated create already made (deleted or not,
    unchanged), or a new one in your currency."""
    rule_id = rule_id or body.id
    replay = replayed_create(
        session, PersonalAllocationRule, rule_id, lambda r: r.user_id == actor.user_id
    )
    if replay is not None:
        return replay
    percent, amount = _amounts(body, None)
    goal, account = _destination(body, None)
    currency = actor.user.currency
    _check_destination(session, actor, goal, account, currency)
    _check_sources(session, actor, body.source_category_id, body.source_account_id)
    r = PersonalAllocationRule(
        **client_id(rule_id),
        user_id=actor.user_id,
        name=_text(body.name),
        trigger=body.trigger,
        source_category_id=body.source_category_id,
        source_account_id=body.source_account_id,
        kind=body.kind,
        percent_bp=percent,
        amount_minor=amount,
        currency=currency,
        goal_id=goal,
        account_id=account,
        active=body.active,
        priority=body.priority,
        acting_admin_id=actor.admin_id,
    )
    session.add(r)
    session.flush()
    record(session, actor, f"{ENTITY}.create", ENTITY, r.id, diff=_state(r), obj=r)
    return r


def update(
    session: Session, actor: Actor, rule_id: uuid.UUID, body: PersonalAllocationRuleIn
) -> PersonalAllocationRule:
    """The kind always (with its amount); anything else when the body has it. Existing plans
    keep their snapshot. Recorded but not committed."""
    r = load(session, actor, rule_id)
    if r.deleted_at is not None:
        raise ApiError(409, "deleted", "Restore this rule before editing it")
    check_version(r, body.version)
    percent, amount = _amounts(body, r)
    goal, account = _destination(body, r)
    if (goal, account) != (r.goal_id, r.account_id):
        _check_destination(session, actor, goal, account, r.currency)
    given = body.model_fields_set
    sources = {
        k: getattr(body, k) for k in ("source_category_id", "source_account_id") if k in given
    }
    changed = {k: v for k, v in sources.items() if v != getattr(r, k)}
    if changed:
        _check_sources(
            session, actor, changed.get("source_category_id"), changed.get("source_account_id")
        )
    before = _state(r)
    r.kind, r.percent_bp, r.amount_minor, r.goal_id, r.account_id = (
        body.kind,
        percent,
        amount,
        goal,
        account,
    )
    if "name" in given:
        r.name = _text(body.name)
    for key in KEPT:
        if key in given:
            setattr(r, key, getattr(body, key))
    after = _state(r)
    diff = {k: {"from": before[k], "to": after[k]} for k in before if before[k] != after[k]}
    if not diff:
        return r
    r.updated_at, r.acting_admin_id = datetime.now(UTC), actor.admin_id
    record(session, actor, f"{ENTITY}.update", ENTITY, r.id, diff=diff, obj=r)
    return r


def change_deleted(
    session: Session, actor: Actor, rule_id: uuid.UUID, deleted: bool, version: int | None
) -> PersonalAllocationRule:
    """Its plans stay as they are either way: they explain the incomes they were made for.
    Restoring needs its destination to still take money. Recorded but not committed."""
    r = load(session, actor, rule_id)
    if (r.deleted_at is not None) == deleted:
        return r
    check_version(r, version)
    if not deleted:
        _check_destination(session, actor, r.goal_id, r.account_id, r.currency)
    now = datetime.now(UTC)
    r.deleted_at = now if deleted else None
    r.updated_at, r.acting_admin_id = now, actor.admin_id
    action = "delete" if deleted else "restore"
    record(session, actor, f"{ENTITY}.{action}", ENTITY, r.id, obj=r)
    return r


def refuse_if_pointed_at(
    session: Session, what: str, *, goal_id: uuid.UUID | None = None, account_id=None
) -> None:
    """For a goal or account about to stop taking money (deleted, archived, switched to another
    mode, closed): refused while a live rule sends money there."""
    column = PersonalAllocationRule.goal_id if goal_id else PersonalAllocationRule.account_id
    r = session.scalar(
        select(PersonalAllocationRule)
        .where(column == (goal_id or account_id), PersonalAllocationRule.deleted_at.is_(None))
        .order_by(PersonalAllocationRule.created_at, PersonalAllocationRule.id)
        .limit(1)
    )
    if r is not None:
        raise ApiError(
            409,
            "rule_points_here",
            f"The rule “{describe(r)}” sends money to this {what}. Change or delete it first",
            rule_id=str(r.id),
        )


def create_rule(
    session: Session, actor: Actor, body: PersonalAllocationRuleIn
) -> PersonalAllocationRuleOut:
    actor.require_write()
    r = create(session, actor, body)
    session.commit()
    return PersonalAllocationRuleOut.model_validate(r)


def update_rule(
    session: Session, actor: Actor, rule_id: uuid.UUID, body: PersonalAllocationRuleIn
) -> PersonalAllocationRuleOut:
    actor.require_write()
    r = update(session, actor, rule_id, body)
    session.commit()
    return PersonalAllocationRuleOut.model_validate(r)


def set_deleted(
    session: Session, actor: Actor, rule_id: uuid.UUID, deleted: bool, version: int | None = None
) -> PersonalAllocationRuleOut:
    actor.require_write()
    r = change_deleted(session, actor, rule_id, deleted, version)
    session.commit()
    return PersonalAllocationRuleOut.model_validate(r)
