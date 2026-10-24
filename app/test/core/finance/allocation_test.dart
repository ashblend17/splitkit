import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/finance/finance.dart';
import 'package:app/core/local/ledger.dart';

import 'finance_helpers.dart';

// Allocation on the device (core/finance/allocation.dart, design §3.1 and §8 X2): planned amounts,
// which rules apply to an income, how an edit changes its plans, plans filled oldest first, the
// over-100% warning, planned against actual, and the seed's two plans.

FinRule rule(
  String id, {
  int? bp,
  int? fixed,
  String? goal,
  String? account,
  String? category,
  String? from,
  bool active = true,
  int priority = 0,
  int created = 0,
  String? deletedAt,
}) => FinRule(
  id: id,
  kind: fixed == null ? AllocationKind.percentage : AllocationKind.fixed,
  percentBp: fixed == null ? bp ?? 1000 : null,
  amountMinor: fixed,
  currency: 'INR',
  goalId: account == null ? goal ?? 'trip' : null,
  accountId: account,
  sourceCategoryId: category,
  sourceAccountId: from,
  active: active,
  priority: priority,
  createdMicros: created,
  deletedAt: deletedAt,
);

FinPlan plan(FinEntry income, FinRule r, int planned, {String? deletedAt, int created = 0}) => FinPlan(
  id: planId(income.id, r.id),
  sourceTransactionId: income.id,
  ruleId: r.id,
  snapshot: r.snapshot,
  plannedMinor: planned,
  currency: 'INR',
  goalId: r.goalId,
  accountId: r.accountId,
  createdMicros: created,
  deletedAt: deletedAt,
);

FinGoal goal(
  String id, {
  GoalMode mode = GoalMode.contribution,
  GoalStatus status = GoalStatus.active,
  String? deletedAt,
}) => FinGoal(
  id: id,
  name: id,
  currency: 'INR',
  targetMinor: 10000000,
  mode: mode,
  status: status,
  startDay: 20260101,
  linkedAccountId: mode == GoalMode.linkedBalance ? 'bank' : null,
  manualProgressMinor: mode == GoalMode.manual ? 0 : null,
  deletedAt: deletedAt,
);

var _made = 0;
FinContribution contribution(String goalId, int amount, int day) => FinContribution(
  id: 'c${_made++}',
  goalId: goalId,
  amountMinor: amount,
  currency: 'INR',
  day: day,
  createdMicros: _made,
);

FinanceEngine engine({
  List<FinEntry> entries = const [],
  List<FinRule> rules = const [],
  List<FinPlan> plans = const [],
  List<FinGoal>? goals,
  List<FinContribution> contributions = const [],
  List<FinAccount>? accounts,
}) => FinanceEngine(
  accounts: accounts ?? [account('bank'), account('savings'), account('closed', closed: true)],
  entries: entries,
  currency: 'INR',
  goals: goals ?? [goal('trip')],
  contributions: contributions,
  rules: rules,
  plans: plans,
);

FinEntry income({
  String? id,
  int amount = 8500000,
  int day = 20260901,
  String? category,
  String accountId = 'bank',
  String? deletedAt,
  String? expenseId,
  String currency = 'INR',
}) => entry(
  id: id,
  type: 'income',
  amount: amount,
  day: day,
  categoryId: category,
  accountId: accountId,
  deletedAt: deletedAt,
  expenseId: expenseId,
  currency: currency,
);

/// [e] with [changes] laid over its synced map.
FinEntry edited(FinEntry e, Map<String, dynamic> changes) => FinEntry({...e.raw, ...changes});

void main() {
  group('planned amounts', () {
    PlanSnapshot pct(int bp) => PlanSnapshot(kind: AllocationKind.percentage, percentBp: bp);

    test('a percentage rounds half away from zero; a fixed amount is as it is', () {
      expect(plannedMinor(pct(1000), 8500000), 850000); // 10% of ₹85,000
      expect(plannedMinor(pct(1500), 3333333), 500000); // 15% of ₹33,333.33 = 4,99,999.95 paise
      expect(plannedMinor(pct(1000), 5), 1); // half a paisa rounds up
      expect(plannedMinor(pct(1000), 4), 0);
      expect(plannedMinor(pct(1), 1), 0); // 1 bp of a paisa: no plan
      expect(plannedMinor(pct(100000), 1000), 10000); // 1000% is allowed
      const fixed = PlanSnapshot(kind: AllocationKind.fixed, amountMinor: 900000);
      expect(plannedMinor(fixed, 100), 900000); // even over the income
      // The largest product stays exact on the web: 9,99,99,99,999 × 1,00,000 < 2^53.
      expect(plannedMinor(pct(100000), 9999999999), 99999999990);
    });

    test('a planned amount of 0 makes no plan', () {
      final tiny = income(amount: 1);
      expect(engine(entries: [tiny], rules: [rule('r', bp: 1)]).plansForIncome(tiny), isEmpty);
    });
  });

  group('which rules apply', () {
    test('a live income in your currency, not linked to Split', () {
      expect(incomeEligible(income(), 'INR'), isTrue);
      expect(incomeEligible(income(deletedAt: '2026-09-02T00:00:00Z'), 'INR'), isFalse);
      expect(incomeEligible(income(expenseId: 'x'), 'INR'), isFalse);
      expect(incomeEligible(income(currency: 'USD'), 'INR'), isFalse);
      expect(incomeEligible(entry(type: 'expense'), 'INR'), isFalse);
    });

    test('filters: category by exact id, account, and a deleted account takes nothing', () {
      final salary = income(category: 'salary');
      final f = engine(
        entries: [salary],
        accounts: [account('bank'), account('gone', deleted: true)],
        rules: [
          rule('any', priority: 2),
          rule('salary', category: 'salary', priority: 1),
          rule('bonus', category: 'bonus'),
          rule('bank', from: 'bank', fixed: 100000),
          rule('other bank', from: 'savings'),
          rule('gone', from: 'gone'),
        ],
      );
      // In the rules' order: priority, then oldest, then id.
      expect([for (final d in f.plansForIncome(salary)) d.rule.id], ['bank', 'salary', 'any']);
      expect(
        [for (final d in f.plansForIncome(salary)) d.id],
        [planId(salary.id, 'bank'), planId(salary.id, 'salary'), planId(salary.id, 'any')],
      );
      expect(f.ruleViews.singleWhere((v) => v.rule.id == 'gone').sourceAccountGone, isTrue);
      expect(f.ruleViews.singleWhere((v) => v.rule.id == 'bank').sourceAccountGone, isFalse);
    });

    test('only active rules whose destination takes money now', () {
      final salary = income();
      final f = engine(
        entries: [salary],
        goals: [
          goal('trip'),
          goal('paused', status: GoalStatus.paused),
          goal('done', status: GoalStatus.completed),
          goal('linked', mode: GoalMode.linkedBalance),
          goal('gone', deletedAt: '2026-09-01T00:00:00Z'),
        ],
        rules: [
          rule('ok'),
          rule('off', active: false),
          rule('deleted', deletedAt: '2026-08-30T00:00:00Z'),
          rule('paused', goal: 'paused'),
          rule('done', goal: 'done'),
          rule('linked', goal: 'linked'),
          rule('gone', goal: 'gone'),
          rule('savings', account: 'savings', fixed: 500000),
          rule('closed', account: 'closed', fixed: 500000),
        ],
      );
      expect([for (final d in f.plansForIncome(salary)) d.rule.id], ['ok', 'savings']);
      // The deleted rule isn't listed; the paused goal's rule is, and says it takes no money now.
      expect(f.ruleViews.map((v) => v.rule.id), isNot(contains('deleted')));
      expect(f.ruleViews.singleWhere((v) => v.rule.id == 'paused').destinationValid, isFalse);
    });

    test('a rule applies only to incomes recorded after it was made', () {
      final r = rule('r', created: DateTime.utc(2026, 9, 10).microsecondsSinceEpoch);
      // A salary read from an old SMS (its SMS time is before the rule): no plan.
      final oldSms = entry(type: 'income', amount: 100000, day: 20260901, sms: true, accountId: 'bank');
      // A back-dated income typed in after the rule was made: plans.
      final typed = FinEntry({...income(day: 20260801).raw, 'created_at': DateTime.utc(2026, 9, 12).toIso8601String()});
      final f = engine(entries: [oldSms, typed], rules: [r]);
      expect(f.plansForIncome(oldSms), isEmpty);
      expect(f.plansForIncome(typed), hasLength(1));
    });
  });

  group('reconcilePlans', () {
    final trip = rule('trip');
    final savings = rule('savings', account: 'savings', fixed: 500000, priority: 1);

    test('a create plans with every rule that applies', () {
      final salary = income();
      final diff = engine(rules: [trip, savings]).reconcilePlans(before: null, after: salary);
      expect([for (final d in diff.create) (d.rule.id, d.plannedMinor)], [('trip', 850000), ('savings', 500000)]);
      expect(diff.deleteBefore, isEmpty);
    });

    test('an amount change recomputes with the plan\'s own snapshot, never the rule as it is now', () {
      final salary = income();
      final now20 = rule('trip', bp: 2000); // the rule was edited to 20% after the plan
      final f = engine(
        entries: [salary],
        rules: [now20, savings],
        plans: [plan(salary, trip, 850000), plan(salary, savings, 500000)],
      );
      final diff = f.reconcilePlans(before: salary, after: edited(salary, {'amount_minor': 9000000}));
      expect([for (final u in diff.update) (u.plan.ruleId, u.plannedMinor)], [('trip', 900000)]); // fixed is unchanged
      expect(diff.create, isEmpty);
    });

    test('a deleted rule\'s plans keep their snapshot too', () {
      final salary = income();
      final f = engine(
        entries: [salary],
        rules: [rule('trip', deletedAt: '2026-09-10T00:00:00Z')],
        plans: [plan(salary, trip, 850000)],
      );
      final diff = f.reconcilePlans(before: salary, after: edited(salary, {'amount_minor': 1000000}));
      expect([for (final u in diff.update) u.plannedMinor], [100000]);
    });

    test('a category change deletes what no longer applies and makes what now does', () {
      final salary = income(category: 'salary');
      final onSalary = rule('on salary', category: 'salary'), onBonus = rule('on bonus', category: 'bonus');
      final f = engine(entries: [salary], rules: [onSalary, onBonus], plans: [plan(salary, onSalary, 850000)]);
      final diff = f.reconcilePlans(before: salary, after: edited(salary, {'category_id': 'bonus'}));
      expect(diff.deleteAfter.map((p) => p.ruleId), ['on salary']);
      expect(diff.create.map((d) => d.rule.id), ['on bonus']);
      expect(diff.deleteBefore, isEmpty);
    });

    test('a re-match restores the deleted plan, with its new amount', () {
      final salary = income(category: 'bonus');
      final onSalary = rule('on salary', category: 'salary');
      final f = engine(
        entries: [salary],
        rules: [onSalary],
        plans: [plan(salary, onSalary, 850000, deletedAt: '2026-09-02T00:00:00Z')],
      );
      final diff = f.reconcilePlans(
        before: salary,
        after: edited(salary, {'category_id': 'salary', 'amount_minor': 9000000}),
      );
      expect([for (final r in diff.restore) (r.plan.ruleId, r.plannedMinor)], [('on salary', 900000)]);
      expect(diff.create, isEmpty);
    });

    test('a type change or a Split link deletes every live plan before the entry', () {
      final salary = income();
      final f = engine(
        entries: [salary],
        rules: [trip, savings],
        plans: [plan(salary, trip, 850000), plan(salary, savings, 500000, created: 1)],
      );
      final toTransfer = f.reconcilePlans(
        before: salary,
        after: edited(salary, {'type': 'transfer', 'direction': 'in'}),
      );
      expect(toTransfer.deleteBefore.map((p) => p.ruleId), ['trip', 'savings']);
      expect([...toTransfer.update, ...toTransfer.create, ...toTransfer.deleteAfter], isEmpty);
      final linked = f.reconcilePlans(before: salary, after: edited(salary, {'settlement_id': 's1'}));
      expect(linked.deleteBefore, hasLength(2));
      final deleted = f.reconcilePlans(before: salary, after: null);
      expect(deleted.deleteBefore, hasLength(2));
    });

    test('nothing plans read changed, or the amount alone: no new plans', () {
      final salary = income();
      final f = engine(entries: [salary], rules: [trip, savings], plans: [plan(salary, trip, 850000)]);
      expect(f.reconcilePlans(before: salary, after: edited(salary, {'notes': 'hi'})).isEmpty, isTrue);
      // Savings has no plan for this income, but an amount edit never adds one.
      final diff = f.reconcilePlans(before: salary, after: edited(salary, {'amount_minor': 9000000}));
      expect((diff.create.length, diff.update.length), (0, 1));
    });

    test('an old income edited never picks up a newer rule', () {
      final salary = income(category: 'bonus');
      final newer = rule('newer', category: 'salary', created: DateTime.utc(2027).microsecondsSinceEpoch);
      final diff = engine(
        entries: [salary],
        rules: [newer],
      ).reconcilePlans(before: salary, after: edited(salary, {'category_id': 'salary'}));
      expect(diff.isEmpty, isTrue);
    });

    test('a replay makes no duplicates: the same ids every time', () {
      final salary = income();
      final f = engine(rules: [trip, savings]);
      final once = f.reconcilePlans(before: null, after: salary).create.map((d) => d.id).toList();
      final twice = f.reconcilePlans(before: null, after: salary).create.map((d) => d.id).toList();
      expect(once, twice);
      expect(once, [planId(salary.id, 'trip'), planId(salary.id, 'savings')]);
    });
  });

  group('plan status', () {
    final trip = rule('trip'), save = rule('save', account: 'savings', fixed: 300000);

    test('money reaching a goal fills its plans oldest income first; what\'s left is surplus', () {
      final sep = income(id: 'sep', amount: 1000000, day: 20260901);
      final oct = income(id: 'oct', amount: 1000000, day: 20261001);
      final f = engine(
        entries: [sep, oct],
        rules: [trip],
        plans: [plan(oct, trip, 100000, created: 1), plan(sep, trip, 100000, created: 2)],
        contributions: [
          contribution('trip', 50000, 20260831), // before both incomes: surplus
          contribution('trip', 150000, 20260905), // fills September's; October's isn't due yet
          contribution('trip', 70000, 20261002),
        ],
      );
      final sepView = f.plansOfIncome('sep').single, octView = f.plansOfIncome('oct').single;
      expect((sepView.status, sepView.filledMinor, sepView.remainingMinor), (PlanStatus.fulfilled, 100000, 0));
      expect((octView.status, octView.filledMinor, octView.remainingMinor), (PlanStatus.partial, 70000, 30000));
      expect(f.plansTo(goalId: 'trip').map((v) => v.plan.sourceTransactionId), ['sep', 'oct']);
      expect(f.plansTo(goalId: 'trip', outstanding: true).map((v) => v.plan.sourceTransactionId), ['oct']);
      expect(f.outstandingTo(goalId: 'trip'), 30000);
    });

    test('an account plan is filled only by transfers into it from another account', () {
      final salary = income(id: 'salary', amount: 1000000, day: 20260901);
      final (out, into) = transfer(from: 'bank', to: 'savings', amount: 200000, day: 20260903);
      final f = engine(
        entries: [
          salary,
          out,
          into,
          // New money or a correction into savings isn't acting on the plan.
          income(id: 'interest', amount: 50000, day: 20260904, accountId: 'savings'),
          entry(type: 'adjustment', direction: 'in', amount: 90000, day: 20260905, accountId: 'savings'),
        ],
        rules: [save],
        plans: [plan(salary, save, 300000)],
      );
      final v = f.plansOfIncome('salary').single;
      expect((v.status, v.filledMinor), (PlanStatus.partial, 200000));
    });

    test('a plan whose income was deleted, or that was deleted, is cancelled', () {
      final gone = income(id: 'gone', deletedAt: '2026-09-03T00:00:00Z');
      final moved = income(id: 'moved', category: 'bonus');
      final f = engine(
        entries: [gone, moved],
        rules: [trip],
        plans: [
          plan(gone, trip, 850000, deletedAt: '2026-09-03T00:00:00Z'),
          plan(moved, trip, 850000, deletedAt: '2026-09-04T00:00:00Z'),
          FinPlan(
            id: 'orphan',
            sourceTransactionId: 'not here',
            ruleId: 'trip',
            snapshot: trip.snapshot,
            plannedMinor: 1,
            currency: 'INR',
            goalId: 'trip',
          ),
        ],
        contributions: [contribution('trip', 900000, 20260910)],
      );
      expect(
        [
          for (final id in [planId('gone', 'trip'), planId('moved', 'trip'), 'orphan'])
            (f.planViews[id]!.status, f.planViews[id]!.cancelReason, f.planViews[id]!.remainingMinor),
        ],
        [
          (PlanStatus.cancelled, CancelReason.incomeDeleted, 0),
          (PlanStatus.cancelled, CancelReason.noLongerApplies, 0),
          (PlanStatus.cancelled, CancelReason.incomeDeleted, 0),
        ],
      );
      expect(f.plansTo(goalId: 'trip'), isEmpty);
    });

    test('plans never count as progress', () {
      final salary = income();
      final contributions = [contribution('trip', 200000, 20260912)];
      final without = engine(entries: [salary], contributions: contributions);
      final withPlans = engine(
        entries: [salary],
        contributions: contributions,
        rules: [trip],
        plans: [plan(salary, trip, 850000)],
      );
      expect(
        withPlans.goal('trip', today: 20260925)!.progressMinor,
        without.goal('trip', today: 20260925)!.progressMinor,
      );
    });
  });

  group('the over-100% warning', () {
    test('with no filters it is the sum of active percentages; the rules are never changed', () {
      final rules = [rule('a', bp: 6000), rule('b', bp: 5000), rule('off', bp: 9000, active: false)];
      final f = engine(rules: rules);
      final load = f.allocationLoad();
      expect((load.worstBp, load.over100, load.categoryId, load.accountId), (11000, true, null, null));
      expect(f.liveRules.map((r) => r.percentBp), [6000, 5000, 9000]);
    });

    test('the worst case per category and account; fixed amounts apart', () {
      final f = engine(
        rules: [
          rule('salary 60', bp: 6000, category: 'salary'),
          rule('salary hdfc 30', bp: 3000, category: 'salary', from: 'bank'),
          rule('any 20', bp: 2000),
          rule('bonus 80', bp: 8000, category: 'bonus'),
          rule('fixed any', fixed: 100000),
          rule('fixed hdfc', fixed: 200000, from: 'bank'),
          rule('gone account', bp: 50000, from: 'nowhere'),
        ],
      );
      expect(
        f.allocationLoad(),
        const AllocationLoad(worstBp: 11000, fixedMinor: 300000, categoryId: 'salary', accountId: 'bank'),
      );
    });

    test('a draft is counted as it would be, replacing the rule it edits', () {
      final f = engine(rules: [rule('a', bp: 6000), rule('b', bp: 3000)]);
      expect(f.allocationLoad().over100, isFalse);
      expect(f.allocationLoad(draft: rule('b', bp: 5000)).worstBp, 11000);
      expect(f.allocationLoad(draft: rule('new', bp: 2000)).worstBp, 11000);
      expect(f.allocationLoad(draft: rule('a', bp: 6000, active: false)).worstBp, 3000);
    });
  });

  test('planned vs actual: plans from the month\'s incomes, per destination', () {
    final trip = rule('trip'), save = rule('save', account: 'savings', fixed: 300000);
    final sep = income(id: 'sep', amount: 1000000, day: 20260901);
    final aug = income(id: 'aug', amount: 1000000, day: 20260801);
    final (out, into) = transfer(from: 'bank', to: 'savings', amount: 100000, day: 20260902);
    final f = engine(
      entries: [sep, aug, out, into],
      rules: [trip, save],
      plans: [plan(sep, trip, 100000), plan(sep, save, 300000), plan(aug, trip, 100000)],
      contributions: [contribution('trip', 250000, 20260905)],
    );
    final september = f.plannedVsActual(monthRange(2026, 9));
    expect(
      (september.plannedMinor, september.actualMinor, september.hasRules, september.isEmpty),
      (400000, 200000, true, false),
    );
    expect(
      [for (final r in september.rows) (r.goalId, r.accountId, r.plannedMinor, r.actualMinor)],
      [(null, 'savings', 300000, 100000), ('trip', null, 100000, 100000)],
    );
    expect(identical(f.plannedVsActual(monthRange(2026, 9)), september), isTrue);
    final july = f.plannedVsActual(monthRange(2026, 7));
    expect((july.isEmpty, july.hasRules), (true, true));
    expect(engine().plannedVsActual(monthRange(2026, 9)).hasRules, isFalse);
  });

  test('rulesPointingAt: live rules, active or not, oldest first', () {
    final f = engine(
      rules: [
        rule('newer', created: 2),
        rule('older', active: false, created: 1),
        rule('deleted', deletedAt: '2026-09-01T00:00:00Z'),
        rule('to savings', account: 'savings', fixed: 1),
      ],
    );
    expect(f.rulesPointingAt(goalId: 'trip'), ['older', 'newer']);
    expect(f.rulesPointingAt(accountId: 'savings'), ['to savings']);
    expect(f.rulesPointingAt(accountId: 'bank'), isEmpty);
    expect(f.guards('trip').canArchiveOrSwitch, isFalse);
  });

  test('the seed: the trip plan is ₹8,500 with ₹2,000 filled; the savings top-up ₹5,000, planned', () {
    final fixture = jsonDecode(File('test/fixtures/sync/john.json').readAsStringSync()) as Map<String, dynamic>;
    final ledger = Ledger([
      for (final s in (fixture['snapshots'] as Map).entries)
        for (final e in ((s.value as Map)['entities'] as List).cast<Map<String, dynamic>>())
          LocalEntity(s.key, e['entity'], e['entity_id'], e['version'], (e['data'] as Map).cast()),
    ], today: DateTime(2026, 9, 25));
    final f = ledger.finance;
    final ladakh = f.liveGoals.singleWhere((g) => g.name == 'Ladakh trip').id;
    final savings = f.accounts.singleWhere((a) => a.name == 'Emergency savings').id;
    final salary = f.planViews.values.first.plan.sourceTransactionId;
    expect(
      [for (final v in f.plansOfIncome(salary)) (v.plan.goalId ?? v.plan.accountId, v.status, v.filledMinor)],
      [
        (ladakh, PlanStatus.partial, 200000), // the jar; the ₹15,000 on 31 Aug came before the salary
        (savings, PlanStatus.planned, 0),
      ],
    );
    expect([for (final v in f.plansOfIncome(salary)) v.plan.plannedMinor], [850000, 500000]);
    expect(f.outstandingTo(goalId: ladakh), 650000);
    final sep = f.plannedVsActual(monthRange(2026, 9));
    expect((sep.plannedMinor, sep.actualMinor), (1350000, 200000));
    expect(
      [for (final v in f.ruleViews) (describeRuleName(v.rule), v.planCount, v.destinationValid)],
      [("10%", 1, true), ("Emergency top-up", 1, true)],
    );
    expect(f.allocationLoad(), const AllocationLoad(worstBp: 1000, fixedMinor: 500000));
    expect(f.rulesPointingAt(goalId: ladakh), hasLength(1));
    expect(f.rulesPointingAt(accountId: savings), hasLength(1));
    // Plans never move progress: still ₹17,000 of ₹60,000.
    expect(f.goal(ladakh, today: 20260925)!.progressMinor, 1700000);
  });
}

String describeRuleName(FinRule r) => r.name ?? '${r.percentBp! ~/ 100}%';
