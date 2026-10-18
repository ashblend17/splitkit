import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/finance/finance.dart';

import 'finance_helpers.dart';

void main() {
  final sep = monthRange(2026, 9);
  final accounts = {
    for (final a in [
      account('hdfc'),
      account('icici'),
      account('card', type: AccountType.creditCard),
      account('zerodha', type: AccountType.investment),
      account('loan', type: AccountType.loan),
    ])
      a.id: a,
  };

  CashFlow flow(
    List<FinEntry> entries, {
    DayRange? period,
    Set<String> notCounted = const {},
    int share = 0,
    bool countShare = false,
  }) => cashFlow(
    entries: entries,
    period: period ?? sep,
    currency: 'INR',
    notCounted: notCounted,
    accounts: accounts,
    groupShareMinor: share,
    countGroupShare: countShare,
    label: labelOf,
  );

  test('monthRange and addDays', () {
    expect(sep, (start: 20260901, end: 20260930));
    expect(monthRange(2024, 2), (start: 20240201, end: 20240229));
    expect(monthRange(2026, 13), (start: 20270101, end: 20270131));
    expect(sep.contains(20260930), isTrue);
    expect(sep.contains(20261001), isFalse);
    expect(addDays(20260301, -1), 20260228);
    expect(addDays(20261231, 1), 20270101);
    expect(addDays(20260915, -60), 20260717);
  });

  test('income, spending net of refunds, what is left and the savings rate', () {
    final f = flow([
      entry(type: 'income', amount: 100000),
      entry(type: 'expense', amount: 30000, categoryId: 'food'),
      entry(type: 'expense', amount: 10000, categoryId: 'shopping'),
      entry(type: 'refund', amount: 4000, categoryId: 'shopping'),
    ]);
    expect(f.incomeMinor, 100000);
    expect(f.expensesMinor, 40000);
    expect(f.refundsMinor, 4000);
    expect(f.spendingMinor, 36000);
    expect(f.consumptionMinor, 36000);
    expect(f.netMinor, 64000);
    expect(f.savingsRate, 0.64);
    expect(f.savingsRatePercent, 64);
    expect(f.entryCount, 4);
    expect(f.isEmpty, isFalse);
  });

  test("a refund lowers spending in its category (the original's), and a fully refunded one drops out", () {
    final f = flow([
      entry(type: 'expense', amount: 5000, categoryId: 'food'),
      entry(type: 'expense', amount: 5000, categoryId: 'travel'),
      entry(type: 'expense', amount: 149000, categoryId: 'shopping'),
      entry(type: 'refund', amount: 149000, categoryId: 'shopping'),
      entry(type: 'refund', amount: 1000, categoryId: 'food'),
      entry(type: 'expense', amount: 700),
    ]);
    expect(
      [for (final c in f.byCategory) (c.categoryId, c.label, c.amountMinor)],
      [('travel', 'travel', 5000), ('food', 'food', 4000), (null, 'Uncategorised', 700)],
    );
  });

  test('transfers between your accounts are neither income nor spending, and corrections count nowhere', () {
    final (out, into) = transfer(from: 'hdfc', to: 'icici', amount: 50000);
    final (bill, paid) = transfer(from: 'hdfc', to: 'card', amount: 4999, group: 'g2');
    // A loan received is a transfer from the loan account.
    final (lent, received) = transfer(from: 'loan', to: 'hdfc', amount: 900000, group: 'g3');
    final f = flow([
      out,
      into,
      bill,
      paid,
      lent,
      received,
      entry(type: 'adjustment', direction: 'in', amount: 12345, accountId: 'hdfc'),
    ]);
    expect(f.incomeMinor, 0);
    expect(f.expensesMinor, 0);
    expect(f.investedMinor, 0);
    expect(f.withdrawnMinor, 0);
    expect(f.entryCount, 0);
    expect(f.isEmpty, isTrue);
  });

  test('investing is not spending: contributions, and transfers into an investment account', () {
    final (sip, bought) = transfer(from: 'hdfc', to: 'zerodha', amount: 500000);
    final (sold, cashed) = transfer(from: 'zerodha', to: 'icici', amount: 200000, group: 'g2');
    final f = flow([
      entry(type: 'investment_contribution', amount: 100000, accountId: 'hdfc'),
      entry(type: 'investment_withdrawal', amount: 30000, accountId: 'hdfc'),
      sip,
      bought,
      sold,
      cashed,
    ]);
    expect(f.investedMinor, 600000);
    expect(f.withdrawnMinor, 230000);
    expect(f.expensesMinor, 0);
    expect(f.incomeMinor, 0);
    expect(f.netMinor, 0);
    expect(f.entryCount, 4);
  });

  test("a transfer leg counts as invested in its own month, and an unpaired leg doesn't count", () {
    final (sip, bought) = transfer(from: 'hdfc', to: 'zerodha', amount: 500000, day: 20260831, toDay: 20260901);
    expect(flow([sip, bought]).investedMinor, 0);
    expect(flow([sip, bought], period: monthRange(2026, 8)).investedMinor, 500000);
    expect(flow([sip]).investedMinor, 0);
    expect(flow([sip], period: monthRange(2026, 8)).investedMinor, 0);
  });

  test('zero income: no savings rate', () {
    final f = flow([entry(type: 'expense', amount: 100)]);
    expect(f.savingsRate, isNull);
    expect(f.savingsRatePercent, isNull);
  });

  test('the savings rate rounds half away from zero', () {
    int? pct(int income, int spent) =>
        flow([entry(type: 'income', amount: income), entry(type: 'expense', amount: spent)]).savingsRatePercent;
    expect(pct(200, 199), 1); // 0.5%
    expect(pct(200, 201), -1); // -0.5%
    expect(pct(1000, 997), 0); // 0.3%
    expect(pct(1000, 1000), 0);
    expect(pct(3, 1), 67); // 66.67%
    expect(pct(3, 2), 33);
    expect(pct(100, 300), -200);
  });

  test('the month boundary follows the date: the 31st and the 1st', () {
    final entries = [
      entry(type: 'expense', amount: 100, day: 20260831, time: '23:59'),
      entry(type: 'expense', amount: 200, day: 20260901, time: '00:01'),
      entry(type: 'expense', amount: 400, day: 20260930),
      entry(type: 'expense', amount: 800, day: 20261001),
    ];
    expect(flow(entries).expensesMinor, 600);
    expect(flow(entries, period: monthRange(2026, 8)).expensesMinor, 100);
    expect(flow(entries, period: monthRange(2026, 10)).expensesMinor, 800);
  });

  test('your group share is spending only when the flag says so', () {
    final entries = [entry(type: 'income', amount: 10000), entry(type: 'expense', amount: 2000)];
    final off = flow(entries, share: 3000);
    expect(off.groupShareMinor, 3000);
    expect(off.groupShareCounted, isFalse);
    expect(off.consumptionMinor, 2000);
    expect(off.netMinor, 8000);
    final on = flow(entries, share: 3000, countShare: true);
    expect(on.consumptionMinor, 5000);
    expect(on.netMinor, 5000);
    expect(on.spendingMinor, 2000, reason: "the server summary's spent_minor never has the share");
    // A month with only a share isn't empty when the share is counted.
    expect(flow(const [], share: 3000).isEmpty, isTrue);
    expect(flow(const [], share: 3000, countShare: true).isEmpty, isFalse);
  });

  test('left out: entries counted in Split, refunds of them, deleted ones, other currencies, unknown types', () {
    final f = flow(
      [
        entry(id: 'split', type: 'expense', amount: 1, expenseId: 'x'),
        entry(id: 'paid-back', type: 'income', amount: 2, settlementId: 's'),
        entry(id: 'refund-of-split', type: 'refund', amount: 4, refundOfId: 'split'),
        entry(type: 'expense', amount: 8, deletedAt: '2026-09-20T00:00:00Z'),
        entry(type: 'income', amount: 16, currency: 'USD'),
        entry(type: 'gift', amount: 32, direction: 'in'),
        entry(type: 'expense', amount: 64),
      ],
      notCounted: {'split', 'paid-back', 'refund-of-split'},
    );
    expect(f.incomeMinor, 0);
    expect(f.expensesMinor, 64);
    expect(f.refundsMinor, 0);
    expect(f.entryCount, 1);
  });

  test('spending can be negative: more refunded than spent this month', () {
    final f = flow([
      entry(type: 'expense', amount: 1000, day: 20260920, categoryId: 'shopping'),
      entry(type: 'refund', amount: 3000, day: 20260921, categoryId: 'shopping'),
    ]);
    expect(f.spendingMinor, -2000);
    expect(f.netMinor, 2000);
    expect(f.byCategory.single.amountMinor, -2000);
  });

  test('consumptionMinor: what each entry adds to spending', () {
    final spend = entry(id: 's', type: 'expense', amount: 500);
    final back = entry(type: 'refund', amount: 200);
    expect(consumptionMinor(spend, const {}, 'INR'), 500);
    expect(consumptionMinor(back, const {}, 'INR'), -200);
    expect(consumptionMinor(spend, const {'s'}, 'INR'), isNull);
    expect(consumptionMinor(spend, const {}, 'USD'), isNull);
    expect(consumptionMinor(entry(type: 'income', amount: 1), const {}, 'INR'), isNull);
    expect(consumptionMinor(entry(type: 'expense', deletedAt: '2026-09-20T00:00:00Z'), const {}, 'INR'), isNull);
  });

  test('monthlyCashFlow gives each month what cashFlow gives it', () {
    final (sip, bought) = transfer(from: 'hdfc', to: 'zerodha', amount: 500000, day: 20260815);
    final entries = [
      entry(type: 'income', amount: 9000, day: 20260801),
      entry(type: 'expense', amount: 300, day: 20260810, categoryId: 'food'),
      entry(type: 'expense', amount: 700, day: 20260905, categoryId: 'food'),
      entry(type: 'refund', amount: 100, day: 20260906, categoryId: 'food'),
      entry(type: 'expense', amount: 50, day: 20261005),
      sip,
      bought,
    ];
    final months = monthlyCashFlow(
      entries: entries,
      yyyymm: [202608, 202609, 202607],
      currency: 'INR',
      notCounted: const {},
      accounts: accounts,
      groupShareFor: (p) => p.start ~/ 100 == 202609 ? 1234 : 0,
      countGroupShare: true,
      label: labelOf,
    );
    expect(months.keys, [202608, 202609, 202607]);
    for (final MapEntry(key: m, value: got) in months.entries) {
      final period = monthRange(m ~/ 100, m % 100);
      final want = cashFlow(
        entries: entries,
        period: period,
        currency: 'INR',
        notCounted: const {},
        accounts: accounts,
        groupShareMinor: m == 202609 ? 1234 : 0,
        countGroupShare: true,
        label: labelOf,
      );
      expect(got.period, period);
      expect(
        (got.incomeMinor, got.expensesMinor, got.refundsMinor, got.investedMinor, got.groupShareMinor, got.netMinor),
        (
          want.incomeMinor,
          want.expensesMinor,
          want.refundsMinor,
          want.investedMinor,
          want.groupShareMinor,
          want.netMinor,
        ),
      );
      expect([for (final c in got.byCategory) c.amountMinor], [for (final c in want.byCategory) c.amountMinor]);
    }
    expect(months[202608]!.investedMinor, 500000);
    expect(months[202609]!.consumptionMinor, 600 + 1234);
    expect(months[202607]!.isEmpty, isTrue);
  });
}
