import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/finance/finance.dart';

import 'finance_helpers.dart';

void main() {
  final hdfc = account('hdfc', opening: 100000);
  final icici = account('icici', opening: 20000);
  final card = account('card', type: AccountType.creditCard, opening: 5000);

  NetWorth worth(List<FinAccount> accounts, List<FinEntry> entries, {int split = 0, bool countSplit = false}) =>
      netWorth(
        balances: accountBalances(accounts, entries),
        currency: 'INR',
        splitNetMinor: split,
        countSplit: countSplit,
      );

  test('assets less what you owe', () {
    final w = worth([hdfc, icici, card], const []);
    expect(w.assetsMinor, 120000);
    expect(w.liabilitiesMinor, 5000);
    expect(w.totalMinor, 115000);
    expect(w.hasAccounts, isTrue);
    expect(worth(const [], const []).hasAccounts, isFalse);
    expect(worth(const [], const []).totalMinor, 0);
  });

  test("a transfer between your accounts doesn't change it", () {
    final before = worth([hdfc, icici, card], const []).totalMinor;
    final (out, into) = transfer(from: 'hdfc', to: 'icici', amount: 30000);
    final w = worth([hdfc, icici, card], [out, into]);
    expect(w.totalMinor, before);
    expect(w.assetsMinor, 120000);
  });

  test("a card spend lowers it, and paying the card bill doesn't change it again", () {
    final before = worth([hdfc, card], const []).totalMinor;
    final spend = entry(type: 'expense', amount: 34000, accountId: 'card');
    final afterSpend = worth([hdfc, card], [spend]);
    expect(afterSpend.totalMinor, before - 34000);
    expect(afterSpend.liabilitiesMinor, 39000);
    final (bill, paid) = transfer(from: 'hdfc', to: 'card', amount: 39000);
    final afterBill = worth([hdfc, card], [spend, bill, paid]);
    expect(afterBill.totalMinor, afterSpend.totalMinor);
    expect(afterBill.liabilitiesMinor, 0);
    expect(afterBill.assetsMinor, 61000);
  });

  test('the Split line counts only when asked', () {
    final off = worth([hdfc], const [], split: -2500);
    expect(off.splitMinor, -2500);
    expect(off.splitCounted, isFalse);
    expect(off.totalMinor, 100000);
    final on = worth([hdfc], const [], split: -2500, countSplit: true);
    expect(on.totalMinor, 97500);
    expect(worth([hdfc], const [], split: 4000, countSplit: true).totalMinor, 104000);
  });

  test("closed accounts count, deleted ones don't", () {
    final w = worth([
      hdfc,
      account('old', opening: 700, closed: true),
      account('gone', opening: 900, deleted: true),
    ], const []);
    expect(w.totalMinor, 100700);
    expect([for (final b in w.accounts) b.account.id], ['hdfc', 'old']);
  });

  test('accounts in another currency are set aside, not added', () {
    final w = worth([hdfc, account('chase', currency: 'USD', opening: 50000)], const []);
    expect(w.totalMinor, 100000);
    expect([for (final b in w.otherCurrency) b.account.id], ['chase']);
    expect([for (final b in w.accounts) b.account.id], ['hdfc']);
  });

  test('an overdrawn account takes away', () {
    final w = worth([account('hdfc', opening: 100)], [entry(type: 'expense', amount: 400, accountId: 'hdfc')]);
    expect(w.assetsMinor, -300);
    expect(w.totalMinor, -300);
  });

  group('with account values (holdings.dart)', () {
    final zerodha = account('zerodha', type: AccountType.investment);
    final groww = account('groww', type: AccountType.investment);
    final ppf = account('ppf', type: AccountType.investment, opening: 30000);
    final abroad = account('abroad', type: AccountType.investment, currency: 'USD', opening: 900);
    final balances = accountBalances([hdfc, zerodha, groww, ppf, abroad, card], const []);
    AccountBalance of(String id) => balances.firstWhere((b) => b.account.id == id);
    AccountValue byHoldings(String id, int value, {required int asOf, int stale = 0, int added = 0}) => AccountValue(
      account: of(id).account,
      ledgerMinor: of(id).balanceMinor,
      valueMinor: value,
      byHoldings: true,
      holdingsMinor: value - added,
      addedSinceMinor: added,
      asOfDay: asOf,
      latestValuationDay: asOf,
      staleCount: stale,
    );
    final values = {
      'zerodha': byHoldings('zerodha', 85750, asOf: 20260815, stale: 1, added: 5000),
      'groww': byHoldings('groww', 12000, asOf: 20260901),
      'abroad': byHoldings('abroad', 5000, asOf: 20260101, stale: 3),
    };

    test('an account with a value counts at it; investments add up with their valuations', () {
      final w = netWorth(balances: balances, currency: 'INR', splitNetMinor: 0, countSplit: false, values: values);
      expect(w.assetsMinor, 100000 + 85750 + 12000 + 30000);
      expect(w.totalMinor, 100000 + 85750 + 12000 + 30000 - 5000);
      // The PPF has no holdings: its balance. The USD account is set aside.
      expect(w.investmentsMinor, 85750 + 12000 + 30000);
      expect((w.addedSinceMinor, w.asOfDay, w.staleCount), (5000, 20260815, 1));
      expect((w.valueOf(of('zerodha')), w.valueOf(of('ppf')), w.valueOf(of('hdfc'))), (85750, 30000, 100000));
    });

    test('without values, every account at its balance, as before', () {
      final w = netWorth(balances: balances, currency: 'INR', splitNetMinor: 0, countSplit: false);
      expect((w.assetsMinor, w.investmentsMinor), (130000, 30000));
      expect((w.addedSinceMinor, w.asOfDay, w.staleCount, w.values.length), (0, null, 0, 0));
    });
  });
}
