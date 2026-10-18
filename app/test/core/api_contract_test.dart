import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';

/// Real responses captured from the seeded API (test/fixtures/api) must parse with the
/// generated client. Catches drift between server output and the OpenAPI spec.
dynamic fixture(String name) => jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync());

void main() {
  test('login', () {
    final t = TokenOut.fromJson(fixture('login'))!;
    expect((t.user.name, t.user.role, t.tokenType), ('John Doe', 'admin', 'bearer'));
  });

  test('groups', () {
    final groups = GroupOut.listFromJson(fixture('groups'));
    final goa = groups.firstWhere((g) => g.name == 'Goa Trip');
    expect((goa.totalSpentMinor, goa.myNetMinor, goa.members.length), (4826000, 115000, 6));
    expect(goa.members.firstWhere((m) => m.placeholderName != null).placeholderName, 'Kabir M.');
  });

  test('overall and group balances', () {
    final overall = OverallBalancesOut.fromJson(fixture('balances'))!;
    expect((overall.totals.single.youOweMinor, overall.totals.single.youAreOwedMinor), (0, 147000));
    final goa = GroupBalancesOut.fromJson(fixture('group_balances'))!;
    expect(goa.people.map((p) => (p.user.name, p.netMinor)).first, ('Kabir Mehta', -75000));
    expect(goa.suggested, isNotEmpty);
  });

  test('feed and expense detail', () {
    final feed = FeedItem.listFromJson(fixture('feed'));
    expect(feed.first.title, 'Dinner at Thalassa');
    expect(feed.first.myNetMinor, -45000);
    final settlement = feed.firstWhere((i) => i.kind == FeedItemKindEnum.settlement);
    expect((settlement.title, settlement.toUser?.name), (null, 'Rahul Sharma'));

    final e = ExpenseOut.fromJson(fixture('expense'))!;
    expect(e.splits.map((s) => s.shareMinor), [45000, 45000, 45000, 45000]);
    expect(e.category?.label, 'Food');
    expect(e.deletedAt, isNull);
  });

  test('split methods and categories drive the UI', () {
    expect(SplitMethodOut.listFromJson(fixture('split_methods')).map((m) => m.key), [
      'equal',
      'exact',
      'percent',
      'shares',
    ]);
    expect(CategoryOut.listFromJson(fixture('categories')).first.label, 'Food');
  });

  test('personal accounts, and the labels with what their bank reported', () {
    final accounts = PersonalAccountOut.listFromJson(fixture('personal_accounts'));
    final hdfc = accounts.firstWhere((a) => a.smsLabel == 'HDFC ··4821');
    expect(
      (hdfc.type, hdfc.openingBalanceMinor, hdfc.status),
      (PersonalAccountOutTypeEnum.bank, 2748000, PersonalAccountOutStatusEnum.active),
    );
    expect(accounts.map((a) => a.type), contains(PersonalAccountOutTypeEnum.creditCard));
    final reported = AccountOut.listFromJson(fixture('personal_accounts_reported'));
    expect((reported.first.account, reported.first.balanceMinor), ('HDFC ··4821', 3993600));
  });

  test('goals, one per tracking mode, and the Ladakh trip\'s contributions', () {
    final goals = PersonalGoalOut.listFromJson(fixture('personal_goals'));
    expect(
      [for (final g in goals) (g.name, g.trackingMode.value, g.priority)],
      [('Emergency fund', 'linked_balance', 0), ('Ladakh trip', 'contribution', 1), ('Gold coins', 'manual', 2)],
    );
    expect(goals[0].linkedAccountId, isNotNull);
    expect(goals[2].manualProgressMinor, 6800000);
    final date = goals[1].targetDate!;
    expect((date.year, date.month, date.day), (2027, 5, 31));
    final contributions = PersonalGoalContributionOut.listFromJson(fixture('goal_contributions'));
    expect(
      [for (final c in contributions) (c.amountMinor, c.note, c.transactionId != null, c.goalId == goals[1].id)],
      [(200000, 'Trip jar', true, true), (1500000, 'Saved before I started tracking', false, true)],
    );
  });

  test('allocation rules (a percentage to a goal, a fixed amount to an account) and their plans', () {
    final rules = PersonalAllocationRuleOut.listFromJson(fixture('allocation_rules'));
    expect(
      [for (final r in rules) (r.name, r.kind.value, r.percentBp, r.amountMinor, r.goalId != null, r.priority)],
      [(null, 'percentage', 1000, null, true, 0), ('Emergency top-up', 'fixed', null, 500000, false, 1)],
    );
    expect(rules.first.trigger.value, 'income_recorded');
    final plans = PersonalAllocationPlanOut.listFromJson(fixture('allocation_plans'));
    expect(
      [for (final p in plans) (p.ruleId, p.snapshotKind.value, p.plannedMinor)],
      [(rules[0].id, 'percentage', 850000), (rules[1].id, 'fixed', 500000)],
    );
    expect(plans.map((p) => p.sourceTransactionId).toSet(), hasLength(1));
  });

  test('error bodies surface the human message', () {
    final error = ApiException(422, jsonEncode(fixture('error_split_invalid')));
    expect(apiErrorMessage(error), '₹100 still needs to be allocated');
    expect(apiErrorMessage(ApiException(502, '<html>Bad gateway</html>')), 'Something went wrong. Please try again.');
  });

  test('dates go out as the calendar day, whatever the device time zone', () {
    final s = SettlementIn(
      fromUser: 'a',
      toUser: 'b',
      amountMinor: 50000,
      date: apiDate(DateTime(2026, 9, 24)),
      method: SettlementInMethodEnum.upi,
    );
    expect(s.toJson()['date'], '2026-09-24');
    expect(s.toJson()['method'], SettlementInMethodEnum.upi);
  });

  test('split inputs are sent as decimal strings', () {
    final input = SplitInputIn(userId: 'u1', value: '33.34');
    expect(input.toJson(), {'user_id': 'u1', 'value': '33.34'});
  });
}
