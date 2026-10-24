import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query, Response

from app.modules.auth.deps import CurrentActor, DbSession
from app.modules.personal import (
    accounts,
    allocation_plans,
    allocation_rules,
    batch,
    contributions,
    goals,
    holdings,
    reminder_schedules,
    reminder_states,
    service,
)
from app.modules.personal.schemas import (
    AccountOut,
    Channel,
    PersonalAccountIn,
    PersonalAccountOut,
    PersonalAllocationPlanIn,
    PersonalAllocationPlanOut,
    PersonalAllocationRuleIn,
    PersonalAllocationRuleOut,
    PersonalBatchIn,
    PersonalBatchOut,
    PersonalGoalContributionIn,
    PersonalGoalContributionOut,
    PersonalGoalIn,
    PersonalGoalOut,
    PersonalHoldingIn,
    PersonalHoldingOut,
    PersonalListOut,
    PersonalMixedBatchIn,
    PersonalMixedBatchOut,
    PersonalReminderScheduleIn,
    PersonalReminderScheduleOut,
    PersonalReminderStateIn,
    PersonalReminderStateOut,
    PersonalSummaryOut,
    PersonalTxnIn,
    PersonalTxnOut,
    Source,
    TxnType,
)

router = APIRouter(prefix="/personal", tags=["personal"])


@router.get("/transactions", response_model=PersonalListOut)
def list_personal(
    actor: CurrentActor,
    session: DbSession,
    start: date | None = None,
    end: date | None = None,
    type: TxnType | None = None,
    category: Annotated[list[str] | None, Query(description="Category keys, repeatable")] = None,
    deleted: bool = False,
    account: Annotated[str | None, Query(description='As labelled, e.g. "HDFC ··4821"')] = None,
    account_id: Annotated[
        uuid.UUID | None,
        Query(description="An account, with the accounts linked to it (their entries count in it)"),
    ] = None,
    channel: Channel | None = None,
    source: Source | None = None,
    reviewed: bool | None = None,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
):
    """Your own entries (only you see these), newest first, with totals: `spent_minor` is
    expenses minus refunds; transfers, adjustments and investments aren't spending.
    `reviewed=false&source=sms` is what the app shows as "Just in"."""
    return service.list_transactions(
        session,
        actor,
        start=start,
        end=end,
        type=type,
        category_keys=category,
        deleted=deleted,
        limit=limit,
        offset=offset,
        account=account,
        account_id=account_id,
        channel=channel,
        source=source,
        reviewed=reviewed,
    )


@router.get("/accounts", response_model=list[PersonalAccountOut])
def list_personal_accounts(actor: CurrentActor, session: DbSession, deleted: bool = False):
    """Your accounts, active and closed, oldest first (`deleted=true`: the deleted ones, for
    restoring). No balances: the app derives them from each account's opening balance and the
    entries in it."""
    return accounts.list_accounts(session, actor, deleted)


@router.get("/accounts/reported", response_model=list[AccountOut])
def personal_reported_accounts(actor: CurrentActor, session: DbSession):
    """The account labels your entries carry, most recently used first, each with the latest
    balance its bank reported. Kept until the app stops using `/personal/summary`."""
    return service.reported_accounts(session, actor)


@router.post("/accounts", response_model=PersonalAccountOut, status_code=201)
def create_personal_account(body: PersonalAccountIn, actor: CurrentActor, session: DbSession):
    """In your currency. A repeated id gives back the account it already made. With an
    `sms_label`, your entries with that label and no account move into it."""
    return accounts.create_account(session, actor, body)


@router.get("/accounts/{account_id}", response_model=PersonalAccountOut)
def get_personal_account(account_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return accounts.get_account(session, actor, account_id)


@router.put("/accounts/{account_id}", response_model=PersonalAccountOut)
def update_personal_account(
    account_id: uuid.UUID, body: PersonalAccountIn, actor: CurrentActor, session: DbSession
):
    """`status: closed` closes it: it takes no new entries and still counts in net worth.
    A new `sms_label` moves in your entries with that label and no account."""
    return accounts.update_account(session, actor, account_id, body)


@router.delete("/accounts/{account_id}", response_model=PersonalAccountOut)
def delete_personal_account(
    account_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    """Only while no entry is in it (409 `account_in_use`): close it instead."""
    return accounts.set_deleted(session, actor, account_id, deleted=True, version=version)


@router.post("/accounts/{account_id}/restore", response_model=PersonalAccountOut)
def restore_personal_account(
    account_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return accounts.set_deleted(session, actor, account_id, deleted=False, version=version)


@router.get("/summary", response_model=PersonalSummaryOut)
def personal_summary(actor: CurrentActor, session: DbSession, month: date | None = None):
    """One month at a glance. `month` is any date inside it (default: this month)."""
    return service.summary(session, actor, month or date.today())


@router.post("/transactions", response_model=PersonalTxnOut, status_code=201)
def create_personal(body: PersonalTxnIn, actor: CurrentActor, session: DbSession):
    return service.create_transaction(session, actor, body)


@router.post("/transactions/batch", response_model=PersonalBatchOut, status_code=201)
def create_personal_batch(body: PersonalBatchIn, actor: CurrentActor, session: DbSession):
    """Up to 100 entries in one request, all or none. A repeated id (a retry, a bank SMS read
    again) gives back the entry it already made, deleted or not."""
    return PersonalBatchOut(items=batch.create_transactions(session, actor, body.items))


@router.post("/batch", response_model=PersonalMixedBatchOut, status_code=201)
def apply_personal_batch(body: PersonalMixedBatchIn, actor: CurrentActor, session: DbSession):
    """Up to 100 account and entry creates, updates and entry deletes, applied in order, all or
    none. A transfer's two legs go in one batch. A repeated create gives back what it already
    made; a stale update gets a 409 and nothing is applied. A refusal says which `item`."""
    return PersonalMixedBatchOut(items=batch.run(session, actor, body.items))


@router.get("/transactions/{txn_id}", response_model=PersonalTxnOut)
def get_personal(txn_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return service.get_transaction(session, actor, txn_id)


@router.put("/transactions/{txn_id}", response_model=PersonalTxnOut)
def update_personal(
    txn_id: uuid.UUID, body: PersonalTxnIn, actor: CurrentActor, session: DbSession
):
    return service.update_transaction(session, actor, txn_id, body)


@router.delete("/transactions/{txn_id}", response_model=PersonalTxnOut)
def delete_personal(
    txn_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return service.set_deleted(session, actor, txn_id, deleted=True, version=version)


@router.post("/transactions/{txn_id}/restore", response_model=PersonalTxnOut)
def restore_personal(
    txn_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return service.set_deleted(session, actor, txn_id, deleted=False, version=version)


@router.get("/goals", response_model=list[PersonalGoalOut])
def list_personal_goals(actor: CurrentActor, session: DbSession, deleted: bool = False):
    """Your goals by priority, then oldest first (`deleted=true`: the deleted ones). No
    progress: the app derives it from the source each goal's `tracking_mode` names."""
    return goals.list_goals(session, actor, deleted)


@router.post("/goals", response_model=PersonalGoalOut, status_code=201)
def create_personal_goal(body: PersonalGoalIn, actor: CurrentActor, session: DbSession):
    """In your currency. A repeated id gives back the goal it already made."""
    return goals.create_goal(session, actor, body)


@router.get("/goals/{goal_id}", response_model=PersonalGoalOut)
def get_personal_goal(goal_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return goals.get_goal(session, actor, goal_id)


@router.put("/goals/{goal_id}", response_model=PersonalGoalOut)
def update_personal_goal(
    goal_id: uuid.UUID, body: PersonalGoalIn, actor: CurrentActor, session: DbSession
):
    """Fields left out keep their value (`status`: null keeps it too). Switching
    `tracking_mode` needs that mode's field, and drops the old mode's."""
    return goals.update_goal(session, actor, goal_id, body)


@router.delete("/goals/{goal_id}", response_model=PersonalGoalOut)
def delete_personal_goal(
    goal_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    """Its contributions go with it, and come back when it's restored."""
    return goals.set_deleted(session, actor, goal_id, deleted=True, version=version)


@router.post("/goals/{goal_id}/restore", response_model=PersonalGoalOut)
def restore_personal_goal(
    goal_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return goals.set_deleted(session, actor, goal_id, deleted=False, version=version)


@router.get("/goal-contributions", response_model=list[PersonalGoalContributionOut])
def list_goal_contributions(
    actor: CurrentActor,
    session: DbSession,
    goal_id: uuid.UUID | None = None,
    deleted: bool = False,
):
    """Newest first, of one goal or all (`deleted=true`: the deleted ones)."""
    return contributions.list_contributions(session, actor, goal_id, deleted)


@router.post("/goal-contributions", response_model=PersonalGoalContributionOut, status_code=201)
def create_goal_contribution(
    body: PersonalGoalContributionIn, actor: CurrentActor, session: DbSession
):
    """To a goal that counts contributions. With `transaction_id`, the entry that moved the
    money: it counts towards one goal at most, and not if it moves an account a goal follows by
    balance (422 `counted_by_balance`)."""
    return contributions.create_contribution(session, actor, body)


@router.get("/goal-contributions/{contribution_id}", response_model=PersonalGoalContributionOut)
def get_goal_contribution(contribution_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return contributions.get_contribution(session, actor, contribution_id)


@router.put("/goal-contributions/{contribution_id}", response_model=PersonalGoalContributionOut)
def update_goal_contribution(
    contribution_id: uuid.UUID,
    body: PersonalGoalContributionIn,
    actor: CurrentActor,
    session: DbSession,
):
    """`transaction_id` and `note` keep their value when left out."""
    return contributions.update_contribution(session, actor, contribution_id, body)


@router.delete("/goal-contributions/{contribution_id}", response_model=PersonalGoalContributionOut)
def delete_goal_contribution(
    contribution_id: uuid.UUID,
    actor: CurrentActor,
    session: DbSession,
    version: int | None = None,
):
    return contributions.set_deleted(session, actor, contribution_id, True, version)


@router.post(
    "/goal-contributions/{contribution_id}/restore", response_model=PersonalGoalContributionOut
)
def restore_goal_contribution(
    contribution_id: uuid.UUID,
    actor: CurrentActor,
    session: DbSession,
    version: int | None = None,
):
    return contributions.set_deleted(session, actor, contribution_id, False, version)


@router.get("/allocation-rules", response_model=list[PersonalAllocationRuleOut])
def list_allocation_rules(actor: CurrentActor, session: DbSession, deleted: bool = False):
    """Your rules by priority, then oldest first (`deleted=true`: the deleted ones). Whether
    active percentages add up to more than 100% is the app's to say."""
    return allocation_rules.list_rules(session, actor, deleted)


@router.post("/allocation-rules", response_model=PersonalAllocationRuleOut, status_code=201)
def create_allocation_rule(body: PersonalAllocationRuleIn, actor: CurrentActor, session: DbSession):
    """To a goal that counts contributions or an open account, in your currency. A repeated id
    gives back the rule it already made."""
    return allocation_rules.create_rule(session, actor, body)


@router.get("/allocation-rules/{rule_id}", response_model=PersonalAllocationRuleOut)
def get_allocation_rule(rule_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return allocation_rules.get_rule(session, actor, rule_id)


@router.put("/allocation-rules/{rule_id}", response_model=PersonalAllocationRuleOut)
def update_allocation_rule(
    rule_id: uuid.UUID, body: PersonalAllocationRuleIn, actor: CurrentActor, session: DbSession
):
    """Fields left out keep their value. Existing plans keep the snapshot they were made with."""
    return allocation_rules.update_rule(session, actor, rule_id, body)


@router.delete("/allocation-rules/{rule_id}", response_model=PersonalAllocationRuleOut)
def delete_allocation_rule(
    rule_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    """Its plans stay, but it makes no new ones."""
    return allocation_rules.set_deleted(session, actor, rule_id, True, version)


@router.post("/allocation-rules/{rule_id}/restore", response_model=PersonalAllocationRuleOut)
def restore_allocation_rule(
    rule_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return allocation_rules.set_deleted(session, actor, rule_id, False, version)


@router.get("/allocation-plans", response_model=list[PersonalAllocationPlanOut])
def list_allocation_plans(
    actor: CurrentActor,
    session: DbSession,
    source_transaction_id: uuid.UUID | None = None,
    rule_id: uuid.UUID | None = None,
    goal_id: uuid.UUID | None = None,
    account_id: uuid.UUID | None = None,
    deleted: bool = False,
):
    """Oldest first (`deleted=true`: cancelled with their income, or deleted). No status: the
    app works out planned, partial, fulfilled or cancelled."""
    return allocation_plans.list_plans(
        session,
        actor,
        source_transaction_id=source_transaction_id,
        rule_id=rule_id,
        goal_id=goal_id,
        account_id=account_id,
        deleted=deleted,
    )


@router.post("/allocation-plans", response_model=PersonalAllocationPlanOut, status_code=201)
def create_allocation_plan(body: PersonalAllocationPlanIn, actor: CurrentActor, session: DbSession):
    """Usually sent with its income in one `POST /personal/batch`. One plan per income and
    rule: the same id gives back the plan, another id gets 409 `plan_exists`."""
    return allocation_plans.create_plan(session, actor, body)


@router.get("/allocation-plans/{plan_id}", response_model=PersonalAllocationPlanOut)
def get_allocation_plan(plan_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return allocation_plans.get_plan(session, actor, plan_id)


@router.put("/allocation-plans/{plan_id}", response_model=PersonalAllocationPlanOut)
def update_allocation_plan(
    plan_id: uuid.UUID, body: PersonalAllocationPlanIn, actor: CurrentActor, session: DbSession
):
    """A recomputed snapshot and amount (after its income changed)."""
    return allocation_plans.update_plan(session, actor, plan_id, body)


@router.delete("/allocation-plans/{plan_id}", response_model=PersonalAllocationPlanOut)
def delete_allocation_plan(
    plan_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return allocation_plans.set_deleted(session, actor, plan_id, True, version)


@router.post("/allocation-plans/{plan_id}/restore", response_model=PersonalAllocationPlanOut)
def restore_allocation_plan(
    plan_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return allocation_plans.set_deleted(session, actor, plan_id, False, version)


@router.get("/holdings", response_model=list[PersonalHoldingOut])
def list_personal_holdings(
    actor: CurrentActor,
    session: DbSession,
    account_id: uuid.UUID | None = None,
    deleted: bool = False,
):
    """Oldest first, of one account or all (`deleted=true`: the deleted ones). No gains or
    stale flags: the app works those out."""
    return holdings.list_holdings(session, actor, account_id, deleted)


@router.post("/holdings", response_model=PersonalHoldingOut, status_code=201)
def create_personal_holding(body: PersonalHoldingIn, actor: CurrentActor, session: DbSession):
    """In an open investment account of yours. A repeated id gives back the holding it made."""
    return holdings.create_holding(session, actor, body)


@router.get("/holdings/{holding_id}", response_model=PersonalHoldingOut)
def get_personal_holding(holding_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return holdings.get_holding(session, actor, holding_id)


@router.put("/holdings/{holding_id}", response_model=PersonalHoldingOut)
def update_personal_holding(
    holding_id: uuid.UUID, body: PersonalHoldingIn, actor: CurrentActor, session: DbSession
):
    """ "Update value": the valuation is replaced (only the latest is kept). The account,
    quantity and cost basis keep their value when left out."""
    return holdings.update_holding(session, actor, holding_id, body)


@router.delete("/holdings/{holding_id}", response_model=PersonalHoldingOut)
def delete_personal_holding(
    holding_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    """Refused while a live entry names it (409 `holding_in_use`). Its SIP reminders go with
    it, and come back when it's restored."""
    return holdings.set_deleted(session, actor, holding_id, True, version)


@router.post("/holdings/{holding_id}/restore", response_model=PersonalHoldingOut)
def restore_personal_holding(
    holding_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return holdings.set_deleted(session, actor, holding_id, False, version)


@router.get("/reminder-states", response_model=list[PersonalReminderStateOut])
def list_reminder_states(actor: CurrentActor, session: DbSession, deleted: bool = False):
    """Your decisions on reminders (`deleted=true`: the ones taken back)."""
    return reminder_states.list_states(session, actor, deleted)


@router.post(
    "/reminder-states",
    response_model=PersonalReminderStateOut,
    status_code=201,
    responses={200: {"model": PersonalReminderStateOut, "description": "Replaced"}},
)
def save_reminder_state(
    body: PersonalReminderStateIn, actor: CurrentActor, session: DbSession, response: Response
):
    """Makes the decision for `dedup_key` (201), or replaces the one there is (200), even a
    deleted one. Its id is reminder_state_id(you, dedup_key)."""
    out, made = reminder_states.save_state(session, actor, body)
    response.status_code = 201 if made else 200
    return out


@router.get("/reminder-states/{state_id}", response_model=PersonalReminderStateOut)
def get_reminder_state(state_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return reminder_states.get_state(session, actor, state_id)


@router.put("/reminder-states/{state_id}", response_model=PersonalReminderStateOut)
def update_reminder_state(
    state_id: uuid.UUID, body: PersonalReminderStateIn, actor: CurrentActor, session: DbSession
):
    return reminder_states.update_state(session, actor, state_id, body)


@router.delete("/reminder-states/{state_id}", response_model=PersonalReminderStateOut)
def delete_reminder_state(
    state_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    """Takes the decision back: the reminder shows again."""
    return reminder_states.set_deleted(session, actor, state_id, True, version)


@router.post("/reminder-states/{state_id}/restore", response_model=PersonalReminderStateOut)
def restore_reminder_state(
    state_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return reminder_states.set_deleted(session, actor, state_id, False, version)


@router.get("/reminder-schedules", response_model=list[PersonalReminderScheduleOut])
def list_reminder_schedules(
    actor: CurrentActor,
    session: DbSession,
    goal_id: uuid.UUID | None = None,
    holding_id: uuid.UUID | None = None,
    deleted: bool = False,
):
    """By day of the month (`deleted=true`: the deleted ones). No due dates: the app works out
    the next one."""
    return reminder_schedules.list_schedules(
        session, actor, goal_id=goal_id, holding_id=holding_id, deleted=deleted
    )


@router.post("/reminder-schedules", response_model=PersonalReminderScheduleOut, status_code=201)
def create_reminder_schedule(
    body: PersonalReminderScheduleIn, actor: CurrentActor, session: DbSession
):
    """A monthly reminder for a goal or a holding. It never records an entry."""
    return reminder_schedules.create_schedule(session, actor, body)


@router.get("/reminder-schedules/{schedule_id}", response_model=PersonalReminderScheduleOut)
def get_reminder_schedule(schedule_id: uuid.UUID, actor: CurrentActor, session: DbSession):
    return reminder_schedules.get_schedule(session, actor, schedule_id)


@router.put("/reminder-schedules/{schedule_id}", response_model=PersonalReminderScheduleOut)
def update_reminder_schedule(
    schedule_id: uuid.UUID,
    body: PersonalReminderScheduleIn,
    actor: CurrentActor,
    session: DbSession,
):
    return reminder_schedules.update_schedule(session, actor, schedule_id, body)


@router.delete("/reminder-schedules/{schedule_id}", response_model=PersonalReminderScheduleOut)
def delete_reminder_schedule(
    schedule_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return reminder_schedules.set_deleted(session, actor, schedule_id, True, version)


@router.post(
    "/reminder-schedules/{schedule_id}/restore", response_model=PersonalReminderScheduleOut
)
def restore_reminder_schedule(
    schedule_id: uuid.UUID, actor: CurrentActor, session: DbSession, version: int | None = None
):
    return reminder_schedules.set_deleted(session, actor, schedule_id, False, version)
