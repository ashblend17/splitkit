"""`POST /personal/batch`: accounts, entries, goals, goal contributions, allocation rules and
plans, holdings, reminder decisions and reminder schedules made, changed or deleted in order,
all or none. An income and its plans, or a transfer and its contribution, go in one batch.

Each item is checked exactly as its own endpoint checks it, so an item can use what an earlier
item made (an account, an entry, a goal) but not what a later one makes. That includes the
no-double-counting check, after each item. Transfers are checked once every item is in, so a
transfer's legs can come in any order. A refusal names the item (`item`, counting from 0) and
nothing is kept: the transaction rolls back and the queued sync entries are dropped with it.
"""

import uuid

from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.modules.auth.deps import Actor
from app.modules.personal import (
    accounts,
    allocation_plans,
    allocation_rules,
    contributions,
    goals,
    holdings,
    reminder_schedules,
    reminder_states,
    service,
    transfers,
)
from app.modules.personal.models import (
    PersonalAccount,
    PersonalAllocationPlan,
    PersonalAllocationRule,
    PersonalGoal,
    PersonalGoalContribution,
    PersonalHolding,
    PersonalReminderSchedule,
    PersonalReminderState,
    PersonalTransaction,
)
from app.modules.personal.schemas import (
    PersonalAccountOut,
    PersonalAllocationPlanOut,
    PersonalAllocationRuleOut,
    PersonalBatchItem,
    PersonalBatchResult,
    PersonalGoalContributionOut,
    PersonalGoalOut,
    PersonalHoldingOut,
    PersonalReminderScheduleOut,
    PersonalReminderStateOut,
    PersonalTxnIn,
    PersonalTxnOut,
)


def _apply(session: Session, actor: Actor, item: PersonalBatchItem, touched: dict[uuid.UUID, bool]):
    payload = getattr(item, item.kind)
    if payload is not None:
        payload = payload.model_copy(update={"version": item.version})
    match item.kind, item.op:
        case "account", "create":
            return accounts.create(session, actor, payload.model_copy(update={"id": item.id}))
        case "account", _:
            return accounts.update(session, actor, item.id, payload)
        case "transaction", "create":
            return service.create(session, actor, payload, txn_id=item.id, touched=touched)
        case "transaction", "update":
            return service.update(session, actor, item.id, payload, touched)
        case "transaction", _:
            return service.change_deleted(session, actor, item.id, True, item.version, touched)
        case "goal", "create":
            return goals.create(session, actor, payload, goal_id=item.id)
        case "goal", "update":
            return goals.update(session, actor, item.id, payload)
        case "goal", _:
            return goals.change_deleted(session, actor, item.id, True, item.version)
        case "goal_contribution", "create":
            return contributions.create(session, actor, payload, contribution_id=item.id)
        case "goal_contribution", "update":
            return contributions.update(session, actor, item.id, payload)
        case "goal_contribution", _:
            return contributions.change_deleted(session, actor, item.id, True, item.version)
        case "allocation_rule", "create":
            return allocation_rules.create(session, actor, payload, rule_id=item.id)
        case "allocation_rule", "update":
            return allocation_rules.update(session, actor, item.id, payload)
        case "allocation_rule", _:
            return allocation_rules.change_deleted(session, actor, item.id, True, item.version)
        case "allocation_plan", "create":
            return allocation_plans.create(session, actor, payload, plan_id=item.id)
        case "allocation_plan", "update":
            return allocation_plans.update(session, actor, item.id, payload)
        case "allocation_plan", _:
            return allocation_plans.change_deleted(session, actor, item.id, True, item.version)
        case "holding", "create":
            return holdings.create(session, actor, payload, holding_id=item.id)
        case "holding", "update":
            return holdings.update(session, actor, item.id, payload)
        case "holding", _:
            return holdings.change_deleted(session, actor, item.id, True, item.version)
        case "reminder_state", "create":
            return reminder_states.upsert(session, actor, payload, state_id=item.id)[0]
        case "reminder_state", "update":
            return reminder_states.update(session, actor, item.id, payload)
        case "reminder_state", _:
            return reminder_states.change_deleted(session, actor, item.id, True, item.version)
        case "reminder_schedule", "create":
            return reminder_schedules.create(session, actor, payload, schedule_id=item.id)
        case "reminder_schedule", "update":
            return reminder_schedules.update(session, actor, item.id, payload)
        case _:
            return reminder_schedules.change_deleted(session, actor, item.id, True, item.version)


def _result(row, entries) -> PersonalBatchResult:
    match row:
        case PersonalTransaction():
            return PersonalBatchResult(kind="transaction", transaction=next(entries))
        case PersonalAccount():
            return PersonalBatchResult(
                kind="account", account=PersonalAccountOut.model_validate(row)
            )
        case PersonalGoal():
            return PersonalBatchResult(kind="goal", goal=PersonalGoalOut.model_validate(row))
        case PersonalGoalContribution():
            out = PersonalGoalContributionOut.model_validate(row)
            return PersonalBatchResult(kind="goal_contribution", goal_contribution=out)
        case PersonalAllocationRule():
            rule = PersonalAllocationRuleOut.model_validate(row)
            return PersonalBatchResult(kind="allocation_rule", allocation_rule=rule)
        case PersonalAllocationPlan():
            plan = PersonalAllocationPlanOut.model_validate(row)
            return PersonalBatchResult(kind="allocation_plan", allocation_plan=plan)
        case PersonalHolding():
            out = PersonalHoldingOut.model_validate(row)
            return PersonalBatchResult(kind="holding", holding=out)
        case PersonalReminderState():
            out = PersonalReminderStateOut.model_validate(row)
            return PersonalBatchResult(kind="reminder_state", reminder_state=out)
        case PersonalReminderSchedule():
            out = PersonalReminderScheduleOut.model_validate(row)
            return PersonalBatchResult(kind="reminder_schedule", reminder_schedule=out)


def run(
    session: Session, actor: Actor, items: list[PersonalBatchItem]
) -> list[PersonalBatchResult]:
    actor.require_write()
    touched: dict[uuid.UUID, bool] = {}
    first_item: dict[uuid.UUID, int] = {}
    rows = []
    for i, item in enumerate(items):
        try:
            rows.append(_apply(session, actor, item, touched))
            if item.kind in ("transaction", "goal", "goal_contribution") and item.op != "delete":
                changed = "goal" if item.kind == "goal" else "contribution"
                contributions.check_counted_once(session, actor.user_id, changed)
        except ApiError as e:
            e.extra["item"] = i
            raise
        for group in touched:
            first_item.setdefault(group, i)
    try:
        transfers.check_groups(session, actor.user_id, touched)
    except ApiError as e:
        e.extra["item"] = first_item[uuid.UUID(e.extra["transfer_group_id"])]
        raise
    session.commit()
    entries = iter(
        service.outs(session, actor, [r for r in rows if isinstance(r, PersonalTransaction)])
    )
    return [_result(r, entries) for r in rows]


def create_transactions(
    session: Session, actor: Actor, bodies: list[PersonalTxnIn]
) -> list[PersonalTxnOut]:
    """`POST /personal/transactions/batch`: a mixed batch of entry creates."""
    items = [
        PersonalBatchItem(kind="transaction", op="create", id=b.id or uuid.uuid4(), transaction=b)
        for b in bodies
    ]
    return [r.transaction for r in run(session, actor, items)]
