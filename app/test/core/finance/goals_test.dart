import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/finance/finance.dart';
import 'package:splitkit/core/local/ledger.dart';

import 'finance_helpers.dart';

/// Goals on the device (core/finance/goals.dart and FinanceEngine's goals): progress by mode, the
/// timeline, behind and overdue, the estimate with returns, and the guards that mirror the
/// server's refusals. Day keys throughout; "today" is the fixtures' day, 25 Sep 2026.
void main() {
  const today = 20260925;

  FinGoal goal({
    String id = 'g1',
    String name = 'Trip',
    int target = 1000000,
    int? targetDay,
    GoalMode mode = GoalMode.contribution,
    String? account,
    int? manual,
    int? bp,
    GoalStatus status = GoalStatus.active,
    int startDay = 20260101,
    int priority = 0,
    int created = 0,
    String? deletedAt,
  }) => FinGoal(
    id: id,
    name: name,
    currency: 'INR',
    targetMinor: target,
    targetDay: targetDay,
    mode: mode,
    linkedAccountId: account,
    manualProgressMinor: manual,
    expectedReturnBp: bp,
    status: status,
    startDay: startDay,
    priority: priority,
    createdMicros: created,
    deletedAt: deletedAt,
  );

  var made = 0;
  FinContribution contribution(String goalId, int amount, {String? entryId, int day = 20260901, String? deletedAt}) =>
      FinContribution(
        id: 'c${made++}',
        goalId: goalId,
        amountMinor: amount,
        currency: 'INR',
        day: day,
        transactionId: entryId,
        createdMicros: made,
        deletedAt: deletedAt,
      );

  /// [g]'s figures from goalProgress with what it's given.
  GoalProgress progress(FinGoal g, {int contributed = 0, int? account, bool liability = false, int on = today}) =>
      goalProgress(
        g,
        today: on,
        contributedMinor: contributed,
        contributionCount: 0,
        accountValueMinor: account,
        accountIsLiability: liability,
      );

  test('reading synced rows: wire names, once per map, unknown modes and statuses left out', () {
    final raw = <String, dynamic>{
      'id': 'g',
      'name': 'Trip',
      'target_minor': 500000,
      'currency': 'INR',
      'target_date': '2027-05-31',
      'tracking_mode': 'linked_balance',
      'linked_account_id': 'a',
      'manual_progress_minor': null,
      'expected_return_bp': 80,
      'priority': 2,
      'status': 'paused',
      'created_at': '2026-08-20T15:30:00+00:00',
      'deleted_at': null,
      'version': 3,
    };
    final g = FinGoal.read(raw)!;
    expect(
      (g.mode, g.status, g.targetDay, g.linkedAccountId, g.expectedReturnBp, g.priority, g.version),
      (GoalMode.linkedBalance, GoalStatus.paused, 20270531, 'a', 80, 2, 3),
    );
    expect(identical(FinGoal.read(raw), g), isTrue);
    expect(FinGoal.read({...raw, 'tracking_mode': 'by_magic'}), isNull);
    expect(FinGoal.read({...raw, 'status': 'snoozed'}), isNull);
    final c = FinContribution.read({
      'id': 'c',
      'goal_id': 'g',
      'transaction_id': null,
      'amount_minor': 1500,
      'currency': 'INR',
      'date': '2026-08-31',
      'note': 'Jar',
      'created_at': '2026-08-31T14:30:00+00:00',
      'deleted_at': null,
      'version': 1,
    });
    expect((c.day, c.amountMinor, c.note, c.deleted), (20260831, 1500, 'Jar', false));
  });

  group('the seed on 25 Sep 2026', () {
    final fixture = jsonDecode(File('test/fixtures/sync/john.json').readAsStringSync()) as Map<String, dynamic>;
    final ledger = Ledger([
      for (final s in (fixture['snapshots'] as Map<String, dynamic>).entries)
        for (final e in (s.value['entities'] as List).cast<Map<String, dynamic>>())
          LocalEntity(s.key, e['entity'], e['entity_id'], e['version'], (e['data'] as Map).cast()),
    ], today: DateTime(2026, 9, 25));
    final goals = ledger.finance.goals(today: today);
    GoalProgress named(String name) => goals.firstWhere((g) => g.goal.name == name);

    test('by priority: Emergency fund, Ladakh trip, Gold coins', () {
      expect([for (final g in goals) g.goal.name], ['Emergency fund', 'Ladakh trip', 'Gold coins']);
      expect(identical(ledger.finance.goals(today: today), goals), isTrue, reason: 'remembered for the day');
    });

    test('Ladakh trip: ₹17,000 of ₹60,000, 9 months left, ₹4,777.78 a month, not behind', () {
      final ladakh = named('Ladakh trip');
      expect(
        (ladakh.progressMinor, ladakh.goal.targetMinor, ladakh.remainingMinor, ladakh.contributionCount),
        (1700000, 6000000, 4300000, 2),
      );
      expect((ladakh.monthsLeft, ladakh.requiredMonthlyMinor), (9, 477778));
      // Made on 20 Aug: 36 of 284 days along, so ₹7,605.63 expected by now.
      expect((ladakh.expectedMinor, ladakh.behind, ladakh.state), (760563, false, GoalState.onTrack));
      expect((ladakh.percentTrue, ladakh.percentShown), (28, 28));
      expect(ladakh.goal.startDay, 20260820);
    });

    test('Emergency fund follows Emergency savings: 44%, no date', () {
      final fund = named('Emergency fund');
      expect((fund.progressMinor, fund.percentShown, fund.issue), (12000000, 44, null));
      expect((fund.monthsLeft, fund.requiredMonthlyMinor, fund.state), (null, null, GoalState.noDate));
    });

    test('Gold coins, by hand: 34%', () {
      final gold = named('Gold coins');
      expect((gold.progressMinor, gold.percentShown, gold.state), (6800000, 34, GoalState.noDate));
    });

    test("the Ladakh trip's contributions, newest first, with the cash withdrawal's in-leg", () {
      final views = ledger.finance.contributionViews(named('Ladakh trip').goal.id);
      expect(
        [for (final v in views) (v.contribution.amountMinor, v.entryDescription, v.accountName)],
        [(200000, 'Cash withdrawal', 'Cash'), (1500000, null, null)],
      );
    });

    test('guards: savings is followed; Cash carries a contribution; what a goal can follow', () {
      final f = ledger.finance;
      final ladakh = named('Ladakh trip').goal, fund = named('Emergency fund').goal;
      final savings = fund.linkedAccountId!;
      final cash = f.accounts.firstWhere((a) => a.name == 'Cash').id;
      final guards = f.guards(named('Gold coins').goal.id);
      expect(guards.followedBy(savings)?.name, 'Emergency fund');
      expect(guards.countedTwiceIfLinkedTo(cash), isTrue);
      expect(guards.countedBy(cash)?.name, 'Ladakh trip');
      expect(guards.canArchiveOrSwitch, isTrue);
      // The fund's own account isn't followed by another goal.
      expect(f.guards(fund.id).followedBy(savings), isNull);
      expect([for (final a in f.followableAccounts()) a.name], ['Zerodha', 'HDFC ··4821', 'Cash']);
      expect([for (final a in f.followableAccounts(exceptGoalId: fund.id)) a.name], contains('Emergency savings'));
      // The jar's entry already counts; the 31 Aug contribution has none.
      final jarEntry = f.contributionsOf(ladakh.id).first.transactionId!;
      expect(
        f.contributionBlocker(goalId: ladakh.id, entryId: jarEntry, amountMinor: 1000)?.code,
        'already_contributed',
      );
      expect(
        f.contributionBlocker(
          goalId: ladakh.id,
          entryId: jarEntry,
          amountMinor: 200000,
          exceptContributionId: f.contributionsOf(ladakh.id).first.id,
        ),
        isNull,
      );
    });
  });

  group('progress by mode, never counted twice', () {
    test('contributions count only in contribution mode; a balance only when linked', () {
      final accounts = [account('savings', opening: 50000)];
      final engine = FinanceEngine(
        accounts: accounts,
        entries: const [],
        currency: 'INR',
        goals: [
          goal(id: 'linked', mode: GoalMode.linkedBalance, account: 'savings', created: 1),
          goal(id: 'saved', created: 2),
          goal(id: 'hand', mode: GoalMode.manual, manual: 7000, created: 3),
        ],
        contributions: [
          contribution('linked', 9000), // kept from before a switch: uncounted
          contribution('saved', 3000),
          contribution('saved', 2000),
          contribution('hand', 100),
        ],
      );
      final figures = {for (final g in engine.goals(today: today)) g.goal.id: g};
      expect((figures['linked']!.progressMinor, figures['linked']!.contributionCount), (50000, 1));
      expect((figures['saved']!.progressMinor, figures['saved']!.contributionCount), (5000, 2));
      expect((figures['hand']!.progressMinor, figures['hand']!.contributionCount), (7000, 1));
    });

    test("a contribution whose entry was deleted doesn't count; one whose entry hasn't synced does", () {
      final engine = FinanceEngine(
        accounts: const [],
        entries: [
          entry(id: 'gone', deletedAt: '2026-09-20T10:00:00Z'),
          entry(id: 'here'),
        ],
        currency: 'INR',
        goals: [goal()],
        contributions: [
          contribution('g1', 1000, entryId: 'gone'),
          contribution('g1', 300, entryId: 'here'),
          contribution('g1', 20, entryId: 'not-synced-yet'),
          contribution('g1', 5000, deletedAt: '2026-09-21T10:00:00Z'),
        ],
      );
      expect(engine.goal('g1', today: today)!.progressMinor, 320);
      expect(engine.contributionsOf('g1').length, 2);
      expect(engine.contributionFor('gone'), isNull);
      expect(engine.goal('missing', today: today), isNull);
    });

    test('a missing or deleted account gives no progress and says why; so does a card', () {
      final missing = progress(goal(mode: GoalMode.linkedBalance, account: 'x'));
      expect((missing.progressMinor, missing.issue), (0, GoalIssue.accountMissing));
      final card = progress(goal(mode: GoalMode.linkedBalance, account: 'card'), account: 40000, liability: true);
      expect((card.progressMinor, card.issue), (0, GoalIssue.followsLiability));
      final engine = FinanceEngine(
        accounts: [account('old', opening: 9000, deleted: true)],
        entries: const [],
        currency: 'INR',
        goals: [goal(mode: GoalMode.linkedBalance, account: 'old')],
      );
      expect(engine.goal('g1', today: today)!.issue, GoalIssue.accountMissing);
    });
  });

  group('the timeline', () {
    test('no date: progress only', () {
      final p = progress(goal(), contributed: 1000);
      expect(
        (p.monthsLeft, p.daysLeft, p.requiredMonthlyMinor, p.overdueDays, p.state),
        (null, null, null, null, GoalState.noDate),
      );
    });

    test('due this month, or today: 1 month left, the rest needed now', () {
      for (final day in [20260930, today]) {
        final p = progress(goal(targetDay: day), contributed: 400000);
        expect((p.monthsLeft, p.requiredMonthlyMinor, p.overdueDays), (1, 600000, null), reason: '$day');
      }
      expect(progress(goal(targetDay: today)).daysLeft, 0);
    });

    test('yesterday: overdue by a day, no months and no division', () {
      final p = progress(goal(targetDay: 20260924), contributed: 400000);
      expect((p.overdueDays, p.monthsLeft, p.requiredMonthlyMinor, p.state), (1, null, null, GoalState.overdue));
    });

    test('reached after its date: reached, not overdue', () {
      final p = progress(goal(targetDay: 20260801), contributed: 1000000);
      expect((p.state, p.overdueDays, p.requiredMonthlyMinor), (GoalState.reached, null, null));
    });

    test('months are counted across years, both ends included', () {
      expect(monthsLeftInclusive(20261215, 20270115), 2);
      expect(monthsLeftInclusive(20260925, 20270531), 9);
      expect(monthsLeftInclusive(20260925, 20260901), 1);
      expect(monthsLeftInclusive(20260925, 20260831), 0);
      expect(daysBetween(20260301, 20260401), 31);
      expect(daysBetween(20261231, 20270101), 1);
      expect(daysBetween(20260925, 20260924), -1);
    });

    test('what is needed each month is rounded up to the paisa', () {
      // ₹10,000 over 3 months: ₹3,333.34, so paying it reaches the target.
      final p = progress(goal(targetDay: 20261130), contributed: 0);
      expect((p.monthsLeft, p.requiredMonthlyMinor), (3, 333334));
    });
  });

  group('percentages', () {
    test('over the target: 100 shown, the true 140 kept, nothing left', () {
      final p = progress(goal(), contributed: 1400000);
      expect((p.percentShown, p.percentTrue, p.remainingMinor, p.barFraction, p.reached), (100, 140, 0, 1.0, true));
      expect(p.state, GoalState.reached);
    });

    test('never "100%" before it is reached', () {
      final p = progress(goal(), contributed: 999999);
      expect((p.percentShown, p.percentTrue, p.reached, p.remainingMinor), (99, 99, false, 1));
      expect(progress(goal()).percentShown, 0);
    });
  });

  group('behind', () {
    // Made on 1 Sep, due on 1 Oct 2026 (30 days): 24 days along on 25 Sep, so ₹8,000 expected.
    FinGoal along({int start = 20260901, GoalStatus status = GoalStatus.active}) =>
        goal(targetDay: 20261001, startDay: start, status: status);

    test('strictly below the line', () {
      expect(
        (progress(along(), contributed: 799999).behind, progress(along(), contributed: 799999).state),
        (true, GoalState.behind),
      );
      final onLine = progress(along(), contributed: 800000);
      expect((onLine.expectedMinor, onLine.behind, onLine.state), (800000, false, GoalState.onTrack));
    });

    test('not in the first 7 days', () {
      final six = progress(along(start: 20260919));
      expect((six.expectedMinor, six.behind), (null, false));
      final seven = progress(along(start: 20260918));
      expect(seven.behind, isTrue);
    });

    test('not when made after its date, paused, or reached', () {
      expect(progress(goal(targetDay: 20261001, startDay: 20261005)).expectedMinor, isNull);
      expect(progress(along(status: GoalStatus.paused)).behind, isFalse);
      expect(progress(along(), contributed: 1000000).behind, isFalse);
    });
  });

  test('state precedence: archived, completed, paused, reached, overdue, behind, on track, no date', () {
    final overdue = goal(targetDay: 20260901);
    expect(progress(goal(targetDay: 20260901, status: GoalStatus.archived)).state, GoalState.archived);
    expect(progress(goal(status: GoalStatus.completed), contributed: 1000000).state, GoalState.completed);
    expect(progress(goal(targetDay: 20260901, status: GoalStatus.paused)).state, GoalState.paused);
    expect(progress(overdue, contributed: 1000000).state, GoalState.reached);
    expect(progress(overdue).state, GoalState.overdue);
  });

  group('the estimate with returns', () {
    test('only for a goal that opted in and has a date', () {
      expect(progress(goal(bp: 80)).estimate, isNull);
      expect(progress(goal(targetDay: 20270925)).estimate, isNull);
      final p = progress(goal(targetDay: 20270831, bp: 80), contributed: 200000);
      expect(p.estimate!.monthlyReturnBp, 80);
      expect(p.estimate!.requiredMonthlyMinor, lessThan(p.requiredMonthlyMinor!));
      expect(p.estimate!.returnsAlone, isFalse);
    });

    test('no return is the plain split; returns alone give 0; rounded up', () {
      expect(returnAdjustedMonthly(targetMinor: 1000000, progressMinor: 0, months: 3, monthlyReturnBp: 0), 333334);
      expect(returnAdjustedMonthly(targetMinor: 1000000, progressMinor: 990000, months: 12, monthlyReturnBp: 100), 0);
      // 1% a month for 2 months from nothing: x·1.01 + x = 10,000 → 4,975.12…, rounded up.
      expect(returnAdjustedMonthly(targetMinor: 1000000, progressMinor: 0, months: 2, monthlyReturnBp: 100), 497513);
      expect(returnAdjustedMonthly(targetMinor: 1000000, progressMinor: 0, months: 0, monthlyReturnBp: 100), isNull);
      final alone = progress(goal(targetDay: 20270925, bp: 200), contributed: 900000);
      expect((alone.estimate!.requiredMonthlyMinor, alone.estimate!.returnsAlone), (0, true));
    });
  });

  group('contributionBlocker mirrors the server', () {
    final (out, into) = transfer(from: 'hdfc', to: 'savings', amount: 5000, outId: 'out', inId: 'in');
    final engine = FinanceEngine(
      accounts: [account('hdfc'), account('savings'), account('cash')],
      entries: [
        out,
        into,
        entry(id: 'spend', amount: 3000, accountId: 'cash'),
        entry(id: 'gone', deletedAt: 'x'),
      ],
      currency: 'INR',
      goals: [
        goal(id: 'trip', name: 'Trip', created: 1),
        goal(id: 'fund', name: 'Fund', mode: GoalMode.linkedBalance, account: 'savings', created: 2),
        goal(id: 'gold', name: 'Gold', mode: GoalMode.manual, manual: 1, created: 3),
        goal(id: 'old', name: 'Old', status: GoalStatus.archived, created: 4),
        goal(id: 'bin', name: 'Bin', deletedAt: 'x', created: 5),
        goal(id: 'car', name: 'Car', created: 6),
      ],
      contributions: [contribution('car', 1000, entryId: 'spend')],
    );
    String? code({String goalId = 'trip', String? entryId, int? amount, String? except}) => engine
        .contributionBlocker(goalId: goalId, entryId: entryId, amountMinor: amount, exceptContributionId: except)
        ?.code;

    test('the goal must take contributions', () {
      expect(code(), isNull);
      expect(code(goalId: 'fund'), 'goal_tracks_balance');
      expect(code(goalId: 'gold'), 'goal_is_manual');
      expect(code(goalId: 'old'), 'goal_archived');
      expect(code(goalId: 'bin'), 'unknown_goal');
      expect(
        engine.contributionBlocker(goalId: 'fund')?.message,
        "Fund follows an account's balance, so it takes no contributions",
      );
    });

    test('the entry: live, big enough, counted once, not moving a followed account', () {
      expect(code(entryId: 'gone'), 'unknown_transaction');
      expect(code(entryId: 'spend', amount: 3001), 'contribution_too_large');
      expect(code(entryId: 'spend', amount: 3000), 'already_contributed');
      expect(
        code(goalId: 'car', entryId: 'spend', amount: 3000, except: engine.contributionsOf('car').single.id),
        isNull,
      );
      // The transfer into savings, by either leg: the fund already counts it through the balance.
      for (final leg in ['in', 'out']) {
        final refusal = engine.contributionBlocker(goalId: 'trip', entryId: leg, amountMinor: 5000);
        expect(refusal, (
          code: 'counted_by_balance',
          message: 'Fund already counts that entry, through the balance of savings',
        ));
      }
    });
  });
}
