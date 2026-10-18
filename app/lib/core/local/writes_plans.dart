part of 'writes.dart';

// Allocation rules and plans (finance revamp design §3.2): the rule writes the Rules screens make,
// the plans an income's create or edit sends with it, and what the device checks and mirrors for
// them while drafting a write ([_Draft]), as the server does (api/app/modules/personal/
// allocation_rules.py, allocation_plans.py). Plans are worked out by core/finance/allocation.dart;
// a rule write never touches existing plans.

const _ruleEntity = 'personal_allocation_rule';
const _planEntity = 'personal_allocation_plan';

/// A rule as the editor fills it in: the full state to save. Only the amount of its [kind] is
/// sent ([percentBp] for a percentage, [amountMinor] for a fixed amount), and exactly one
/// destination ([goalId] or [accountId]).
final class RuleDraft {
  const RuleDraft({
    required this.kind,
    this.name,
    this.percentBp,
    this.amountMinor,
    this.sourceCategoryId,
    this.sourceAccountId,
    this.goalId,
    this.accountId,
    this.active = true,
    this.priority = 0,
  });

  /// [rule] as it is, to edit.
  RuleDraft.of(FinRule rule)
    : kind = rule.kind,
      name = rule.name,
      percentBp = rule.percentBp,
      amountMinor = rule.amountMinor,
      sourceCategoryId = rule.sourceCategoryId,
      sourceAccountId = rule.sourceAccountId,
      goalId = rule.goalId,
      accountId = rule.accountId,
      active = rule.active,
      priority = rule.priority;

  final AllocationKind kind;

  /// Optional, at most 60 characters; blank is none ("10% of each income" is shown instead).
  final String? name;

  /// For a percentage: basis points of each income (1000 is 10%, 1 to 100000; over 100% is
  /// allowed, with a warning).
  final int? percentBp;

  /// For a fixed amount: what each income sets aside.
  final int? amountMinor;

  /// Only incomes in this category ("From": a category), or any.
  final String? sourceCategoryId;

  /// Only incomes into this account ("From": an account), or any.
  final String? sourceAccountId;

  /// Where the money goes: a goal counting contributions (not archived), or an open account.
  final String? goalId, accountId;

  /// Inactive rules make no new plans.
  final bool active;

  /// 0 to 1000, 0 first. The editor has no control for it yet.
  final int priority;

  /// The rule as it would be, for [FinanceEngine.allocationLoad]'s `draft` (the editor's live
  /// warning): [id] is the rule being edited, or any id for a new one.
  FinRule toRule({String id = '', String currency = ''}) => FinRule(
    id: id,
    name: name,
    kind: kind,
    percentBp: kind == AllocationKind.percentage ? percentBp : null,
    amountMinor: kind == AllocationKind.fixed ? amountMinor : null,
    currency: currency,
    sourceCategoryId: sourceCategoryId,
    sourceAccountId: sourceAccountId,
    goalId: goalId,
    accountId: accountId,
    active: active,
    priority: priority,
  );

  PersonalAllocationRuleIn _body() => PersonalAllocationRuleIn(
    kind: PersonalAllocationRuleInKindEnum.fromJson(kind.wire)!,
    percentBp: kind == AllocationKind.percentage ? percentBp : null,
    amountMinor: kind == AllocationKind.fixed ? amountMinor : null,
    name: LocalWrites._text(name),
    trigger: PersonalAllocationRuleInTriggerEnum.incomeRecorded,
    sourceCategoryId: sourceCategoryId,
    sourceAccountId: sourceAccountId,
    goalId: goalId,
    accountId: accountId,
    active: active,
    priority: priority,
  );
}

/// The full body for a rule as [r] (a raw entity) has it.
PersonalAllocationRuleIn _ruleIn(Json r) => PersonalAllocationRuleIn(
  kind: PersonalAllocationRuleInKindEnum.fromJson(r['kind'])!,
  percentBp: r['percent_bp'] as int?,
  amountMinor: r['amount_minor'] as int?,
  name: r['name'] as String?,
  trigger: PersonalAllocationRuleInTriggerEnum.incomeRecorded,
  sourceCategoryId: r['source_category_id'] as String?,
  sourceAccountId: r['source_account_id'] as String?,
  goalId: r['goal_id'] as String?,
  accountId: r['account_id'] as String?,
  active: r['active'] as bool? ?? true,
  priority: r['priority'] as int? ?? 0,
);

/// The full body for plan [p] coming to [plannedMinor]: what it was made from stays, as the server
/// wants it (plan_fixed).
PersonalAllocationPlanIn _planIn(FinPlan p, int plannedMinor) => PersonalAllocationPlanIn(
  sourceTransactionId: p.sourceTransactionId,
  ruleId: p.ruleId,
  goalId: p.goalId,
  accountId: p.accountId,
  snapshotKind: PersonalAllocationPlanInSnapshotKindEnum.fromJson(p.snapshot.kind.wire)!,
  snapshotPercentBp: p.snapshot.percentBp,
  snapshotAmountMinor: p.snapshot.amountMinor,
  plannedMinor: plannedMinor,
);

/// The body that makes plan [d].
PersonalAllocationPlanIn _newPlanIn(PlanDraft d) => PersonalAllocationPlanIn(
  sourceTransactionId: d.incomeId,
  ruleId: d.rule.id,
  goalId: d.goalId,
  accountId: d.accountId,
  snapshotKind: PersonalAllocationPlanInSnapshotKindEnum.fromJson(d.snapshot.kind.wire)!,
  snapshotPercentBp: d.snapshot.percentBp,
  snapshotAmountMinor: d.snapshot.amountMinor,
  plannedMinor: d.plannedMinor,
);

/// A rule's name, or what it does: "10% of each income", "₹5,000 from each income"
/// (allocation_rules.describe).
String describeRule(FinRule r) {
  if (r.name case final name? when name.isNotEmpty) return name;
  if (r.kind == AllocationKind.percentage) return '${_percentText(r.percentBp ?? 0)}% of each income';
  return '${formatMinor(r.amountMinor ?? 0, currency: r.currency)} from each income';
}

/// [bp] as a percentage without trailing zeros: 1000 is "10", 1250 is "12.5", 333 is "3.33".
String _percentText(int bp) {
  if (bp % 100 == 0) return '${bp ~/ 100}';
  var text = (bp / 100).toStringAsFixed(2);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

/// allocation_rules.refuse_if_pointed_at: refused while a live rule, active or not, sends money
/// to goal [goalId] or account [accountId] (a [what]: 'goal' or 'account'), naming the oldest.
void _refuseIfPointedAt(FinanceEngine f, String what, {String? goalId, String? accountId}) {
  final ids = f.rulesPointingAt(goalId: goalId, accountId: accountId);
  if (ids.isEmpty) return;
  final rule = f.ruleById(ids.first)!;
  _refuse(
    'rule_points_here',
    'The rule “${describeRule(rule)}” sends money to this $what. Change or delete it first',
    status: 409,
  );
}

/// What income [after] (as it will be stored) does to its [plans] (raw, deleted ones too) when it
/// was [before]: the plan items sent before the entry, those sent after it, and the deleted plans
/// that come back (FinanceEngine.reconcilePlans).
({List<BatchItem> before, List<BatchItem> after, List<PlanAmount> restore}) _planItems(
  FinanceEngine f,
  Json? before,
  Json after,
  Iterable<Json> plans,
) {
  final diff = f.reconcilePlans(
    before: before == null ? null : PersonalRow(before),
    after: PersonalRow(after),
    plans: [
      for (final p in plans)
        if (FinPlan.read(p) case final plan?) plan,
    ],
  );
  return (
    before: [for (final p in diff.deleteBefore) BatchItem.deletePlan(p.id)],
    after: [
      for (final (:plan, :plannedMinor) in diff.update) BatchItem.updatePlan(plan.id, _planIn(plan, plannedMinor)),
      for (final d in diff.create) BatchItem.createPlan(d.id, _newPlanIn(d)),
      for (final p in diff.deleteAfter) BatchItem.deletePlan(p.id),
    ],
    restore: diff.restore,
  );
}

/// The `POST /personal/batch` items that make entry [id] as [body]: the entry, then, for an income
/// the allocation rules apply to, its plans (FinanceEngine.plansForIncome). One unit for
/// FinanceWrites.importUnits: never split. An entry already here makes nothing new (a replay).
List<BatchItem> entryCreateUnit(Ledger l, String id, PersonalTxnIn body) {
  final unit = [BatchItem.createEntry(id, body)];
  if (body.type != PersonalTxnInTypeEnum.income || l.rawPersonal(id) != null) return unit;
  final row = PersonalRow(_personalJson(l, id, body, null, now: appClock.now().toUtc().toIso8601String()));
  return [...unit, for (final d in l.finance.plansForIncome(row)) BatchItem.createPlan(d.id, _newPlanIn(d))];
}

/// The `POST /personal/batch` items that change entry [id] to [body], with what that does to its
/// plans: [plan deletes, the entry, plan updates, plan creates, plan deletes]. One unit for
/// FinanceWrites.importUnits. A deleted plan that would come back isn't (a restore can't go in a
/// batch): [LocalWrites.updatePersonal] does that.
List<BatchItem> entryUpdateUnit(Ledger l, String id, PersonalTxnIn body) {
  final before = l.rawPersonal(id);
  if (before == null || before['deleted_at'] != null) return [BatchItem.updateEntry(id, body)];
  final after = _personalJson(l, id, body, before, now: appClock.now().toUtc().toIso8601String());
  final items = _planItems(l.finance, before, after, l.rawPlansOf(id));
  return [...items.before, BatchItem.updateEntry(id, body), ...items.after];
}

/// What a rule or plan write checks and mirrors while it's drafted ([_Draft.add] calls these), and
/// the entry writes that bring an income's plans along.
extension _PlanDraft on _Draft {
  /// Rule [id] as the items so far leave it (deleted ones too), or null.
  Json? rule(String id) => _states[LocalEntity.keyOf(_stream, _ruleEntity, id)]?.data ?? _l.rawRule(id);

  /// Plan [id] as the items so far leave it (deleted ones too), or null.
  Json? plan(String id) => _states[LocalEntity.keyOf(_stream, _planEntity, id)]?.data ?? _l.rawPlan(id);

  /// Every plan of income [incomeId] (deleted ones too), as the items so far leave them.
  List<Json> _plansOf(String incomeId) {
    final ids = <String>{
      for (final p in _l.rawPlansOf(incomeId)) p['id'] as String,
      for (final s in _states.values)
        if (s.entity == _planEntity && s.data['source_transaction_id'] == incomeId) s.entityId,
    };
    return [
      for (final id in ids)
        if (plan(id) case final p? when p['source_transaction_id'] == incomeId) p,
    ];
  }

  /// The live plans of income [incomeId], as the items so far leave them.
  List<Json> _livePlansOf(String incomeId) => [
    for (final p in _plansOf(incomeId))
      if (p['deleted_at'] == null) p,
  ];

  // ---- entries with their plans ----

  /// Makes entry [id] as [body]; for an income the rules apply to, its plans after it, in the same
  /// request (FinanceEngine.plansForIncome). A replay (the entry is here) makes no plans.
  void addEntryCreate(String id, PersonalTxnIn body) {
    final existed = entry(id) != null;
    add(BatchItem.createEntry(id, body));
    if (existed || body.type != PersonalTxnInTypeEnum.income) return;
    for (final d in _l.finance.plansForIncome(PersonalRow(entry(id)!))) {
      add(BatchItem.createPlan(d.id, _newPlanIn(d)));
    }
  }

  /// Changes entry [id] to [body] with what that does to its plans (FinanceEngine.reconcilePlans):
  /// plan deletes first (an income can't change type while it has live plans), then the entry, then
  /// plan updates, creates and deletes. Deleted plans that come back are noted for [ops].
  void addEntryUpdate(String id, PersonalTxnIn body) {
    final before = entry(id);
    if (before == null || before['deleted_at'] != null) return add(BatchItem.updateEntry(id, body));
    if (body.accountId == null && _claimedBy[id] != null) body.accountId = _claimedBy[id];
    final after = _personalJson(_l, id, body, before, now: _now, adminId: _adminId);
    final items = _planItems(_l.finance, before, after, _plansOf(id));
    items.before.forEach(add);
    add(BatchItem.updateEntry(id, body));
    items.after.forEach(add);
    _restores = [..._restores, ...items.restore];
  }

  /// The plans noted to come back, and none after.
  List<PlanAmount> _takeRestores() {
    final out = _restores;
    _restores = [];
    return out;
  }

  /// This request as one `POST /personal/batch` ([op]), then each plan it brings back
  /// (LocalWrites._planRestoreOps).
  List<OutboxOp> ops(String label) {
    final restores = _takeRestores();
    return [op(label), ..._w._planRestoreOps(_l, restores)];
  }

  /// allocation_plans.follow_income: entry [entryId] was just deleted at [at] (its live plans go
  /// with it), or is being restored from a delete at [at] (the ones that went with it come back).
  void _followIncome(String entryId, bool deleted, String at) {
    final when = isoMicros(at);
    for (final p in _plansOf(entryId)) {
      if (deleted ? p['deleted_at'] == null : p['deleted_at'] != null && isoMicros(p['deleted_at']) == when) {
        _setPlanState(p, deletedAt: deleted ? at : null);
      }
    }
  }

  void _setPlanState(Json p, {required String? deletedAt}) => _set(_planEntity, {
    ...p,
    'deleted_at': deletedAt,
    'updated_at': _now,
    'acting_admin_id': _adminId,
    'version': (p['version'] as int) + 1,
  });

  // ---- plans (allocation_plans.py create, update, change_deleted) ----

  void _createPlan(String id, PersonalAllocationPlanIn body) {
    // A repeated create gives back the plan that's there, deleted or not, unchanged.
    if (plan(id) != null) return;
    final incomeId = body.sourceTransactionId, ruleId = body.ruleId;
    if (incomeId == null || ruleId == null || (body.goalId == null) == (body.accountId == null)) {
      _refuse('plan_incomplete', 'A plan needs its income, its rule and one destination');
    }
    final income = entry(incomeId);
    if (income == null || income['deleted_at'] != null || income['type'] != 'income') {
      _refuse('unknown_income', "That income isn't available");
    }
    final currency = _l.userOut()['currency'];
    if (income['currency'] != currency) {
      _refuse('currency_mismatch', 'That income is in ${income['currency']}; your entries are in $currency');
    }
    final r = rule(ruleId);
    if (r == null) _refuse('unknown_rule', "That rule isn't available");
    if (r['deleted_at'] != null) _refuse('unknown_rule', 'That rule was deleted, so it makes no new plans');
    if (body.goalId != r['goal_id'] || body.accountId != r['account_id']) {
      _refuse('destination_mismatch', 'A plan goes where its rule sends money');
    }
    if (_plansOf(incomeId).any((p) => p['rule_id'] == ruleId)) {
      _refuse('plan_exists', 'This income already has a plan from that rule', status: 409);
    }
    _checkPlanBody(body);
    _set(_planEntity, {
      'id': id,
      'user_id': _l.me,
      'source_transaction_id': incomeId,
      'rule_id': ruleId,
      'snapshot_kind': body.snapshotKind.value,
      'snapshot_percent_bp': body.snapshotPercentBp,
      'snapshot_amount_minor': body.snapshotAmountMinor,
      'planned_minor': body.plannedMinor,
      'currency': income['currency'],
      'goal_id': body.goalId,
      'account_id': body.accountId,
      'acting_admin_id': _adminId,
      'created_at': _now,
      'updated_at': _now,
      'deleted_at': null,
      'version': 1,
    });
  }

  void _updatePlan(String id, PersonalAllocationPlanIn body) {
    final before = plan(id) ?? (throw const LocalNotFound('Plan'));
    if (before['deleted_at'] != null) _refuse('deleted', 'Restore this plan before editing it', status: 409);
    for (final (key, value) in [
      ('source_transaction_id', body.sourceTransactionId),
      ('rule_id', body.ruleId),
      ('goal_id', body.goalId),
      ('account_id', body.accountId),
    ]) {
      if (value != before[key]) _refuse('plan_fixed', "A plan's income, rule and destination don't change");
    }
    _checkPlanBody(body);
    final data = {
      ...before,
      'snapshot_kind': body.snapshotKind.value,
      'snapshot_percent_bp': body.snapshotPercentBp,
      'snapshot_amount_minor': body.snapshotAmountMinor,
      'planned_minor': body.plannedMinor,
    };
    const fields = ['snapshot_kind', 'snapshot_percent_bp', 'snapshot_amount_minor', 'planned_minor'];
    // The server leaves a plan nothing changes as it is, version too.
    if (fields.every((k) => data[k] == before[k])) return;
    _set(_planEntity, {
      ...data,
      'updated_at': _now,
      'acting_admin_id': _adminId,
      'version': (before['version'] as int) + 1,
    });
  }

  /// Deletes plan [id] (a restore is its own request: LocalWrites._planRestoreOps).
  void _setPlanDeleted(String id, bool deleted) {
    final p = plan(id) ?? (throw const LocalNotFound('Plan'));
    if ((p['deleted_at'] != null) == deleted) return;
    _setPlanState(p, deletedAt: deleted ? _now : null);
  }

  /// What PersonalAllocationPlanIn's validation and allocation_plans._check_snapshot refuse.
  void _checkPlanBody(PersonalAllocationPlanIn body) {
    final percentage = body.snapshotKind == PersonalAllocationPlanInSnapshotKindEnum.percentage;
    if (percentage != (body.snapshotPercentBp != null) || percentage == (body.snapshotAmountMinor != null)) {
      _refuse('snapshot_invalid', 'A percentage plan records the percentage, and a fixed one the amount');
    }
    if (body.plannedMinor <= 0 || body.plannedMinor > maxAmountMinor) {
      _refuse('invalid_input', 'A plan sets aside an amount above zero');
    }
  }

  // ---- rules (allocation_rules.py create, update, change_deleted) ----

  void _createRule(String id, PersonalAllocationRuleIn body) {
    // A repeated create gives back the rule that's there, unchanged (versioning.replayed_create).
    if (rule(id) != null) return;
    _checkRuleBody(body);
    final (percent, amount) = _ruleAmounts(body);
    final (goal, account) = _ruleDestination(body);
    final currency = _l.userOut()['currency'] as String;
    _checkRuleDestination(goal, account, currency);
    _checkRuleSources(body.sourceCategoryId, body.sourceAccountId);
    _set(_ruleEntity, _ruleData(id, body, null, percent, amount, goal, account, currency));
  }

  void _updateRule(String id, PersonalAllocationRuleIn body) {
    final before = rule(id) ?? (throw const LocalNotFound('Rule'));
    if (before['deleted_at'] != null) _refuse('deleted', 'Restore this rule before editing it', status: 409);
    _checkRuleBody(body);
    final (percent, amount) = _ruleAmounts(body);
    final (goal, account) = _ruleDestination(body);
    final currency = before['currency'] as String;
    if (goal != before['goal_id'] || account != before['account_id']) _checkRuleDestination(goal, account, currency);
    _checkRuleSources(
      body.sourceCategoryId == before['source_category_id'] ? null : body.sourceCategoryId,
      body.sourceAccountId == before['source_account_id'] ? null : body.sourceAccountId,
    );
    final data = _ruleData(id, body, before, percent, amount, goal, account, currency);
    const fields = [
      'name',
      'trigger',
      'kind',
      'percent_bp',
      'amount_minor',
      'active',
      'priority',
      'source_category_id',
      'source_account_id',
      'goal_id',
      'account_id',
    ];
    // The server leaves a rule nothing changes as it is, version too.
    if (fields.every((k) => data[k] == before[k])) return;
    _set(_ruleEntity, data);
  }

  /// Deletes or restores rule [id]; its plans stay as they are either way. A restore needs its
  /// destination to still take money.
  void _setRuleDeleted(String id, bool deleted) {
    final r = rule(id) ?? (throw const LocalNotFound('Rule'));
    if ((r['deleted_at'] != null) == deleted) return;
    if (!deleted) _checkRuleDestination(r['goal_id'] as String?, r['account_id'] as String?, r['currency'] as String);
    _set(_ruleEntity, {
      ...r,
      'deleted_at': deleted ? _now : null,
      'updated_at': _now,
      'acting_admin_id': _adminId,
      'version': (r['version'] as int) + 1,
    });
  }

  /// What PersonalAllocationRuleIn's validation refuses that the editor could send.
  void _checkRuleBody(PersonalAllocationRuleIn body) {
    if ((body.name?.length ?? 0) > 60) _refuse('invalid_input', 'Name can be at most 60 characters');
    if (body.percentBp case final bp? when bp < 1 || bp > 100000) {
      _refuse('invalid_input', 'A percentage is between 0.01% and 1000%');
    }
    if (body.amountMinor case final a? when a <= 0 || a > maxAmountMinor) {
      _refuse('invalid_input', 'Enter an amount above zero');
    }
    if (body.priority < 0 || body.priority > 1000) _refuse('invalid_input', 'Priority is between 0 and 1000');
  }

  /// allocation_rules._amounts for a full body: the kind's amount is required, the other's must be
  /// empty.
  (int?, int?) _ruleAmounts(PersonalAllocationRuleIn body) {
    if (body.kind == PersonalAllocationRuleInKindEnum.percentage) {
      if (body.percentBp == null) _refuse('percent_required', 'Give the percentage');
      if (body.amountMinor != null) _refuse('amount_not_used', 'A percentage rule has no fixed amount');
      return (body.percentBp, null);
    }
    if (body.amountMinor == null) _refuse('amount_required', 'Give the amount');
    if (body.percentBp != null) _refuse('percent_not_used', 'A fixed rule has no percentage');
    return (null, body.amountMinor);
  }

  /// allocation_rules._destination for a full body: exactly one of a goal and an account.
  (String?, String?) _ruleDestination(PersonalAllocationRuleIn body) {
    if (body.goalId != null && body.accountId != null) {
      _refuse('destination_invalid', 'A rule sends money to a goal or an account, not both');
    }
    if (body.goalId == null && body.accountId == null) {
      _refuse('destination_required', 'Pick the goal or account the money goes to');
    }
    return (body.goalId, body.accountId);
  }

  /// allocation_rules._check_destination: a goal that counts contributions (not archived), or an
  /// open account, in the rule's [currency].
  void _checkRuleDestination(String? goalId, String? accountId, String currency) {
    if (goalId != null) {
      final g = goal(goalId);
      if (g == null || g['deleted_at'] != null) _refuse('unknown_goal', "That goal isn't available");
      final name = g['name'];
      if (g['status'] == 'archived') _refuse('goal_archived', '$name is archived');
      if (g['tracking_mode'] == 'linked_balance') {
        _refuse('goal_tracks_balance', "$name follows an account's balance: send the money to that account instead");
      }
      if (g['tracking_mode'] == 'manual') {
        _refuse('goal_is_manual', "$name is tracked by hand, so money can't go to it");
      }
      if (g['currency'] != currency) {
        _refuse('currency_mismatch', 'That goal is in ${g['currency']}; this rule is in $currency');
      }
      return;
    }
    final a = account(accountId!);
    if (a == null || a['deleted_at'] != null) _refuse('unknown_account', "That account isn't available");
    if (a['status'] == 'closed') _refuse('account_closed', 'That account is closed');
    if (a['currency'] != currency) {
      _refuse('currency_mismatch', 'That account is in ${a['currency']}; this rule is in $currency');
    }
  }

  /// allocation_rules._check_sources: a category this device has, a live account.
  void _checkRuleSources(String? categoryId, String? accountId) {
    if (categoryId != null && _l.rawCategory(categoryId) == null) {
      _refuse('unknown_category', "That category isn't available");
    }
    if (accountId != null) {
      final a = account(accountId);
      if (a == null || a['deleted_at'] != null) _refuse('unknown_account', "That account isn't available");
    }
  }

  /// The rule as the server stores it (personal_allocation_rules, as the sync log sends it).
  Json _ruleData(
    String id,
    PersonalAllocationRuleIn body,
    Json? before,
    int? percent,
    int? amount,
    String? goal,
    String? account,
    String currency,
  ) => {
    'id': id,
    'user_id': _l.me,
    'name': LocalWrites._text(body.name),
    'trigger': body.trigger.value,
    'source_category_id': body.sourceCategoryId,
    'source_account_id': body.sourceAccountId,
    'kind': body.kind.value,
    'percent_bp': percent,
    'amount_minor': amount,
    'currency': currency,
    'goal_id': goal,
    'account_id': account,
    'active': body.active,
    'priority': body.priority,
    'acting_admin_id': _adminId,
    'created_at': before?['created_at'] ?? _now,
    'updated_at': _now,
    'deleted_at': null,
    'version': (before?['version'] as int? ?? 0) + 1,
  };
}

/// Allocation rules, queued like every other write: each is checked first as the server will check
/// it and laid over the synced data ([_Draft]). A rule change never touches existing plans: plans
/// are made and worked out again by the income writes (createPersonal, updatePersonal and the
/// rest). The views to read them with are in core/finance/allocation_providers.dart.
extension PlanWrites on LocalWrites {
  /// A new rule in your currency, with [id] or a new one (`POST /personal/allocation-rules`);
  /// returns its id. It applies to incomes recorded from now on. Refused when its destination
  /// doesn't take money (a goal that follows a balance, is tracked by hand or archived; a closed
  /// account) or a filter names something that isn't available.
  Future<String> createRule(RuleDraft rule, {String? id}) async {
    final l = await _ledger();
    id ??= LocalWrites._uuid.v4();
    final body = rule._body();
    final entities = (_Draft(this, l)..add(BatchItem.createRule(id, body))).finish();
    await _queue(
      OutboxOp(
        method: 'POST',
        path: '/api/v1/personal/allocation-rules',
        body: _json((body..id = id).toJson()),
        label: 'Added rule ${_ruleLabel(l, entities.first.data)}',
        entities: entities,
        createdAt: _now(),
      ),
    );
    return id;
  }

  /// Saves rule [id] as [rule] (`PUT /personal/allocation-rules/{id}`, the full state: one
  /// destination, the kind with its amount). Plans already made keep their amounts. Nothing is
  /// queued when nothing changes.
  Future<void> updateRule(String id, RuleDraft rule) async {
    final l = await _ledger();
    await _queueRuleEdit(l, id, rule._body(), 'Edited rule');
  }

  /// Turns rule [id] on or off: an inactive rule makes no new plans, and still counts as pointing
  /// at its destination (rule_points_here).
  Future<void> setRuleActive(String id, bool active) async {
    final l = await _ledger();
    final before = _required(l.rawRule(id), 'Rule');
    if (before['active'] == active) return;
    await _queueRuleEdit(l, id, _ruleIn(before)..active = active, active ? 'Turned on rule' : 'Turned off rule');
  }

  Future<void> _queueRuleEdit(Ledger l, String id, PersonalAllocationRuleIn body, String verb) async {
    final version = _required(l.rawRule(id), 'Rule')['version'] as int;
    final entities = (_Draft(this, l)..add(BatchItem.updateRule(id, body))).finish();
    if (entities.isEmpty) return;
    await _queue(
      OutboxOp(
        method: 'PUT',
        path: '/api/v1/personal/allocation-rules/$id',
        body: _json(
          (body
                ..id = null
                ..version = version)
              .toJson(),
        ),
        label: '$verb ${_ruleLabel(l, entities.first.data)}',
        entities: entities,
        createdAt: _now(),
      ),
    );
  }

  /// Deletes rule [id] (`DELETE /personal/allocation-rules/{id}`). Its plans stay: they explain
  /// the incomes they were made for.
  Future<void> deleteRule(String id) => _setRuleDeletedOp(id, true);

  /// Brings deleted rule [id] back. Refused when its destination no longer takes money.
  Future<void> restoreRule(String id) => _setRuleDeletedOp(id, false);

  Future<void> _setRuleDeletedOp(String id, bool deleted) async {
    final l = await _ledger();
    final before = _required(l.rawRule(id), 'Rule');
    if ((before['deleted_at'] != null) == deleted) return;
    final version = before['version'] as int;
    final entities = (_Draft(this, l).._setRuleDeleted(id, deleted)).finish();
    await _queue(
      OutboxOp(
        method: deleted ? 'DELETE' : 'POST',
        path: deleted ? '/api/v1/personal/allocation-rules/$id' : '/api/v1/personal/allocation-rules/$id/restore',
        query: {'version': '$version'},
        label: '${deleted ? 'Deleted' : 'Restored'} rule ${_ruleLabel(l, before)}',
        entities: entities,
        createdAt: _now(),
      ),
    );
  }

  /// "10% of each income → Ladakh trip".
  String _ruleLabel(Ledger l, Json r) {
    final rule = FinRule.read(r);
    final what = rule == null ? 'a rule' : describeRule(rule);
    return '$what → ${_destinationName(l, r)}';
  }

  /// The name of the goal or account [row] (a rule or a plan) sends money to.
  String _destinationName(Ledger l, Json row) => switch ((row['goal_id'], row['account_id'])) {
    (final String g, _) => l.rawGoal(g)?['name'] as String? ?? 'a goal',
    (_, final String a) => l.rawAccount(a)?['name'] as String? ?? 'an account',
    _ => 'nowhere',
  };

  /// Brings back each of [restores] (deleted plans whose rule applies again) after the request that
  /// made them apply: `POST /personal/allocation-plans/{id}/restore`, then, when what it comes to
  /// changed, a PUT of its new amount. A create can't: with the plan's id it gives back the deleted
  /// row.
  List<OutboxOp> _planRestoreOps(Ledger l, List<PlanAmount> restores) {
    final ops = <OutboxOp>[];
    final now = _now();
    final adminId = _ref.read(sessionProvider).value?.adminId;
    final stream = 'user:${l.me}';
    for (final (:plan, :plannedMinor) in restores) {
      final raw = l.rawPlan(plan.id);
      if (raw == null || raw['deleted_at'] == null) continue;
      final version = raw['version'] as int;
      final back = {...raw, 'deleted_at': null, 'updated_at': now, 'acting_admin_id': adminId, 'version': version + 1};
      final amount = formatMinor(plannedMinor, currency: raw['currency'] as String);
      final label = 'Plan back: $amount → ${_destinationName(l, raw)}';
      ops.add(
        OutboxOp(
          method: 'POST',
          path: '/api/v1/personal/allocation-plans/${plan.id}/restore',
          query: {'version': '$version'},
          label: label,
          entities: [_entity(stream, _planEntity, plan.id, version + 1, back)],
          createdAt: now,
        ),
      );
      if (plannedMinor == raw['planned_minor']) continue;
      final changed = {...back, 'planned_minor': plannedMinor, 'version': version + 2};
      ops.add(
        OutboxOp(
          method: 'PUT',
          path: '/api/v1/personal/allocation-plans/${plan.id}',
          body: _json((_planIn(plan, plannedMinor)..version = version + 1).toJson()),
          label: label,
          entities: [_entity(stream, _planEntity, plan.id, version + 2, changed)],
          createdAt: now,
        ),
      );
    }
    return ops;
  }
}
