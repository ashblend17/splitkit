import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/finance/finance.dart';
import 'package:splitkit/core/local/ledger.dart';
import 'package:splitkit/core/local/outbox.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/local/writes.dart';

import '../fake_backend.dart';

// Goal and contribution writes (core/local/writes_goals.dart) against the seed's sync snapshot,
// offline, so every write stays queued and the test reads what it would send and what it shows.
// The seed: Emergency fund follows Emergency savings, the Ladakh trip counts contributions (₹15,000
// with no entry, and ₹2,000 from the 12 Sep cash withdrawal's in-leg), Gold coins is tracked by hand.

Ledger _ledger(WidgetTester tester) => appContainer(tester).read(localStoreProvider).value!.ledger;
LocalWrites _writes(WidgetTester tester) => appContainer(tester).read(writesProvider);
List<OutboxOp> _ops(WidgetTester tester) => appContainer(tester).read(outboxProvider);

String _goal(Ledger l, String name) => l.personalGoalList().firstWhere((g) => g['name'] == name)['id'] as String;
String _account(Ledger l, String name) => l.personalAccountList().firstWhere((a) => a['name'] == name)['id'] as String;

/// A transfer's legs in the seed, out first.
(Json, Json) _legs(Ledger l, String description) {
  final legs = [
    for (final t in (l.personalList(type: 'transfer', limit: 1 << 20)['items'] as List).cast<Json>())
      if (t['description'] == description) t,
  ];
  return legs[0]['direction'] == 'out' ? (legs[0], legs[1]) : (legs[1], legs[0]);
}

List<Json> _items(OutboxOp op) {
  // The request parses as the generated client's model, so its shape can't drift from the API's.
  expect(PersonalMixedBatchIn.fromJson(op.body), isNotNull);
  return (op.body!['items'] as List).cast<Json>();
}

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

int _progress(WidgetTester tester, String goalId) =>
    _ledger(tester).finance.goal(goalId, today: 20260925)!.progressMinor;

void main() {
  testWidgets('a new goal: POST /personal/goals with every key, shown at once', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    final zerodha = _account(_ledger(tester), 'Zerodha');

    final id = await runWrite(
      tester,
      w.createGoal(
        GoalDraft(
          name: ' New laptop ',
          targetMinor: 15000000,
          targetDate: DateTime(2027, 3, 31),
          mode: GoalMode.linkedBalance,
          linkedAccountId: zerodha,
          manualProgressMinor: 5000, // not this mode's: sent empty
        ),
      ),
    );
    final op = _ops(tester).single;
    expect((op.method, op.path, op.label), ('POST', '/api/v1/personal/goals', 'Added goal New laptop'));
    expect(PersonalGoalIn.fromJson(op.body), isNotNull);
    expect(
      (
        op.body!['id'],
        op.body!['target_date'],
        op.body!['tracking_mode'],
        op.body!['linked_account_id'],
        op.body!['manual_progress_minor'],
        op.body!['status'],
      ),
      (id, '2027-03-31', 'linked_balance', zerodha, null, 'active'),
    );
    expect([for (final e in op.entities) (e.entity, e.entityId, e.version)], [('personal_goal', id, 1)]);
    final l = _ledger(tester);
    expect(l.personalGoal(id)['name'], 'New laptop');
    expect(l.finance.goal(id, today: 20260925)!.issue, isNull);
  });

  testWidgets('a goal is refused as the server refuses it', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    final l = _ledger(tester);
    final savings = _account(l, 'Emergency savings'), cash = _account(l, 'Cash'), hdfc = _account(l, 'HDFC ··4821');
    GoalDraft linked(String account) =>
        GoalDraft(name: 'Rainy day', targetMinor: 100000, mode: GoalMode.linkedBalance, linkedAccountId: account);

    await _expectRefused(
      tester,
      w.createGoal(linked(savings)),
      'account_followed',
      'Emergency fund already follows Emergency savings',
    );
    // The jar's entry is the cash withdrawal: its in-leg moved Cash, its out-leg HDFC.
    await _expectRefused(
      tester,
      w.createGoal(linked(cash)),
      'counted_by_contribution',
      'An entry in Cash already counts toward Ladakh trip',
    );
    await _expectRefused(
      tester,
      w.createGoal(linked(hdfc)),
      'counted_by_contribution',
      'An entry in HDFC ··4821 already counts toward Ladakh trip',
    );
    await _expectRefused(
      tester,
      w.createGoal(const GoalDraft(name: 'Rainy day', targetMinor: 100000, mode: GoalMode.linkedBalance)),
      'account_required',
    );
    await _expectRefused(
      tester,
      w.createGoal(const GoalDraft(name: 'Rainy day', targetMinor: 100000, mode: GoalMode.manual)),
      'progress_required',
    );
    await _expectRefused(tester, w.createGoal(const GoalDraft(name: '  ', targetMinor: 100000)), 'invalid_input');
    await _expectRefused(tester, w.createGoal(const GoalDraft(name: 'Trip', targetMinor: 0)), 'invalid_input');
  });

  testWidgets("switching a goal's mode nulls the old mode's field; a starting amount is one batch", (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    var l = _ledger(tester);
    final ladakh = _goal(l, 'Ladakh trip'), gold = _goal(l, 'Gold coins');

    // Ladakh by hand from now on: its contributions are kept, uncounted.
    await runWrite(tester, w.switchGoalMode(ladakh, GoalMode.manual, manualProgressMinor: 2500000));
    var op = _ops(tester).last;
    expect((op.method, op.path, op.body!['version']), ('PUT', '/api/v1/personal/goals/$ladakh', 1));
    expect(
      (
        op.body!['tracking_mode'],
        op.body!['manual_progress_minor'],
        op.body!['linked_account_id'],
        op.body!['target_date'],
      ),
      ('manual', 2500000, null, '2027-05-31'),
    );
    l = _ledger(tester);
    final figures = l.finance.goal(ladakh, today: 20260925)!;
    expect((figures.progressMinor, figures.contributionCount), (2500000, 2));

    // Gold coins counts contributions from now on, starting with what it had: one request.
    await runWrite(tester, w.switchGoalMode(gold, GoalMode.contribution, startingContributionMinor: 6800000));
    op = _ops(tester).last;
    expect((op.method, op.path, op.label), ('POST', '/api/v1/personal/batch', 'Changed how Gold coins is tracked'));
    final items = _items(op);
    expect(
      [for (final i in items) (i['kind'], i['op'], i['version'])],
      [('goal', 'update', 1), ('goal_contribution', 'create', null)],
    );
    final goalBody = (items[0]['goal'] as Map).cast<String, dynamic>();
    expect(
      (goalBody['tracking_mode'], goalBody['manual_progress_minor'], goalBody['id'], goalBody['version']),
      ('contribution', null, null, null),
    );
    final starting = (items[1]['goal_contribution'] as Map).cast<String, dynamic>();
    expect(
      (starting['goal_id'], starting['amount_minor'], starting['date'], starting['note']),
      (gold, 6800000, '2026-09-25', 'Starting amount'),
    );
    expect(
      [for (final e in op.entities) (e.entity, e.version)],
      [('personal_goal', 2), ('personal_goal_contribution', 1)],
    );
    expect(_progress(tester, gold), 6800000);

    // Following an account another goal follows is refused.
    final savings = _account(_ledger(tester), 'Emergency savings');
    await _expectRefused(
      tester,
      w.switchGoalMode(gold, GoalMode.linkedBalance, linkedAccountId: savings),
      'account_followed',
    );
  });

  testWidgets('status and progress: archive, pause, complete; update progress by hand', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    final l = _ledger(tester);
    final ladakh = _goal(l, 'Ladakh trip'), gold = _goal(l, 'Gold coins');

    await runWrite(tester, w.setGoalStatus(ladakh, GoalStatus.paused));
    expect((_ops(tester).last.body!['status'], _ops(tester).last.label), ('paused', 'Paused Ladakh trip'));
    await runWrite(tester, w.setGoalStatus(ladakh, GoalStatus.active));
    expect((_ops(tester).last.body!['status'], _ops(tester).last.body!['version']), ('active', 2));
    expect(_ops(tester).last.label, 'Resumed Ladakh trip');
    await runWrite(tester, w.setGoalStatus(ladakh, GoalStatus.archived));
    expect(_ledger(tester).finance.goal(ladakh, today: 20260925)!.state, GoalState.archived);
    // An archived goal takes nothing.
    await _expectRefused(
      tester,
      w.addContribution(goalId: ladakh, amountMinor: 1000, date: DateTime(2026, 9, 25)),
      'goal_archived',
      'Ladakh trip is archived',
    );
    final queued = _ops(tester).length;
    await runWrite(tester, w.setGoalStatus(ladakh, GoalStatus.archived));
    expect(_ops(tester).length, queued, reason: 'already archived: nothing queued');

    await runWrite(tester, w.setGoalProgress(gold, 7000000));
    expect(
      (_ops(tester).last.body!['manual_progress_minor'], _ops(tester).last.label),
      (7000000, 'Updated progress on Gold coins'),
    );
    expect(_progress(tester, gold), 7000000);
    await _expectRefused(tester, w.setGoalProgress(ladakh, 100), 'progress_not_used');
  });

  testWidgets("deleting a goal takes its contributions; restoring brings them back", (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    var l = _ledger(tester);
    final ladakh = _goal(l, 'Ladakh trip');
    final contributions = [for (final c in l.goalContributionList(goalId: ladakh)) c['id']];
    expect(contributions, hasLength(2));

    await runWrite(tester, w.deleteGoal(ladakh));
    var op = _ops(tester).single;
    expect((op.method, op.path, op.query['version']), ('DELETE', '/api/v1/personal/goals/$ladakh', '1'));
    // The goal first (keepMine re-versions by it), then its contributions in any order.
    expect((op.entities.first.entityId, op.entities.first.version), (ladakh, 2));
    expect([
      for (final e in op.entities.skip(1)) (e.entityId, e.version),
    ], unorderedEquals([for (final c in contributions) (c, 2)]));
    expect(op.entities.map((e) => e.data['deleted_at']).toSet(), hasLength(1));
    l = _ledger(tester);
    expect(l.finance.goal(ladakh, today: 20260925), isNull);
    expect(l.goalContributionList(goalId: ladakh), isEmpty);
    expect(l.goalContributionList(goalId: ladakh, deleted: true), hasLength(2));

    await runWrite(tester, w.restoreGoal(ladakh));
    op = _ops(tester).last;
    expect((op.method, op.path, op.query['version']), ('POST', '/api/v1/personal/goals/$ladakh/restore', '2'));
    expect([
      for (final e in op.entities) (e.entityId, e.version, e.data['deleted_at']),
    ], unorderedEquals([(ladakh, 3, null), for (final c in contributions) (c, 3, null)]));
    expect(op.entities.first.entityId, ladakh);
    expect(_progress(tester, ladakh), 1700000);
  });

  testWidgets('contributions: a plain amount, from an entry, edited and deleted', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    final l = _ledger(tester);
    final ladakh = _goal(l, 'Ladakh trip');

    final id = await runWrite(
      tester,
      w.addContribution(goalId: ladakh, amountMinor: 300000, date: DateTime(2026, 9, 25), note: ' Bonus '),
    );
    var op = _ops(tester).last;
    expect(
      (op.method, op.path, op.label),
      ('POST', '/api/v1/personal/goal-contributions', 'Added ₹3,000 to Ladakh trip'),
    );
    expect(PersonalGoalContributionIn.fromJson(op.body), isNotNull);
    expect(
      (op.body!['id'], op.body!['date'], op.body!['transaction_id'], op.body!['note']),
      (id, '2026-09-25', null, 'Bonus'),
    );
    expect(_progress(tester, ladakh), 2000000);

    await runWrite(tester, w.updateContribution(id, amountMinor: 250000, note: ''));
    op = _ops(tester).last;
    expect(
      (op.method, op.path, op.body!['version'], op.body!['amount_minor'], op.body!['note']),
      ('PUT', '/api/v1/personal/goal-contributions/$id', 1, 250000, null),
    );
    expect(_progress(tester, ladakh), 1950000);

    await runWrite(tester, w.deleteContribution(id));
    op = _ops(tester).last;
    expect((op.method, op.path, op.query['version']), ('DELETE', '/api/v1/personal/goal-contributions/$id', '2'));
    expect(_progress(tester, ladakh), 1700000);
    await runWrite(tester, w.restoreContribution(id));
    expect(_ops(tester).last.path, '/api/v1/personal/goal-contributions/$id/restore');
    expect(_progress(tester, ladakh), 1950000);

    // From an entry: at most the entry's amount.
    final spend = (l.personalList(limit: 1 << 20)['items'] as List).cast<Json>().firstWhere(
      (t) => t['type'] == 'expense' && t['expense_id'] == null && t['settlement_id'] == null,
    );
    final amount = spend['amount_minor'] as int;
    await _expectRefused(
      tester,
      w.addContribution(goalId: ladakh, amountMinor: amount + 1, date: DateTime(2026, 9, 25), entryId: spend['id']),
      'contribution_too_large',
      "A contribution can't be more than its entry",
    );
    await runWrite(
      tester,
      w.addContribution(goalId: ladakh, amountMinor: amount, date: DateTime(2026, 9, 25), entryId: spend['id']),
    );
    expect(_ops(tester).last.body!['transaction_id'], spend['id']);
  });

  testWidgets('money moved or invested for a goal: the entry and the contribution in one batch', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    final l = _ledger(tester);
    final ladakh = _goal(l, 'Ladakh trip');
    final hdfc = _account(l, 'HDFC ··4821'), cash = _account(l, 'Cash'), zerodha = _account(l, 'Zerodha');
    final day = DateTime(2026, 9, 25);

    final moved = await runWrite(
      tester,
      w.contributeByTransfer(goalId: ladakh, fromAccountId: hdfc, toAccountId: cash, amountMinor: 400000, date: day),
    );
    var op = _ops(tester).last;
    expect(op.label, 'Added ₹4,000 to Ladakh trip');
    var items = _items(op);
    expect(
      [for (final i in items) (i['kind'], i['op'])],
      [('transaction', 'create'), ('transaction', 'create'), ('goal_contribution', 'create')],
    );
    final inLeg = items[1];
    expect(
      ((inLeg['transaction'] as Map)['direction'], (inLeg['transaction'] as Map)['description']),
      ('in', 'Saved for Ladakh trip'),
    );
    expect((items[2]['id'], (items[2]['goal_contribution'] as Map)['transaction_id']), (moved, inLeg['id']));
    expect(_progress(tester, ladakh), 2100000);

    await runWrite(
      tester,
      w.contributeByInvestment(goalId: ladakh, fromAccountId: zerodha, amountMinor: 100000, date: day, note: 'SIP'),
    );
    op = _ops(tester).last;
    items = _items(op);
    expect(
      [for (final i in items) (i['kind'], (i['transaction'] as Map?)?['type'])],
      [('transaction', 'investment_contribution'), ('goal_contribution', null)],
    );
    expect((items[1]['goal_contribution'] as Map)['transaction_id'], items[0]['id']);
    expect(_progress(tester, ladakh), 2200000);

    // Into an account a goal follows: its balance counts it already.
    await _expectRefused(
      tester,
      w.contributeByTransfer(
        goalId: ladakh,
        fromAccountId: hdfc,
        toAccountId: _account(l, 'Emergency savings'),
        amountMinor: 1000,
        date: day,
      ),
      'counted_by_balance',
    );
  });

  testWidgets('a contribution is refused as the server refuses it', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    var l = _ledger(tester);
    final ladakh = _goal(l, 'Ladakh trip'), fund = _goal(l, 'Emergency fund'), gold = _goal(l, 'Gold coins');
    final day = DateTime(2026, 9, 25);
    final (_, jarLeg) = _legs(l, 'Cash withdrawal');

    await _expectRefused(
      tester,
      w.addContribution(goalId: fund, amountMinor: 1000, date: day),
      'goal_tracks_balance',
      "Emergency fund follows an account's balance, so it takes no contributions",
    );
    await _expectRefused(
      tester,
      w.addContribution(goalId: gold, amountMinor: 1000, date: day),
      'goal_is_manual',
      'Gold coins is tracked by hand, so it takes no contributions',
    );
    await _expectRefused(
      tester,
      w.addContribution(goalId: gold, amountMinor: 1000, date: day, entryId: jarLeg['id']),
      'goal_is_manual',
    );
    await _expectRefused(
      tester,
      w.addContribution(goalId: ladakh, amountMinor: 1000, date: day, entryId: jarLeg['id']),
      'already_contributed',
      'That entry already counts toward Ladakh trip',
    );

    // An account a goal follows can't be deleted (Emergency savings has no entries).
    await _expectRefused(
      tester,
      w.deleteAccount(_account(l, 'Emergency savings')),
      'account_in_use',
      "A goal follows this account's balance, so it can't be deleted",
    );

    // Money moved into Emergency savings already counts toward the fund, through its balance.
    final savings = _account(l, 'Emergency savings'), hdfc = _account(l, 'HDFC ··4821');
    final group = await runWrite(
      tester,
      w.createTransfer(
        fromAccountId: hdfc,
        toAccountId: savings,
        amountMinor: 500000,
        date: day,
        description: 'Top-up',
      ),
    );
    l = _ledger(tester);
    final inLeg = l.finance.transferLegs(group).firstWhere((e) => e.flow == MoneyFlow.inflow);
    await _expectRefused(
      tester,
      w.addContribution(goalId: ladakh, amountMinor: 500000, date: day, entryId: inLeg.id),
      'counted_by_balance',
      'Emergency fund already counts that entry, through the balance of Emergency savings',
    );
  });

  testWidgets("an entry's delete and restore take its contributions; it can't shrink below one", (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    var l = _ledger(tester);
    final ladakh = _goal(l, 'Ladakh trip');
    final (out, into) = _legs(l, 'Cash withdrawal');
    final jar = l.rawContributionsOf(entryId: into['id']).single['id'];

    // ₹2,000 of the withdrawal is the jar.
    await _expectRefused(
      tester,
      w.updateTransfer(out['transfer_group_id'], amountMinor: 150000),
      'contribution_too_large',
      '₹2,000 of this entry counts toward Ladakh trip. Lower that contribution first',
    );
    // Moving the cash into Emergency savings would count the jar twice.
    await _expectRefused(
      tester,
      w.updateTransfer(out['transfer_group_id'], toAccountId: _account(l, 'Emergency savings')),
      'counted_by_balance',
      'Emergency fund already counts that entry, through the balance of Emergency savings',
    );

    await runWrite(tester, w.deletePersonal(out['id']));
    var op = _ops(tester).single;
    expect([for (final e in op.entities) (e.entityId, e.version)], [(out['id'], 2), (into['id'], 2), (jar, 2)]);
    expect(_progress(tester, ladakh), 1500000);

    await runWrite(tester, w.restorePersonal(out['id']));
    op = _ops(tester).last;
    expect(
      [for (final e in op.entities) (e.entityId, e.version, e.data['deleted_at'])],
      [(out['id'], 3, null), (into['id'], 3, null), (jar, 3, null)],
    );
    expect(_progress(tester, ladakh), 1700000);
  });
}
