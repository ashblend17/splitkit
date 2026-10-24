import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/finance/finance.dart';

import 'finance_helpers.dart';

void main() {
  final accounts = {
    for (final id in ['hdfc', 'icici', 'sbi']) id: account(id),
  };

  /// A spend read from an SMS at [time] on 15 Sep.
  FinEntry spend(String id, String time, {String accountId = 'hdfc', int amount = 500000}) =>
      entry(id: id, type: 'expense', amount: amount, time: time, accountId: accountId, sms: true);

  /// An income read from an SMS at [time] on 15 Sep.
  FinEntry income(String id, String time, {String accountId = 'icici', int amount = 500000}) =>
      entry(id: id, type: 'income', amount: amount, time: time, accountId: accountId, sms: true);

  List<String> suggested(
    List<FinEntry> entries, {
    Set<String> notCounted = const {},
    Set<String> dismissed = const {},
    Duration window = const Duration(minutes: 30),
  }) => [
    for (final s in transferSuggestions(
      entries,
      accounts: accounts,
      notCounted: notCounted,
      dismissed: dismissed,
      window: window,
    ))
      s.key,
  ];

  test('a spend and an income of the same amount on two accounts, close in time', () {
    final found = transferSuggestions(
      [spend('out', '10:00'), income('in', '10:12')],
      accounts: accounts,
      notCounted: const {},
      dismissed: const {},
    );
    expect(found.single.outflow.id, 'out');
    expect(found.single.inflow.id, 'in');
    expect(found.single.minutesApart, 12);
    expect(found.single.key, 'out|in');
  });

  test('the window: 30 minutes apart is in, 31 is out, either way round', () {
    expect(suggested([spend('out', '10:00'), income('in', '10:30')]), ['out|in']);
    expect(suggested([spend('out', '10:31'), income('in', '10:01')]), ['out|in']);
    expect(suggested([spend('out', '10:00'), income('in', '10:31')]), isEmpty);
    expect(suggested([spend('out', '10:00'), income('in', '10:31')], window: const Duration(hours: 1)), ['out|in']);
  });

  test('closest first: each entry joins one pair', () {
    final entries = [
      spend('a', '10:00'),
      spend('b', '10:20'),
      income('x', '10:18'),
      income('y', '10:25', accountId: 'sbi'),
    ];
    // b–x (2 min) first; then a can take only y (25 min). Newest pair first.
    expect(suggested(entries), ['a|y', 'b|x']);
    final found = transferSuggestions(entries, accounts: accounts, notCounted: const {}, dismissed: const {});
    expect({for (final s in found) s.key: s.minutesApart}, {'a|y': 25, 'b|x': 2});
  });

  test('ties go by id', () {
    final entries = [spend('b', '10:00'), spend('a', '10:00'), income('x', '10:05')];
    expect(suggested(entries), ['a|x']);
  });

  test('left out: dismissed pairs, the same account, other amounts, entries not from SMS', () {
    expect(suggested([spend('out', '10:00'), income('in', '10:05')], dismissed: {'out|in'}), isEmpty);
    expect(suggested([spend('out', '10:00'), income('in', '10:05', accountId: 'hdfc')]), isEmpty);
    expect(suggested([spend('out', '10:00'), income('in', '10:05', amount: 499999)]), isEmpty);
    final manual = entry(id: 'in', type: 'income', amount: 500000, accountId: 'icici');
    expect(suggested([spend('out', '10:00'), manual]), isEmpty);
  });

  test('a dismissed pair frees both entries for another pair', () {
    final entries = [spend('a', '10:00'), income('x', '10:01'), income('y', '10:09', accountId: 'sbi')];
    expect(suggested(entries, dismissed: {'a|x'}), ['a|y']);
  });

  test('left out: entries linked to Split or not counted, already transfers, deleted, no or unknown account', () {
    final entries = [spend('out', '10:00'), income('in', '10:05')];
    expect(suggested(entries, notCounted: {'in'}), isEmpty);
    expect(
      suggested([
        entry(id: 'out', type: 'expense', amount: 500000, time: '10:00', accountId: 'hdfc', sms: true, expenseId: 'x'),
        income('in', '10:05'),
      ]),
      isEmpty,
    );
    final (leg, other) = transfer(from: 'sbi', to: 'icici', amount: 500000);
    expect(suggested([spend('out', '10:00'), leg, other]), isEmpty);
    expect(
      suggested([
        spend('out', '10:00'),
        entry(id: 'in', type: 'income', amount: 500000, time: '10:05', accountId: 'icici', sms: true, deletedAt: 'x'),
      ]),
      isEmpty,
    );
    expect(suggested([spend('out', '10:00'), income('in', '10:05', accountId: 'nowhere')]), isEmpty);
    expect(
      suggested([spend('out', '10:00'), entry(id: 'in', type: 'income', amount: 500000, time: '10:05', sms: true)]),
      isEmpty,
    );
  });

  test('transferPartners: each live leg to the other', () {
    final (out, into) = transfer(from: 'hdfc', to: 'icici', outId: 'o', inId: 'i');
    final lone = entry(id: 'lone', type: 'transfer', direction: 'out', accountId: 'hdfc', transferGroupId: 'g2');
    final gone = entry(
      id: 'gone',
      type: 'transfer',
      direction: 'in',
      accountId: 'sbi',
      transferGroupId: 'g2',
      deletedAt: 'x',
    );
    final partners = transferPartners([out, into, lone, gone]);
    expect(partners.keys.toSet(), {'o', 'i'});
    expect(partners['o']!.id, 'i');
    expect(partners['i']!.id, 'o');
  });

  group('deterministic ids', () {
    const leg = '11111111-1111-4111-8111-111111111111', other = '22222222-2222-4222-8222-222222222222';

    test('the paired leg and the group are the same every time, on every phone', () {
      // uuid5(ledger_rules.ACCOUNT_NAMESPACE, "<leg>|pair") and "<leg>|group", "<a>|<b>|group".
      expect(pairedLegId(leg), '861b60ce-841e-58a0-b589-13d8551ff8b5');
      expect(transferGroupIdFor(leg), '4a193154-d2fb-549d-badd-b6d75c21f9d6');
      expect(transferGroupIdFor(leg, other), '035f5337-bfc9-58c8-a721-e5f9166cea56');
    });

    test("a pair's group doesn't depend on the order of its legs", () {
      expect(transferGroupIdFor(other, leg), transferGroupIdFor(leg, other));
      expect(transferGroupIdFor(leg), isNot(transferGroupIdFor(leg, other)));
      expect(pairedLegId(leg), isNot(pairedLegId(other)));
    });
  });
}
