import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/finance/finance.dart';
import 'package:splitkit/core/local/ledger.dart';

/// Every screen answer the device computes must equal the API's for the same data.
///
/// `test/fixtures/sync/<user>.json` holds every snapshot a seeded user can see plus the API's own
/// answers, captured together by tool/capture_api_fixtures.py. Both sides go through the
/// generated models, so "+00:00" vs "Z" and field order don't count as differences.
void main() {
  for (final user in ['john', 'rahul']) {
    final fixture = jsonDecode(File('test/fixtures/sync/$user.json').readAsStringSync()) as Map<String, dynamic>;
    final snapshots = (fixture['snapshots'] as Map).cast<String, dynamic>();
    final answers = (fixture['answers'] as Map).cast<String, dynamic>();
    final ledger = Ledger([
      for (final s in snapshots.entries)
        for (final e in (s.value['entities'] as List).cast<Map<String, dynamic>>())
          LocalEntity(s.key, e['entity'], e['entity_id'], e['version'], (e['data'] as Map).cast()),
    ], today: DateTime(2026, 9, 25));

    group('$user:', () {
      for (final entry in answers.entries) {
        final (name, arg) = _split(entry.key);
        test(entry.key, () {
          final (mine, parse) = switch (name) {
            'me' => (ledger.userOut(), UserOut.fromJson),
            'groups' => (ledger.groups(), GroupOut.listFromJson),
            'groups_archived' => (ledger.groups(archived: true), GroupOut.listFromJson),
            'group' => (ledger.group(arg!), GroupOut.fromJson),
            'balances' => (ledger.overallBalances(), OverallBalancesOut.fromJson),
            'group_balances' => (ledger.groupBalances(arg!), GroupBalancesOut.fromJson),
            'feed' => (ledger.feed(groupId: arg, limit: 100), FeedItem.listFromJson),
            'feed_deleted' => (ledger.feed(deleted: true, limit: 100), FeedItem.listFromJson),
            'expense' => (ledger.expense(arg!), ExpenseOut.fromJson),
            'categories' => (ledger.categories(), CategoryOut.listFromJson),
            'categories_group' => (ledger.categories(scope: 'group'), CategoryOut.listFromJson),
            'categories_personal' => (ledger.categories(scope: 'personal'), CategoryOut.listFromJson),
            'settle_up' => (
              ledger.settleUpPlan(arg!.split(':')[0], currency: arg.split(':')[1]),
              SettleUpPlanOut.fromJson,
            ),
            'personal_summary' => (ledger.personalSummary(DateTime.parse(arg!)), PersonalSummaryOut.fromJson),
            'personal_list' => (
              switch (arg) {
                null => ledger.personalList(limit: 500),
                'sep_expense' => ledger.personalList(start: '2026-09-01', end: '2026-09-30', type: 'expense', limit: 500),
                'just_in' => ledger.personalList(source: 'sms', reviewed: false, limit: 500),
                'upi' => ledger.personalList(channel: 'upi', limit: 500),
                'hdfc' => ledger.personalList(account: 'HDFC ··4821', limit: 500),
                'hdfc_account' => ledger.personalList(accountId: _accountId(ledger, 'HDFC ··4821'), limit: 500),
                'transfers' => ledger.personalList(type: 'transfer', limit: 500),
                _ => throw StateError('No local view for ${entry.key}'),
              },
              PersonalListOut.fromJson,
            ),
            'personal_accounts' => (ledger.personalAccountList(), PersonalAccountOut.listFromJson),
            'personal_accounts_reported' => (ledger.personalReportedAccounts(), AccountOut.listFromJson),
            'personal_account' => (ledger.personalAccount(arg!), PersonalAccountOut.fromJson),
            'personal_deleted' => (ledger.personalList(deleted: true, limit: 500), PersonalListOut.fromJson),
            'personal_goals' => (ledger.personalGoalList(), PersonalGoalOut.listFromJson),
            'personal_goals_deleted' => (ledger.personalGoalList(deleted: true), PersonalGoalOut.listFromJson),
            'personal_goal' => (ledger.personalGoal(arg!), PersonalGoalOut.fromJson),
            'goal_contributions' => (ledger.goalContributionList(goalId: arg), PersonalGoalContributionOut.listFromJson),
            'goal_contributions_deleted' => (
              ledger.goalContributionList(deleted: true),
              PersonalGoalContributionOut.listFromJson,
            ),
            'allocation_rules' => (ledger.allocationRuleList(), PersonalAllocationRuleOut.listFromJson),
            'allocation_rules_deleted' => (
              ledger.allocationRuleList(deleted: true),
              PersonalAllocationRuleOut.listFromJson,
            ),
            'allocation_rule' => (ledger.allocationRule(arg!), PersonalAllocationRuleOut.fromJson),
            'allocation_plans' => (
              switch (arg?.split(':')) {
                null => ledger.allocationPlanList(),
                ['income', final id] => ledger.allocationPlanList(sourceTransactionId: id),
                ['rule', final id] => ledger.allocationPlanList(ruleId: id),
                ['goal', final id] => ledger.allocationPlanList(goalId: id),
                ['account', final id] => ledger.allocationPlanList(accountId: id),
                _ => throw StateError('No local view for ${entry.key}'),
              },
              PersonalAllocationPlanOut.listFromJson,
            ),
            'allocation_plans_deleted' => (
              ledger.allocationPlanList(deleted: true),
              PersonalAllocationPlanOut.listFromJson,
            ),
            _ => throw StateError('No local view for ${entry.key}'),
          };
          final expected = _normal(parse(entry.value));
          expect(expected, isNotNull, reason: 'the fixture must parse');
          expect(_normal(parse(mine)), expected);
        });
      }

      // The finance engine on its own, without personalSummary's JSON: its cash flow (group share
      // not counted) is the API's summary.
      for (final month in ['2026-07-01', '2026-08-01', '2026-09-01']) {
        test('finance.cashFlow($month) is personal_summary:$month', () {
          final summary = answers['personal_summary:$month'] as Map<String, dynamic>?;
          expect(summary, isNotNull, reason: 'the fixture has the month');
          final first = DateTime.parse(month);
          final period = monthRange(first.year, first.month);
          final flow = ledger.finance.cashFlow(
            period,
            notCounted: ledger.notCounted,
            groupShareMinor: ledger.groupShareFor(period),
            countGroupShare: false,
            label: ledger.categoryLabel,
          );
          expect(
            (flow.spendingMinor, flow.incomeMinor, flow.refundsMinor, flow.groupShareMinor),
            (summary!['spent_minor'], summary['income_minor'], summary['refunds_minor'], summary['group_share_minor']),
          );
          expect(flow.netMinor, summary['left_over_minor']);
          expect(
            [for (final c in flow.byCategory) (c.label, c.amountMinor)],
            [for (final c in (summary['by_category'] as List).cast<Map>()) (c['label'], c['amount_minor'])],
          );
        });
      }
    });
  }
}

/// The id of the account with SMS label [label].
String _accountId(Ledger ledger, String label) =>
    ledger.personalAccountList().firstWhere((a) => a['sms_label'] == label)['id'] as String;

(String, String?) _split(String key) {
  final i = key.indexOf(':');
  return i < 0 ? (key, null) : (key.substring(0, i), key.substring(i + 1));
}

Object? _normal(Object? model) => jsonDecode(jsonEncode(model));
