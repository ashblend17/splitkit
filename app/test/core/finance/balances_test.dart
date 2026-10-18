import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/finance/finance.dart';

import 'finance_helpers.dart';

void main() {
  AccountBalance only(FinAccount a, List<FinEntry> entries) => accountBalances([a], entries).single;

  group('signs', () {
    test('an asset rises with money in and falls with money out', () {
      final hdfc = account('hdfc', opening: 10000);
      final b = only(hdfc, [
        entry(type: 'income', amount: 5000, accountId: 'hdfc'),
        entry(type: 'expense', amount: 2000, accountId: 'hdfc'),
        entry(type: 'refund', amount: 300, accountId: 'hdfc'),
        entry(type: 'investment_contribution', amount: 1000, accountId: 'hdfc'),
        entry(type: 'investment_withdrawal', amount: 400, accountId: 'hdfc'),
      ]);
      expect(b.balanceMinor, 10000 + 5000 - 2000 + 300 - 1000 + 400);
      expect(b.netWorthMinor, b.balanceMinor);
      expect(b.entryCount, 5);
    });

    test("a liability's balance is what you owe: spending raises it, paying it off lowers it", () {
      final card = account('card', type: AccountType.creditCard, opening: 499900);
      final (bill, paid) = transfer(from: 'hdfc', to: 'card', amount: 499900);
      final b = only(card, [entry(type: 'expense', amount: 34000, accountId: 'card'), bill, paid]);
      expect(b.balanceMinor, 34000);
      expect(b.netWorthMinor, -34000);
      final loan = account('loan', type: AccountType.loan);
      expect(only(loan, [entry(type: 'transfer', direction: 'out', amount: 100, accountId: 'loan')]).balanceMinor, 100);
    });

    test('entryEffect', () {
      final spend = entry(type: 'expense', amount: 700), pay = entry(type: 'income', amount: 700);
      expect(entryEffect(spend, AccountType.bank), -700);
      expect(entryEffect(pay, AccountType.cash), 700);
      expect(entryEffect(spend, AccountType.creditCard), 700);
      expect(entryEffect(pay, AccountType.loan), -700);
    });
  });

  group('which entries move a balance', () {
    test('uncounted entries do (the money moved); deleted ones, unknown types and other accounts do not', () {
      final hdfc = account('hdfc');
      final b = only(hdfc, [
        entry(type: 'expense', amount: 100, accountId: 'hdfc', expenseId: 'split'), // counted in Split
        entry(type: 'expense', amount: 200, accountId: 'hdfc', deletedAt: '2026-09-16T10:00:00Z'),
        entry(type: 'gift', amount: 400, accountId: 'hdfc', direction: 'out'), // a type from a later build
        entry(type: 'expense', amount: 800, accountId: 'icici'),
        entry(type: 'expense', amount: 1600),
      ]);
      expect(b.balanceMinor, -100);
      expect(b.entryCount, 1);
    });

    test("entries in another currency than the account's are left out", () {
      final b = only(account('hdfc'), [
        entry(type: 'income', amount: 100, accountId: 'hdfc'),
        entry(type: 'income', amount: 999, accountId: 'hdfc', currency: 'USD'),
      ]);
      expect(b.balanceMinor, 100);
      expect(b.entryCount, 1);
    });

    test('deleted accounts get no balance; the others keep the order given', () {
      final out = accountBalances(
        [account('b'), account('gone', deleted: true), account('a', closed: true)],
        [entry(type: 'income', amount: 5, accountId: 'a')],
      );
      expect([for (final b in out) b.account.id], ['b', 'a']);
      expect(out.last.balanceMinor, 5);
      expect(out.first.lastActivityDay, isNull);
      expect(out.first.entryCount, 0);
    });

    test('a row synced before migration 0013 (no direction) moves money the way its type does', () {
      final income = entry(type: 'income', amount: 100, accountId: 'hdfc', noDirection: true);
      final spend = entry(type: 'expense', amount: 30, accountId: 'hdfc', noDirection: true);
      expect(income.flow, MoneyFlow.inflow);
      expect(spend.flow, MoneyFlow.outflow);
      expect(only(account('hdfc'), [income, spend]).balanceMinor, 70);
    });
  });

  test('ledger order: day, a correction first in its day, then the SMS time, then made, then id', () {
    final late = entry(id: 'late', day: 20260902, time: '09:00', sms: true);
    final fix = entry(id: 'fix', type: 'adjustment', direction: 'in', day: 20260902, time: '23:00', sms: true);
    final early = entry(id: 'early', day: 20260901, time: '23:59', sms: true);
    final b = entry(id: 'b', day: 20260902, time: '10:00', sms: true);
    final a = entry(id: 'a', day: 20260902, time: '10:00', sms: true);
    // Made later, but happened earlier the same day: the SMS time decides.
    final first = entry(id: 'z', day: 20260902, time: '08:00', sms: true);
    final sorted = [late, fix, b, early, a, first]..sort(compareLedgerOrder);
    expect([for (final e in sorted) e.id], ['early', 'fix', 'z', 'late', 'a', 'b']);
    // The same time: when it was made decides, then the id.
    final m1 = entry(id: 'y'), m2 = entry(id: 'x');
    expect(compareLedgerOrder(m1, m2), lessThan(0));
    expect(compareLedgerOrder(m1, m1), 0);
  });

  group('checkpoints', () {
    test("the latest reported balance against the entries' balance up to it", () {
      final b = only(account('hdfc', opening: 1000), [
        entry(type: 'income', amount: 500, accountId: 'hdfc', day: 20260901, balance: 1500, sms: true),
        entry(type: 'expense', amount: 200, accountId: 'hdfc', day: 20260905, balance: 1250, sms: true),
        entry(type: 'expense', amount: 100, accountId: 'hdfc', day: 20260906),
      ]);
      expect(b.balanceMinor, 1200);
      expect(b.lastActivityDay, 20260906);
      final k = b.lastReported!;
      expect(k.day, 20260905);
      expect(k.reportedMinor, 1250);
      expect(k.derivedMinor, 1300);
      expect(k.gapMinor, -50);
    });

    test("liabilities have none: a card's SMS reports its limit", () {
      final b = only(account('card', type: AccountType.creditCard), [
        entry(type: 'expense', amount: 500, accountId: 'card', balance: 15000000, sms: true),
      ]);
      expect(b.lastReported, isNull);
    });

    test('a reported zero is a report', () {
      final b = only(account('hdfc'), [entry(type: 'expense', amount: 5, accountId: 'hdfc', balance: 0)]);
      expect(b.lastReported!.gapMinor, 5);
    });
  });

  group('reconcile', () {
    test('a correction dated on the checkpoint day closes the gap there, and moves the balance now', () {
      final hdfc = account('hdfc', opening: 1000);
      final entries = [
        entry(type: 'expense', amount: 300, accountId: 'hdfc', day: 20260910, time: '08:00', sms: true),
        entry(type: 'expense', amount: 200, accountId: 'hdfc', day: 20260910, time: '18:00', balance: 900, sms: true),
        entry(type: 'income', amount: 50, accountId: 'hdfc', day: 20260912),
      ];
      final before = only(hdfc, entries);
      expect(before.lastReported!.gapMinor, 900 - 500);
      final fix = reconcileDelta(before, before.lastReported!.reportedMinor)!;
      expect(fix.flow, MoneyFlow.inflow);
      expect(fix.amountMinor, 400);
      final after = only(hdfc, [
        ...entries,
        entry(type: 'adjustment', direction: fix.flow.wire, amount: fix.amountMinor, accountId: 'hdfc', day: 20260910),
      ]);
      expect(after.lastReported!.gapMinor, 0);
      expect(after.balanceMinor, before.balanceMinor + 400);
      expect(reconcileDelta(after, 900), isNull);
    });

    test('against the balance now, and for a liability (what you owe)', () {
      final bank = only(account('hdfc', opening: 1000), [entry(type: 'expense', amount: 100, accountId: 'hdfc')]);
      expect(reconcileDelta(bank, 600, atCheckpoint: false), (flow: MoneyFlow.outflow, amountMinor: 300));
      // No reported balance: at the checkpoint means now.
      expect(reconcileDelta(bank, 950), (flow: MoneyFlow.inflow, amountMinor: 50));
      final card = only(account('card', type: AccountType.creditCard), [
        entry(type: 'expense', amount: 300, accountId: 'card'),
      ]);
      expect(reconcileDelta(card, 500), (flow: MoneyFlow.outflow, amountMinor: 200));
      expect(reconcileDelta(card, 100), (flow: MoneyFlow.inflow, amountMinor: 200));
      expect(reconcileDelta(card, 300), isNull);
    });
  });

  group('openingFromFirstReport', () {
    test('makes the balance right after the first report equal it (later reports, deleted entries aside)', () {
      final entries = [
        entry(type: 'expense', amount: 100, day: 20260901),
        entry(type: 'expense', amount: 999, day: 20260902, deletedAt: '2026-09-03T00:00:00Z', balance: 1),
        entry(type: 'income', amount: 1000, day: 20260903, balance: 5000),
        entry(type: 'expense', amount: 10, day: 20260904, balance: 123),
      ];
      expect(openingFromFirstReport(entries, AccountType.bank), 5000 - 1000 + 100);
      expect(openingFromFirstReport(entries, AccountType.creditCard), 0);
      expect(openingFromFirstReport(const [], AccountType.cash), 0);
    });

    test("on the seeded data, HDFC's first reported balance has no gap", () {
      // The sync fixture's HDFC entries, linked to their account the way migration 0013's backfill
      // links them (if the fixture doesn't carry account_id yet).
      final fixture = jsonDecode(File('test/fixtures/sync/john.json').readAsStringSync()) as Map<String, dynamic>;
      final entities = [
        for (final s in (fixture['snapshots'] as Map).values)
          for (final e in (s['entities'] as List).cast<Map<String, dynamic>>()) e,
      ];
      final me = entities.firstWhere((e) => e['entity'] == 'profile')['entity_id'] as String;
      const label = 'HDFC ··4821';
      final id = smsAccountId(me, label);
      final synced = [
        for (final e in entities)
          if (e['entity'] == 'personal_account') FinAccount.read((e['data'] as Map).cast())!,
      ];
      final rows = [
        for (final e in entities)
          if (e['entity'] == 'personal_transaction' && (e['data'] as Map)['account'] == label)
            FinEntry({...(e['data'] as Map).cast<String, dynamic>(), 'account_id': id}),
      ];
      final opening = openingFromFirstReport(rows, AccountType.bank);
      expect(opening, 2748000, reason: '₹1,12,480 reported with the ₹85,000 salary');
      final hdfc = synced.where((a) => a.id == id).firstOrNull ?? account(id, opening: opening, label: label);
      expect(hdfc.openingMinor, opening);
      final firstReport = ([...rows.where((e) => e.balance != null && !e.deleted)]..sort(compareLedgerOrder)).first;
      final upToIt = [
        for (final e in rows)
          if (compareLedgerOrder(e, firstReport) <= 0) e,
      ];
      final b = only(hdfc, upToIt);
      expect(b.lastReported!.entryId, firstReport.id);
      expect(b.lastReported!.gapMinor, 0);
      // Later reports show what the entries miss.
      expect(only(hdfc, rows).lastReported!.gapMinor, isNot(0));
    });
  });
}
