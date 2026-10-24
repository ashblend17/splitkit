import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/api/api.dart';
import 'package:app/core/local/ledger.dart';

/// The Ledger's personal views with the finance revamp's entry types and accounts: what the
/// seeded parity fixtures (local_parity_test.dart) don't have. A refund of a split spend, a
/// category that nets to nothing, a deleted account, an entry from before directions, and an
/// entry of a type this build doesn't know (ISS-073).
void main() {
  const me = 'u-me', group = 'g-1', food = 'c-food', shopping = 'c-shopping', travel = 'c-travel';
  var made = 0;

  LocalEntity entity(String kind, String id, Map<String, dynamic> data) =>
      LocalEntity('user:$me', kind, id, data['version'] as int? ?? 1, {'id': id, ...data});

  LocalEntity txn(
    String id, {
    String type = 'expense',
    int amount = 1000,
    String date = '2026-09-10',
    String? direction,
    bool noDirection = false,
    String? category,
    String? account,
    String? accountId,
    int? balance,
    String? refundOf,
    String? transferGroup,
    String? expense,
  }) => entity('personal_transaction', id, {
    'user_id': me,
    'type': type,
    if (!noDirection) 'direction': direction ?? (type == 'income' || type == 'refund' ? 'in' : 'out'),
    'amount_minor': amount,
    'currency': 'INR',
    'description': id,
    'date': date,
    'category_id': category,
    'notes': null,
    'channel': null,
    'merchant': null,
    'account': account,
    'account_id': accountId,
    'transfer_group_id': transferGroup,
    'refund_of_id': refundOf,
    'holding_id': null,
    'source': balance == null ? 'manual' : 'sms',
    'reference': null,
    'balance_minor': balance,
    'sms_at': balance == null ? null : '${date}T10:00:00+05:30',
    'reviewed': true,
    'expense_id': expense,
    'settlement_id': null,
    'acting_admin_id': null,
    'created_at': DateTime.utc(2026, 9, 1).add(Duration(minutes: made++)).toIso8601String(),
    'deleted_at': null,
    'version': 1,
  });

  LocalEntity account(String id, String name, {required String created, String type = 'bank', bool deleted = false}) =>
      entity('personal_account', id, {
        'user_id': me,
        'name': name,
        'type': type,
        'currency': 'INR',
        'opening_balance_minor': 50000,
        'sms_label': null,
        'status': 'active',
        'acting_admin_id': null,
        'created_at': created,
        'updated_at': created,
        'deleted_at': deleted ? '2026-09-20T10:00:00Z' : null,
        'version': 1,
      });

  LocalEntity category(String id, String label) => entity('category', id, {
    'key': label.toLowerCase(),
    'label': label,
    'icon': 'other',
    'scope': 'personal',
    'owner_id': null,
  });

  final base = [
    entity('profile', me, {'name': 'Me', 'email': 'me@example.com', 'avatar_url': null, 'currency': 'INR'}),
    category(food, 'Food'),
    category(shopping, 'Shopping'),
    category(travel, 'Travel'),
    LocalEntity('group:$group', 'group', group, 1, {'id': group, 'name': 'Flat', 'currency': 'INR'}),
    LocalEntity('group:$group', 'member', 'm-1', 1, {
      'group_id': group,
      'user_id': me,
      'joined_at': '2026-01-01T00:00:00Z',
      'left_at': null,
      'user': {'id': me, 'name': 'Me', 'avatar_url': null},
    }),
    LocalEntity('group:$group', 'expense', 'x-1', 1, {
      'id': 'x-1',
      'group_id': group,
      'payer_id': me,
      'amount_minor': 1000,
      'currency': 'INR',
      'date': '2026-09-10',
      'splits': [
        {'user_id': me, 'share_minor': 500},
      ],
      'created_at': '2026-09-10T10:00:00Z',
      'deleted_at': null,
    }),
  ];

  final entities = [
    ...base,
    // A spend split in the group, and its refund: neither is counted.
    txn('split-spend', amount: 1000, category: food, expense: 'x-1'),
    txn('split-refund', type: 'refund', amount: 400, category: food, refundOf: 'split-spend'),
    // A spend and part of it back: 1,500 spent on shopping.
    txn('spend', amount: 2000, category: shopping, account: 'HDFC ··4821', balance: 90000),
    txn('refund', type: 'refund', amount: 500, category: shopping, refundOf: 'spend'),
    // Travel nets to nothing, so it isn't listed by category.
    txn('trip', amount: 300, category: travel),
    txn('trip-back', type: 'refund', amount: 300, category: travel),
    // Never income or spending.
    txn('leg-out', type: 'transfer', amount: 700, accountId: 'a-hdfc', transferGroup: 'tg-1'),
    txn('leg-in', type: 'transfer', amount: 700, direction: 'in', accountId: 'a-cash', transferGroup: 'tg-1'),
    txn('fix', type: 'adjustment', amount: 50, direction: 'in', accountId: 'a-cash'),
    txn('sip', type: 'investment_contribution', amount: 5000, accountId: 'a-hdfc'),
    // Synced before migration 0013: no direction.
    txn('salary', type: 'income', amount: 9000, noDirection: true, accountId: 'a-hdfc'),
    // Added by a newer build, with a type this one doesn't know.
    txn(
      'swap',
      type: 'crypto_swap',
      amount: 777,
      direction: 'out',
      account: 'HDFC ··4821',
      balance: 1,
      accountId: 'a-hdfc',
    ),
    account('a-cash', 'Cash', created: '2026-09-02T10:00:00Z', type: 'cash'),
    account('a-hdfc', 'HDFC', created: '2026-09-01T10:00:00Z'),
    account('a-old', 'Old card', created: '2026-08-01T10:00:00Z', type: 'credit_card', deleted: true),
  ];
  final ledger = Ledger(entities, today: DateTime(2026, 9, 25));

  List<Json> items(Json list) => (list['items'] as List).cast<Json>();

  test('an entry of a type this build doesn\'t know is skipped by every view', () {
    final list = ledger.personalList(limit: 500);
    expect(PersonalListOut.fromJson(list), isNotNull);
    expect(items(list).map((t) => t['id']), isNot(contains('swap')));
    expect(list['count'], 11);
    expect(items(ledger.personalList(type: 'crypto_swap')), isEmpty);
    expect(items(ledger.personalList(accountId: 'a-hdfc')).map((t) => t['id']), ['salary', 'sip', 'leg-out']);
    expect(PersonalSummaryOut.fromJson(ledger.personalSummary(DateTime(2026, 9))), isNotNull);
    final reported = AccountOut.listFromJson(ledger.personalReportedAccounts());
    expect([for (final a in reported) (a.account, a.balanceMinor, a.count)], [('HDFC ··4821', 90000, 1)]);
    expect(() => ledger.personalTransaction('swap'), throwsA(isA<LocalNotFound>()));
    expect(ledger.rawPersonal('swap'), isNull);
    // Still known as there, so the SMS it came from isn't added again.
    expect(ledger.personalIds(), contains('swap'));
  });

  test('refunds come off spending and their category; a refund of a split spend isn\'t counted', () {
    final summary = ledger.personalSummary(DateTime(2026, 9));
    expect(
      (summary['spent_minor'], summary['refunds_minor'], summary['income_minor'], summary['left_over_minor']),
      (2300 - 800, 800, 9000, 9000 - 1500),
    );
    expect([for (final c in summary['by_category'] as List) (c['label'], c['amount_minor'])], [('Shopping', 1500)]);
    final list = ledger.personalList(limit: 500);
    expect((list['spent_minor'], list['refunds_minor'], list['income_minor']), (1500, 800, 9000));
    final counted = {for (final t in items(list)) t['id']: t['counted']};
    expect((counted['split-spend'], counted['split-refund'], counted['refund']), (false, false, true));
    final transfers = ledger.personalList(type: 'transfer');
    expect((transfers['count'], transfers['spent_minor'], transfers['income_minor']), (2, 0, 0));
  });

  test('spending can go below zero', () {
    final refundOnly = Ledger([...base, txn('late', type: 'refund', amount: 250, category: food, date: '2026-10-02')]);
    final summary = refundOnly.personalSummary(DateTime(2026, 10));
    expect((summary['spent_minor'], summary['left_over_minor']), (-250, 250));
    expect([for (final c in summary['by_category'] as List) (c['label'], c['amount_minor'])], [('Food', -250)]);
  });

  test('entries carry their direction, account and links; one from before directions gets its type\'s', () {
    final salary = PersonalTxnOut.fromJson(ledger.personalTransaction('salary'))!;
    expect((salary.direction, salary.accountId), (PersonalTxnOutDirectionEnum.in_, 'a-hdfc'));
    final leg = PersonalTxnOut.fromJson(ledger.personalTransaction('leg-in'))!;
    expect(
      (leg.type, leg.direction, leg.transferGroupId),
      (PersonalTxnOutTypeEnum.transfer, PersonalTxnOutDirectionEnum.in_, 'tg-1'),
    );
    expect(PersonalTxnOut.fromJson(ledger.personalTransaction('refund'))!.refundOfId, 'spend');
  });

  test('accounts: oldest first, deleted ones apart, each by id', () {
    final live = PersonalAccountOut.listFromJson(ledger.personalAccountList());
    expect(live.map((a) => a.name), ['HDFC', 'Cash']);
    expect(PersonalAccountOut.listFromJson(ledger.personalAccountList(deleted: true)).map((a) => a.name), ['Old card']);
    expect(PersonalAccountOut.fromJson(ledger.personalAccount('a-old'))!.deletedAt, isNotNull);
    expect(() => ledger.personalAccount('nope'), throwsA(isA<LocalNotFound>()));
  });
}
