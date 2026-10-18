import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/categorise/category_rules.dart';
import 'package:splitkit/core/finance/finance.dart';

import 'finance_helpers.dart';

/// The facade: what it answers is what the pure functions answer over the same data, and it
/// remembers its answers.
void main() {
  final sep = monthRange(2026, 9);
  final hdfc = account('hdfc', opening: 100000, label: 'HDFC ··4821', created: 3);
  final card = account('card', type: AccountType.creditCard, label: 'ICICI Credit card ··9012', created: 2);
  final cash = account('cash', type: AccountType.cash, opening: 500, created: 5);
  final shut = account('shut', type: AccountType.cash, closed: true, created: 1);
  final gone = account('gone', label: 'SBI ··0042', deleted: true, created: 0);
  final zerodha = account('zerodha', type: AccountType.investment, created: 4);
  final accounts = [hdfc, card, cash, shut, gone, zerodha];

  late List<FinEntry> entries;
  late FinanceEngine engine;

  setUp(() {
    final (atm, inCash) = transfer(from: 'hdfc', to: 'cash', amount: 200000, day: 20260912, outId: 'atm', inId: 'jar');
    final (sip, bought) = transfer(
      from: 'hdfc',
      to: 'zerodha',
      amount: 500000,
      day: 20260831,
      toDay: 20260901,
      group: 'g2',
    );
    final (oldOut, oldIn) = transfer(
      from: 'hdfc',
      to: 'cash',
      amount: 7,
      group: 'g3',
      outId: 'old-out',
      inId: 'old-in',
    );
    entries = [
      entry(
        id: 'salary',
        type: 'income',
        amount: 8500000,
        day: 20260901,
        accountId: 'hdfc',
        sms: true,
        time: '09:00',
        balance: 11248000,
      ),
      entry(
        id: 'swiggy',
        type: 'expense',
        amount: 45000,
        day: 20260910,
        accountId: 'hdfc',
        merchant: 'SWIGGY',
        categoryId: 'food',
      ),
      entry(
        id: 'split',
        type: 'expense',
        amount: 90000,
        day: 20260911,
        accountId: 'card',
        expenseId: 'x',
        categoryId: 'food',
      ),
      entry(type: 'refund', amount: 5000, day: 20260914, accountId: 'hdfc', refundOfId: 'swiggy', categoryId: 'food'),
      entry(type: 'gift', amount: 123, day: 20260915, accountId: 'hdfc', direction: 'in', transferGroupId: 'g9'),
      entry(type: 'expense', amount: 999, day: 20260916, accountId: 'hdfc', deletedAt: '2026-09-17T00:00:00Z'),
      entry(
        id: 'neft-out',
        type: 'expense',
        amount: 300000,
        day: 20260920,
        time: '11:00',
        accountId: 'hdfc',
        sms: true,
      ),
      entry(id: 'neft-in', type: 'income', amount: 300000, day: 20260920, time: '11:04', accountId: 'card', sms: true),
      atm,
      inCash,
      sip,
      bought,
      FinEntry({...oldOut.raw, 'deleted_at': '2026-09-18T10:00:00Z'}),
      FinEntry({...oldIn.raw, 'deleted_at': '2026-09-18T10:00:00Z'}),
    ];
    engine = FinanceEngine(accounts: accounts, entries: entries, currency: 'INR');
  });

  group('accounts', () {
    test('those not deleted, oldest first; by id or label whatever their state', () {
      expect([for (final a in engine.accounts) a.id], ['shut', 'card', 'hdfc', 'zerodha', 'cash']);
      expect(engine.account('gone'), gone);
      expect(engine.account('nope'), isNull);
      expect(engine.accountForLabel('HDFC ··4821'), hdfc);
      expect(engine.accountForLabel('SBI ··0042'), gone);
      expect(engine.accountForLabel('Axis ··1'), isNull);
      expect(engine.firstActiveCash(), cash, reason: 'the closed cash account is older');
      expect(FinanceEngine(accounts: [hdfc], entries: const [], currency: 'INR').firstActiveCash(), isNull);
    });

    test('balances are the pure function over the same data', () {
      final want = accountBalances(engine.accounts, entries);
      expect(
        [for (final b in engine.balances) (b.account.id, b.balanceMinor, b.entryCount)],
        [for (final b in want) (b.account.id, b.balanceMinor, b.entryCount)],
      );
      expect([for (final b in engine.balances) b.account], engine.accounts);
      expect(engine.balanceOf('hdfc')!.balanceMinor, 100000 + 8500000 - 45000 + 5000 - 300000 - 200000 - 500000);
      expect(engine.balanceOf('cash')!.balanceMinor, 500 + 200000);
      expect(engine.balanceOf('card')!.balanceMinor, 90000 - 300000);
      expect(engine.balanceOf('gone'), isNull);
      expect(identical(engine.balances, engine.balances), isTrue);
    });
  });

  group('cash flow', () {
    test('is the pure function over every entry (a transfer leg finds its partner in another month)', () {
      for (final period in [sep, monthRange(2026, 8), monthRange(2026, 10)]) {
        final got = engine.cashFlow(
          period,
          notCounted: const {'split'},
          groupShareMinor: 77,
          countGroupShare: true,
          label: labelOf,
        );
        final want = cashFlow(
          entries: entries,
          period: period,
          currency: 'INR',
          notCounted: const {'split'},
          accounts: {for (final a in accounts) a.id: a},
          groupShareMinor: 77,
          countGroupShare: true,
          label: labelOf,
        );
        expect(
          (
            got.incomeMinor,
            got.expensesMinor,
            got.refundsMinor,
            got.investedMinor,
            got.consumptionMinor,
            got.entryCount,
          ),
          (
            want.incomeMinor,
            want.expensesMinor,
            want.refundsMinor,
            want.investedMinor,
            want.consumptionMinor,
            want.entryCount,
          ),
        );
        expect(
          [for (final c in got.byCategory) (c.label, c.amountMinor)],
          [for (final c in want.byCategory) (c.label, c.amountMinor)],
        );
      }
      final aug = engine.cashFlow(
        monthRange(2026, 8),
        notCounted: const {},
        groupShareMinor: 0,
        countGroupShare: false,
        label: labelOf,
      );
      expect(aug.investedMinor, 500000);
      final s = engine.cashFlow(
        sep,
        notCounted: const {'split'},
        groupShareMinor: 0,
        countGroupShare: false,
        label: labelOf,
      );
      expect(s.incomeMinor, 8500000 + 300000);
      expect(s.spendingMinor, 45000 + 300000 - 5000);
    });

    test('is remembered for the same arguments: the set by identity, the label function by equality', () {
      final notCounted = {'split'};
      CashFlow ask(Set<String> n, {String Function(String?) label = labelOf, int share = 0}) =>
          engine.cashFlow(sep, notCounted: n, groupShareMinor: share, countGroupShare: false, label: label);
      final first = ask(notCounted);
      expect(identical(ask(notCounted), first), isTrue);
      expect(identical(ask({'split'}), first), isFalse, reason: 'another set, even an equal one');
      expect(identical(ask(notCounted, share: 1), first), isFalse);
      final names = _Names();
      final named = ask(notCounted, label: names.label);
      expect(identical(ask(notCounted, label: names.label), named), isTrue, reason: 'a tear-off of the same object');
      expect(identical(ask(notCounted, label: _Names().label), named), isFalse);
      // Many periods later, the first is worked out again (only the last few are kept).
      for (var m = 1; m <= 30; m++) {
        engine.cashFlow(
          monthRange(2024, m),
          notCounted: notCounted,
          groupShareMinor: 0,
          countGroupShare: false,
          label: labelOf,
        );
      }
      expect(identical(ask(notCounted), first), isFalse);
    });
  });

  test('net worth from the balances', () {
    final w = engine.netWorth(splitNetMinor: -1000, countSplit: true, today: 20260925);
    final assets = engine.balances.where((b) => !b.account.type.isLiability).fold(0, (s, b) => s + b.balanceMinor);
    expect(w.assetsMinor, assets);
    expect(w.liabilitiesMinor, -210000);
    expect(w.totalMinor, assets + 210000 - 1000);
    expect(w.accounts.length, 5);
  });

  test('transfer suggestions, remembered for the same sets', () {
    final notCounted = <String>{}, dismissed = <String>{};
    final found = engine.transferSuggestions(notCounted: notCounted, dismissed: dismissed);
    expect([for (final s in found) s.key], ['neft-out|neft-in']);
    expect(identical(engine.transferSuggestions(notCounted: notCounted, dismissed: dismissed), found), isTrue);
    expect(engine.transferSuggestions(notCounted: notCounted, dismissed: {'neft-out|neft-in'}), isEmpty);
  });

  test('refunds: the target and what is left to refund', () {
    final swiggy = entries.firstWhere((e) => e.id == 'swiggy');
    expect(engine.refundableMinor(swiggy), 40000);
    expect(engine.refundTarget(amountMinor: 40000, day: 20260925, merchantKey: merchantKey('Swiggy'))?.id, 'swiggy');
    expect(engine.refundTarget(amountMinor: 40001, day: 20260925, merchantKey: merchantKey('Swiggy')), isNull);
  });

  test("partnerLeg: a live leg's live partner, a deleted leg's partner deleted with it", () {
    expect(engine.partnerLeg('atm')!.id, 'jar');
    expect(engine.partnerLeg('jar')!.id, 'atm');
    expect(engine.partnerLeg('old-out')!.id, 'old-in');
    expect(engine.partnerLeg('swiggy'), isNull);
    expect(engine.partnerLeg('nope'), isNull);
  });

  test('entries of a type this build does not know count nowhere (ISS-073)', () {
    final known = FinanceEngine(
      accounts: accounts,
      entries: [
        for (final e in entries)
          if (e.txnType != null) e,
      ],
      currency: 'INR',
    );
    expect([for (final b in engine.balances) b.balanceMinor], [for (final b in known.balances) b.balanceMinor]);
    expect([for (final b in engine.balances) b.entryCount], [for (final b in known.balances) b.entryCount]);
    CashFlow sepOf(FinanceEngine f) =>
        f.cashFlow(sep, notCounted: const {}, groupShareMinor: 0, countGroupShare: false, label: labelOf);
    expect(sepOf(engine).entryCount, sepOf(known).entryCount);
    expect(sepOf(engine).incomeMinor, sepOf(known).incomeMinor);
  });
}

class _Names {
  String label(String? id) => id ?? 'Uncategorised';
}
