import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/finance/finance.dart';
import 'package:splitkit/core/local/ledger.dart';
import 'package:splitkit/core/local/outbox.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/local/writes.dart';

import '../fake_backend.dart';

// Plans in the income writes, and the rule writes (core/local/writes_plans.dart, design §3.2),
// against the seed's sync snapshot, offline, so every write stays queued and the test reads what
// it would send and what it shows. The seed: "10% of each income" to the Ladakh trip, and
// "Emergency top-up", ₹5,000 from each income to Emergency savings; both planned from the 1 Sep
// salary.

Ledger _ledger(WidgetTester tester) => appContainer(tester).read(localStoreProvider).value!.ledger;
LocalWrites _writes(WidgetTester tester) => appContainer(tester).read(writesProvider);
List<OutboxOp> _ops(WidgetTester tester) => appContainer(tester).read(outboxProvider);

String _goal(Ledger l, String name) => l.personalGoalList().firstWhere((g) => g['name'] == name)['id'] as String;
String _account(Ledger l, String name) => l.personalAccountList().firstWhere((a) => a['name'] == name)['id'] as String;

/// The seed's rules: the trip's (no name), then the top-up.
(String trip, String topUp) _rules(Ledger l) {
  final rules = l.allocationRuleList();
  return (rules[0]['id'] as String, rules[1]['id'] as String);
}

List<Json> _items(OutboxOp op) {
  // The request parses as the generated client's model, so its shape can't drift from the API's.
  expect(PersonalMixedBatchIn.fromJson(op.body), isNotNull);
  return (op.body!['items'] as List).cast<Json>();
}

Object _item(Json i) => (i['kind'], i['op'], i['id'], i['version']);

/// The batch items deleting income [incomeId]'s plans from [rules], in the API's order: made at
/// the same moment, so by id.
List<Object> _planDeletes(String incomeId, List<String> rules) => [
  for (final p in [for (final r in rules) planId(incomeId, r)]..sort()) ('allocation_plan', 'delete', p, 1),
];

/// [write] is refused before anything is queued, with the server's [code] (and [message]).
Future<void> _expectRefused(WidgetTester tester, Future<Object?> write, String code, [Object? message]) async {
  final queued = _ops(tester).length;
  Object? error;
  try {
    await runWrite(tester, write);
  } catch (e) {
    error = e;
  }
  expect(
    error,
    isA<WriteRefused>().having(apiErrorCode, 'code', code).having(apiErrorMessage, 'message', message ?? anything),
  );
  expect(_ops(tester).length, queued);
}

Future<void> _offline(WidgetTester tester) async {
  final be = await pumpApp(tester);
  be.offline = true;
}

PersonalTxnIn _income(int amount, {String? accountId, String? categoryId}) => PersonalTxnIn(
  type: PersonalTxnInTypeEnum.income,
  amountMinor: amount,
  description: 'Freelance',
  date: DateTime.utc(2026, 9, 24),
  accountId: accountId,
  categoryId: categoryId,
  source_: PersonalTxnInSource_Enum.manual,
);

void main() {
  testWidgets('an income is one batch with its plans; anything else a plain POST', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    var l = _ledger(tester);
    final (trip, topUp) = _rules(l);
    final hdfc = _account(l, 'HDFC ··4821');

    final id = await runWrite(tester, w.createPersonal(_income(4000000, accountId: hdfc)));
    final op = _ops(tester).single;
    expect((op.method, op.path, op.label), ('POST', '/api/v1/personal/batch', 'Added Freelance · ₹40,000'));
    final items = _items(op);
    expect(
      [for (final i in items) _item(i)],
      [
        ('transaction', 'create', id, null),
        ('allocation_plan', 'create', planId(id, trip), null),
        ('allocation_plan', 'create', planId(id, topUp), null),
      ],
    );
    final plan = items[1]['allocation_plan'] as Map;
    expect(
      (plan['source_transaction_id'], plan['rule_id'], plan['snapshot_kind'], plan['snapshot_percent_bp']),
      (id, trip, 'percentage', 1000),
    );
    expect(
      (plan['planned_minor'], plan['goal_id'], plan['id'], plan['version']),
      (400000, _goal(l, 'Ladakh trip'), null, null),
    );
    expect((items[2]['allocation_plan'] as Map)['planned_minor'], 500000);
    expect(
      [for (final e in op.entities) (e.entity, e.version)],
      [('personal_transaction', 1), ('personal_allocation_plan', 1), ('personal_allocation_plan', 1)],
    );
    // Shown at once: planned, nothing set aside yet.
    l = _ledger(tester);
    expect([
      for (final v in l.finance.plansOfIncome(id)) (v.plan.plannedMinor, v.status),
    ], unorderedEquals([(400000, PlanStatus.planned), (500000, PlanStatus.planned)]));

    // A spend has no plans: a plain POST.
    await runWrite(
      tester,
      w.createPersonal(
        PersonalTxnIn(
          type: PersonalTxnInTypeEnum.expense,
          amountMinor: 1000,
          description: 'Tea',
          date: DateTime.utc(2026, 9, 24),
          source_: PersonalTxnInSource_Enum.manual,
        ),
      ),
    );
    expect((_ops(tester).last.method, _ops(tester).last.path), ('POST', '/api/v1/personal/transactions'));
  });

  testWidgets('edits: the amount recomputes with each plan\'s snapshot; a note alone is a plain PUT', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    final l = _ledger(tester);
    final (trip, _) = _rules(l);
    final id = await runWrite(tester, w.createPersonal(_income(4000000)));

    // The trip rule is now 20%: the plan made at 10% keeps its 10%.
    await runWrite(tester, w.updateRule(trip, RuleDraft.of(_ledger(tester).finance.ruleById(trip)!.withPercent(2000))));
    final body = personalBody(PersonalTxnOut.fromJson(_ledger(tester).personalTransaction(id))!)..amountMinor = 5000000;
    await runWrite(tester, w.updatePersonal(id, body));
    var op = _ops(tester).last;
    expect((op.method, op.path, op.label), ('POST', '/api/v1/personal/batch', 'Edited Freelance · ₹50,000'));
    expect(
      [for (final i in _items(op)) _item(i)],
      [('transaction', 'update', id, 1), ('allocation_plan', 'update', planId(id, trip), 1)],
    );
    final sent = _items(op)[1]['allocation_plan'] as Map;
    expect(
      (sent['planned_minor'], sent['snapshot_percent_bp'], sent['source_transaction_id'], sent['rule_id']),
      (500000, 1000, id, trip),
    );
    expect(_ledger(tester).allocationPlan(planId(id, trip))['version'], 2);

    await runWrite(tester, w.updatePersonal(id, body..notes = 'Invoice 12'));
    op = _ops(tester).last;
    expect((op.method, op.path), ('PUT', '/api/v1/personal/transactions/$id'));
  });

  testWidgets('a type change sends the plan deletes first; changing back restores them', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    final (trip, topUp) = _rules(_ledger(tester));
    final id = await runWrite(tester, w.createPersonal(_income(4000000)));
    PersonalTxnIn body() => personalBody(PersonalTxnOut.fromJson(_ledger(tester).personalTransaction(id))!);

    await runWrite(tester, w.updatePersonal(id, body()..type = PersonalTxnInTypeEnum.expense));
    var op = _ops(tester).last;
    expect(
      [for (final i in _items(op)) _item(i)],
      [
        ..._planDeletes(id, [trip, topUp]),
        ('transaction', 'update', id, 1),
      ],
    );
    expect([for (final v in _ledger(tester).finance.plansOfIncome(id)) v.status], everyElement(PlanStatus.cancelled));

    // An income again, at a new amount: the entry, then each plan back and, at its new amount, put.
    final before = _ops(tester).length;
    await runWrite(
      tester,
      w.updatePersonal(
        id,
        body()
          ..type = PersonalTxnInTypeEnum.income
          ..amountMinor = 3000000,
      ),
    );
    final ops = _ops(tester).skip(before).toList();
    expect(
      [for (final o in ops) (o.method, o.path, o.query['version'] ?? o.body?['version'])],
      [
        ('PUT', '/api/v1/personal/transactions/$id', 2),
        ('POST', '/api/v1/personal/allocation-plans/${planId(id, trip)}/restore', '2'),
        ('PUT', '/api/v1/personal/allocation-plans/${planId(id, trip)}', 3),
        ('POST', '/api/v1/personal/allocation-plans/${planId(id, topUp)}/restore', '2'),
      ],
    );
    expect(PersonalAllocationPlanIn.fromJson(ops[2].body)!.plannedMinor, 300000);
    final l = _ledger(tester);
    expect([
      for (final v in l.finance.plansOfIncome(id)) (v.plan.plannedMinor, v.status, v.plan.version),
    ], unorderedEquals([(300000, PlanStatus.planned, 4), (500000, PlanStatus.planned, 3)]));
  });

  testWidgets('deleting an income cancels its plans with it; restoring brings them back', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    final l = _ledger(tester);
    final salary = l.finance.planViews.values.first.plan.sourceTransactionId;
    await runWrite(tester, w.deletePersonal(salary));
    var op = _ops(tester).last;
    expect((op.method, op.path), ('DELETE', '/api/v1/personal/transactions/$salary'));
    final at = op.entities.first.data['deleted_at'];
    expect(
      [for (final e in op.entities) (e.entity, e.version, e.data['deleted_at'])],
      [('personal_transaction', 2, at), ('personal_allocation_plan', 2, at), ('personal_allocation_plan', 2, at)],
    );
    expect([
      for (final v in _ledger(tester).finance.plansOfIncome(salary)) v.cancelReason,
    ], everyElement(CancelReason.incomeDeleted));

    await runWrite(tester, w.restorePersonal(salary));
    op = _ops(tester).last;
    expect(
      [for (final e in op.entities) (e.entity, e.version, e.data['deleted_at'])],
      [('personal_transaction', 3, null), ('personal_allocation_plan', 3, null), ('personal_allocation_plan', 3, null)],
    );
    expect(
      [for (final v in _ledger(tester).finance.plansOfIncome(salary)) v.status],
      [PlanStatus.partial, PlanStatus.planned],
    );
  });

  testWidgets('linking an income to Split, or making it a transfer half, deletes its plans first', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    final l = _ledger(tester);
    final (trip, topUp) = _rules(l);
    final id = await runWrite(tester, w.createPersonal(_income(4000000, accountId: _account(l, 'HDFC ··4821'))));
    final spend = await runWrite(
      tester,
      w.createPersonal(
        PersonalTxnIn(
          type: PersonalTxnInTypeEnum.expense,
          amountMinor: 4000000,
          description: 'To HDFC',
          date: DateTime.utc(2026, 9, 24),
          accountId: _account(l, 'Cash'),
          source_: PersonalTxnInSource_Enum.manual,
        ),
      ),
    );
    await runWrite(tester, w.pairAsTransfer(spend, id));
    expect(
      [for (final i in _items(_ops(tester).last)) _item(i)],
      [
        ('transaction', 'update', spend, 1),
        ..._planDeletes(id, [trip, topUp]),
        ('transaction', 'update', id, 1),
      ],
    );

    final other = await runWrite(tester, w.createPersonal(_income(100000)));
    final settlement = l.feed(limit: 100).firstWhere((f) => f['kind'] == 'settlement')['id'] as String;
    await runWrite(tester, w.linkPersonal(other, settlementId: settlement));
    expect(
      [for (final i in _items(_ops(tester).last)) (i['kind'], i['op'])],
      [('allocation_plan', 'delete'), ('allocation_plan', 'delete'), ('transaction', 'update')],
    );
  });

  testWidgets('rule writes: create, edit with the full body, turn off, delete, restore; no plan writes', (
    tester,
  ) async {
    await _offline(tester);
    final w = _writes(tester);
    final l = _ledger(tester);
    final ladakh = _goal(l, 'Ladakh trip'), hdfc = _account(l, 'HDFC ··4821');
    final plansBefore = l.allocationPlanList().length;

    final id = await runWrite(
      tester,
      w.createRule(
        const RuleDraft(kind: AllocationKind.percentage, percentBp: 1250, amountMinor: 999).withGoal(ladakh),
      ),
    );
    var op = _ops(tester).last;
    expect(
      (op.method, op.path, op.label),
      ('POST', '/api/v1/personal/allocation-rules', 'Added rule 12.5% of each income → Ladakh trip'),
    );
    expect(PersonalAllocationRuleIn.fromJson(op.body), isNotNull);
    expect(
      (op.body!['id'], op.body!['percent_bp'], op.body!['amount_minor'], op.body!['trigger']),
      (
        id,
        1250,
        null, // not this kind's: sent empty
        'income_recorded',
      ),
    );
    expect(_ledger(tester).finance.ruleById(id)!.percentBp, 1250);
    // Over 100% would warn; this is 22.5% from any income, so it doesn't.
    expect(_ledger(tester).finance.allocationLoad().worstBp, 2250);

    // The full state, now a fixed amount to an account, from HDFC only.
    await runWrite(
      tester,
      w.updateRule(
        id,
        RuleDraft(
          kind: AllocationKind.fixed,
          amountMinor: 200000,
          accountId: hdfc,
          sourceAccountId: hdfc,
          name: ' Rent ',
        ),
      ),
    );
    op = _ops(tester).last;
    expect(
      (op.method, op.path, op.body!['version'], op.body!['goal_id'], op.body!['account_id']),
      ('PUT', '/api/v1/personal/allocation-rules/$id', 1, null, hdfc),
    );
    expect((op.body!['percent_bp'], op.body!['amount_minor'], op.body!['source_account_id']), (null, 200000, hdfc));
    expect(_ledger(tester).allocationRule(id)['name'], 'Rent');

    // Nothing changes: nothing queued.
    final count = _ops(tester).length;
    await runWrite(tester, w.updateRule(id, RuleDraft.of(_ledger(tester).finance.ruleById(id)!)));
    expect(_ops(tester).length, count);

    await runWrite(tester, w.setRuleActive(id, false));
    op = _ops(tester).last;
    expect(
      (op.method, op.body!['active'], op.body!['version'], op.label),
      ('PUT', false, 2, 'Turned off rule Rent → HDFC ··4821'),
    );

    await runWrite(tester, w.deleteRule(id));
    op = _ops(tester).last;
    expect((op.method, op.path, op.query['version']), ('DELETE', '/api/v1/personal/allocation-rules/$id', '3'));
    expect(_ledger(tester).finance.liveRules.map((r) => r.id), isNot(contains(id)));
    await runWrite(tester, w.restoreRule(id));
    op = _ops(tester).last;
    expect((op.method, op.path, op.query['version']), ('POST', '/api/v1/personal/allocation-rules/$id/restore', '4'));

    // A rule change never touches existing plans.
    expect(_ledger(tester).allocationPlanList().length, plansBefore);
    expect(_ops(tester).where((o) => o.path.contains('allocation-plans')), isEmpty);
  });

  testWidgets('a rule is refused as the server refuses it', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    final l = _ledger(tester);
    final fund = _goal(l, 'Emergency fund'), gold = _goal(l, 'Gold coins'), ladakh = _goal(l, 'Ladakh trip');
    const pct = RuleDraft(kind: AllocationKind.percentage, percentBp: 1000);
    await _expectRefused(
      tester,
      w.createRule(pct.withGoal(fund)),
      'goal_tracks_balance',
      "Emergency fund follows an account's balance: send the money to that account instead",
    );
    await _expectRefused(tester, w.createRule(pct.withGoal(gold)), 'goal_is_manual');
    await _expectRefused(tester, w.createRule(pct), 'destination_required');
    await _expectRefused(
      tester,
      w.createRule(const RuleDraft(kind: AllocationKind.percentage, goalId: 'x', accountId: 'y', percentBp: 1)),
      'destination_invalid',
    );
    await _expectRefused(
      tester,
      w.createRule(const RuleDraft(kind: AllocationKind.percentage).withGoal(ladakh)),
      'percent_required',
    );
    await _expectRefused(
      tester,
      w.createRule(const RuleDraft(kind: AllocationKind.fixed).withGoal(ladakh)),
      'amount_required',
    );
    await _expectRefused(
      tester,
      w.createRule(pct.withGoal(ladakh).withSource('a0000000-0000-4000-8000-000000000000')),
      'unknown_account',
    );
    await runWrite(tester, w.closeAccount(_account(l, 'Cash')));
    await _expectRefused(
      tester,
      w.createRule(RuleDraft(kind: AllocationKind.fixed, amountMinor: 100, accountId: _account(l, 'Cash'))),
      'account_closed',
    );
  });

  testWidgets('a goal or account a rule points at, active or not, can\'t stop taking money', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    final l = _ledger(tester);
    final ladakh = _goal(l, 'Ladakh trip'), savings = _account(l, 'Emergency savings');
    final (trip, topUp) = _rules(l);
    await runWrite(tester, w.setRuleActive(trip, false));
    const message = 'The rule “10% of each income” sends money to this goal. Change or delete it first';
    await _expectRefused(tester, w.deleteGoal(ladakh), 'rule_points_here', message);
    await _expectRefused(tester, w.setGoalStatus(ladakh, GoalStatus.archived), 'rule_points_here', message);
    await _expectRefused(tester, w.switchGoalMode(ladakh, GoalMode.manual, manualProgressMinor: 0), 'rule_points_here');
    // Pausing is fine: the rule makes no plans while it's paused.
    await runWrite(tester, w.setGoalStatus(ladakh, GoalStatus.paused));
    expect(_ledger(tester).finance.ruleViews.first.destinationValid, isFalse);

    const top = 'The rule “Emergency top-up” sends money to this account. Change or delete it first';
    await _expectRefused(tester, w.closeAccount(savings), 'rule_points_here', top);
    await _expectRefused(tester, w.deleteAccount(savings), 'rule_points_here', top);

    // Once the rules are gone, it can.
    await runWrite(tester, w.deleteRule(trip));
    await runWrite(tester, w.deleteRule(topUp));
    await runWrite(tester, w.deleteGoal(ladakh));
    await runWrite(tester, w.closeAccount(savings));
    expect(_ledger(tester).finance.account(savings)!.closed, isTrue);
  });
}

extension on FinRule {
  FinRule withPercent(int bp) => FinRule(
    id: id,
    kind: kind,
    currency: currency,
    name: name,
    percentBp: bp,
    goalId: goalId,
    accountId: accountId,
    active: active,
    priority: priority,
  );
}

extension on RuleDraft {
  RuleDraft withGoal(String goalId) => RuleDraft(
    kind: kind,
    name: name,
    percentBp: percentBp,
    amountMinor: amountMinor,
    sourceCategoryId: sourceCategoryId,
    sourceAccountId: sourceAccountId,
    goalId: goalId,
  );

  RuleDraft withSource(String accountId) => RuleDraft(
    kind: kind,
    name: name,
    percentBp: percentBp,
    amountMinor: amountMinor,
    sourceAccountId: accountId,
    goalId: goalId,
    accountId: this.accountId,
  );
}
