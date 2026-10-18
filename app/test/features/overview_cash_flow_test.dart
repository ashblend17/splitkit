import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/clock.dart';
import 'package:splitkit/core/finance/finance_providers.dart';
import 'package:splitkit/core/integrations.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/local/writes.dart';
import 'package:splitkit/design_system/design_system.dart';
import 'package:splitkit/features/personal/accounts_page.dart';

import '../fake_backend.dart';
import '../helpers.dart';

/// The seed's accounts (test/fixtures/sync/john.json).
const hdfc = '21aa8dac-2761-5677-ad69-c1b5e7fe9543';
const icici = 'bf514d30-82b8-5c59-adb4-c61a838811a6';
const savings = '137b07e8-c67b-5bb2-a5a7-4f58aa342755'; // Emergency savings
const swiggy = '7519b197-caab-50b4-83b7-16f72b5b9456'; // ₹486 on 23 Sep, HDFC

const tall = Size(390, 1600);
const desktop = Size(1440, 1000);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

LocalWrites _writes(WidgetTester tester) => appContainer(tester).read(writesProvider);

/// An entry made on this device, as if typed or read from an SMS ([at]).
Future<String> _entry(
  WidgetTester tester, {
  required PersonalTxnInTypeEnum type,
  required int amount,
  required DateTime day,
  String description = 'Card spend',
  String? accountId,
  DateTime? at,
}) => runWrite(
  tester,
  _writes(tester).createPersonal(
    PersonalTxnIn(
      type: type,
      amountMinor: amount,
      description: description,
      date: day,
      accountId: accountId,
      smsAt: at,
      source_: at == null ? PersonalTxnInSource_Enum.manual : PersonalTxnInSource_Enum.sms,
      reviewed: true,
    ),
  ),
);

List<(String, String, Map?)> _queued(WidgetTester tester) => [
  for (final op in appContainer(tester).read(outboxProvider)) (op.method, op.path, op.body as Map?),
];

/// The summary card's line [label] says [value].
void _line(String label, String value) => expect(
  find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
    matching: find.text(value),
  ),
  findsOneWidget,
  reason: '$label: $value',
);

/// The tile of the summary card labelled [label] shows [value].
void _tile(String label, String value) => expect(
  find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
    matching: find.text(value),
  ),
  findsOneWidget,
  reason: '$label: $value',
);

void main() {
  setUpAll(loadFonts);

  group('the month on Overview', () {
    for (final (name, size) in [('a phone', tall), ('a desktop', desktop)]) {
      testWidgets('on $name: what you spent with your group share, income, left over, saved', (tester) async {
        await pumpApp(tester, location: '/personal', size: size);
        expect(find.text('Spent in September'), findsOneWidget);
        expect(find.text('₹50,660'), findsOneWidget);
        _line('On your own', '₹32,450');
        _line('Your share in groups', '₹18,210');
        expect(find.textContaining('Refunds'), findsNothing); // none in September
        _tile('Income', '₹85,000');
        _tile('Left over', '₹34,340');
        _tile('Saved', '40%');
        _line('Invested', '₹5,000'); // the SIP
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a refund comes off what you spent, on a line of its own', (tester) async {
      final be = await pumpApp(tester, location: '/personal', size: tall);
      be.offline = true;
      await runWrite(
        tester,
        _writes(tester).recordRefund(
          amountMinor: 18600,
          date: DateTime(2026, 9, 24),
          description: 'Swiggy refund',
          refundOfId: swiggy,
        ),
      );
      expect(find.text('₹50,474'), findsOneWidget);
      _line('Refunds', '−₹186');
      _line('On your own', '₹32,450');
    });

    testWidgets('your group share counts only while both flags say so', (tester) async {
      // Shown next to your spending, but not part of it.
      const shown = Integrations(groupShareInCashFlow: false);
      await pumpApp(
        tester,
        location: '/personal',
        size: tall,
        overrides: [integrationsProvider.overrideWithValue(shown)],
      );
      expect(find.text('₹32,450'), findsOneWidget);
      expect(find.textContaining('On your own'), findsNothing); // only your own spending: nothing to break down
      _line('Your share in groups (not counted)', '₹18,210');
      _tile('Left over', '₹52,550');
      _tile('Saved', '62%');

      const off = Integrations(groupShareInPersonal: false);
      await pumpApp(
        tester,
        location: '/personal',
        size: tall,
        overrides: [integrationsProvider.overrideWithValue(off)],
      );
      expect(find.text('₹32,450'), findsOneWidget);
      expect(find.textContaining('Your share in groups'), findsNothing);
      expect(find.text('₹18,210'), findsNothing);
      _tile('Left over', '₹52,550');
    });

    testWidgets('spending more than you earned: overspent, and a saved rate below zero', (tester) async {
      final be = await pumpApp(tester, location: '/personal', size: tall);
      be.offline = true;
      await _entry(tester, type: PersonalTxnInTypeEnum.expense, amount: 10000000, day: DateTime.utc(2026, 9, 24));
      expect(find.text('₹1,50,660'), findsOneWidget);
      _tile('Overspent', '₹65,660');
      _tile('Saved', '−77%');
    });

    testWidgets('an empty month says so and offers Add entry; with no income, no rate', (tester) async {
      final before = appClock;
      appClock = Clock.fixed(DateTime(2026, 10, 3, 12));
      addTearDown(() => appClock = before);
      final be = await pumpApp(tester, location: '/personal', size: tall);
      be.offline = true;
      expect(find.text('Spent in October'), findsOneWidget);
      expect(find.text('Nothing this month yet'), findsOneWidget);
      expect(find.text('₹0'), findsNothing);
      await _tap(tester, find.widgetWithText(SkButton, 'Add entry'));
      expect(find.text('Add expense'), findsOneWidget);
      Navigator.of(tester.element(find.text('Add expense'))).pop();
      await tester.pumpAndSettle();

      await _entry(tester, type: PersonalTxnInTypeEnum.expense, amount: 25000, day: DateTime.utc(2026, 10, 2));
      expect(find.text('Nothing this month yet'), findsNothing);
      _tile('Income', '₹0');
      _tile('Left over', '—');
      _tile('Saved', '—');
    });
  });

  group("Overview's accounts", () {
    for (final (name, size) in [('a phone', tall), ('a desktop', desktop)]) {
      testWidgets('on $name: net worth, the three biggest, and how many to check', (tester) async {
        await pumpApp(tester, location: '/personal', size: size);
        final card = find.ancestor(of: find.text('Net worth'), matching: find.byType(SkCard));
        Finder inCard(String text) => find.descendant(of: card, matching: find.text(text));
        expect(inCard('₹2,19,765'), findsOneWidget);
        expect(inCard('1 to check'), findsOneWidget); // HDFC: the bank said ₹39,936
        expect(inCard('Emergency savings'), findsOneWidget);
        expect(inCard('₹1,20,000'), findsOneWidget);
        expect(inCard('HDFC ··4821'), findsOneWidget);
        expect(inCard('Cash'), findsWidgets);
        expect(inCard('Zerodha'), findsNothing);
        expect(inCard('ICICI Credit card ··9012'), findsNothing);
        expect(tester.takeException(), isNull);
        await _tap(tester, inCard('1 to check'));
        expect(find.byType(AccountsPage), findsOneWidget);
      });
    }

    testWidgets('without what the bank said (accountBalances off), nothing to check', (tester) async {
      const narrow = Features(accountBalances: false);
      await pumpApp(tester, location: '/personal', size: tall, overrides: [featuresProvider.overrideWithValue(narrow)]);
      expect(find.text('Net worth'), findsOneWidget);
      expect(find.text('1 to check'), findsNothing);
      await _tap(tester, find.text('All accounts'));
      expect(find.textContaining('Bank said'), findsNothing);
      expect(find.text('Reconcile'), findsNothing);
    });

    testWidgets('with no accounts, an offer to add one', (tester) async {
      final be = FakeBackend();
      for (final s in be.snapshots.values) {
        ((s as Map)['entities'] as List).removeWhere((e) => (e as Map)['entity'] == 'personal_account');
      }
      await pumpApp(tester, backend: be, location: '/personal', size: tall);
      expect(find.text('See balances and net worth'), findsOneWidget);
      expect(find.text('All accounts'), findsNothing);
      await _tap(tester, find.widgetWithText(SkButton, 'Add account'));
      expect(find.text('Opening balance'), findsOneWidget);
    });

    testWidgets('none of it while accounts are off', (tester) async {
      const off = Features(accounts: false);
      await pumpApp(tester, location: '/personal', size: tall, overrides: [featuresProvider.overrideWithValue(off)]);
      expect(find.text('Net worth'), findsNothing);
      expect(find.text('Accounts'), findsNothing);
    });
  });

  group('Just in: a spend and an income that look like one transfer', () {
    /// ₹5,000 out of HDFC and into Emergency savings, five minutes apart, both from bank SMS.
    Future<(String, String)> pair(WidgetTester tester) async {
      final out = await _entry(
        tester,
        type: PersonalTxnInTypeEnum.expense,
        amount: 500000,
        day: DateTime.utc(2026, 9, 24),
        description: 'NEFT to self',
        accountId: hdfc,
        at: DateTime.utc(2026, 9, 24, 10),
      );
      final into = await _entry(
        tester,
        type: PersonalTxnInTypeEnum.income,
        amount: 500000,
        day: DateTime.utc(2026, 9, 24),
        description: 'From JOHN D',
        accountId: savings,
        at: DateTime.utc(2026, 9, 24, 10, 5),
      );
      return (out, into);
    }

    final suggestion = find.ancestor(of: find.text('Looks like a transfer'), matching: find.byType(SkCard));

    testWidgets('This was a transfer makes them its two halves', (tester) async {
      final be = await pumpApp(tester, location: '/personal', size: tall);
      be.offline = true;
      final (out, into) = await pair(tester);
      expect(find.text('Just in'), findsOneWidget);
      expect(find.descendant(of: suggestion, matching: find.text('HDFC ··4821 → Emergency savings')), findsOneWidget);
      expect(find.descendant(of: suggestion, matching: find.text('₹5,000')), findsOneWidget);
      expect(find.text('₹55,660'), findsOneWidget); // the ₹5,000 counts as spending until then
      await _tap(tester, find.text('This was a transfer'));
      final (method, path, body) = _queued(tester).last;
      expect((method, path), ('POST', '/api/v1/personal/batch'));
      expect(
        [
          for (final i in (body!['items'] as List).cast<Map>())
            (i['op'], i['id'], i['transaction']['type'], i['transaction']['direction'], i['transaction']['reviewed']),
        ],
        [('update', out, 'transfer', 'out', true), ('update', into, 'transfer', 'in', true)],
      );
      expect(find.text('Looks like a transfer'), findsNothing);
      expect(find.text('₹50,660'), findsOneWidget); // neither spending nor income now
    });

    testWidgets("Not a transfer: it isn't offered again", (tester) async {
      final be = await pumpApp(tester, location: '/personal', size: tall);
      be.offline = true;
      final (out, into) = await pair(tester);
      final queued = _queued(tester).length;
      await _tap(tester, find.text('Not a transfer'));
      expect(find.text('Looks like a transfer'), findsNothing);
      expect(_queued(tester).length, queued, reason: 'kept on this device, not sent');
      expect(appContainer(tester).read(notTransferProvider).value, {'$out|$into'});
    });

    testWidgets('none while transferSuggestions is off', (tester) async {
      const off = Features(transferSuggestions: false);
      final be = await pumpApp(
        tester,
        location: '/personal',
        size: tall,
        overrides: [featuresProvider.overrideWithValue(off)],
      );
      be.offline = true;
      await pair(tester);
      expect(find.text('Looks like a transfer'), findsNothing);
    });
  });

  group('Transactions', () {
    testWidgets('filter by one of your accounts', (tester) async {
      await pumpApp(tester, location: '/personal/transactions', size: tall);
      await _tap(tester, find.text('All accounts'));
      for (final name in ['HDFC ··4821', 'ICICI Credit card ··9012', 'Cash', 'Emergency savings', 'Zerodha']) {
        expect(find.text(name), findsOneWidget);
      }
      await _tap(tester, find.text('ICICI Credit card ··9012'));
      expect(find.text('ICICI Credit card ··9012'), findsOneWidget); // the filter, now
      expect(find.text('Blue Tokai coffee'), findsOneWidget);
      expect(find.text('Swiggy order'), findsNothing);
    });

    testWidgets("a link to an account's entries, by id or by an old SMS label", (tester) async {
      for (final link in ['account_id=$hdfc', 'account=${Uri.encodeQueryComponent('HDFC ··4821')}']) {
        await pumpApp(tester, location: '/personal/transactions?$link', size: tall);
        expect(find.text('HDFC ··4821'), findsOneWidget, reason: link);
        expect(find.text('Swiggy order'), findsOneWidget, reason: link);
        expect(find.text('Rapido ride'), findsOneWidget, reason: link);
        expect(find.text('Blue Tokai coffee'), findsNothing, reason: link);
        expect(find.text('Weekend groceries'), findsNothing, reason: link); // no account
      }
      await pumpApp(tester, location: '/personal/transactions?account_id=$icici', size: tall);
      expect(find.text('Blue Tokai coffee'), findsOneWidget);
      expect(find.text('Swiggy order'), findsNothing);
    });

    testWidgets('transfers: both halves, no categories, nothing added up', (tester) async {
      await pumpApp(tester, location: '/personal/transactions', size: tall);
      await _tap(tester, find.text('Expenses only'));
      await _tap(tester, find.text('Transfers only'));
      expect(find.text('Credit card bill'), findsNWidgets(2));
      expect(find.text('Cash withdrawal'), findsNWidgets(2));
      expect(find.text('Swiggy order'), findsNothing);
      expect(find.text("Money moved between your accounts isn't spending or income."), findsOneWidget);
      expect(find.text('₹4,999 moved'), findsOneWidget); // 5 Sep's day
      expect(find.text('Food'), findsNothing); // no category chips
    });

    testWidgets('refunds, with their total', (tester) async {
      final be = await pumpApp(tester, location: '/personal/transactions', size: tall);
      be.offline = true;
      await runWrite(
        tester,
        _writes(tester).recordRefund(
          amountMinor: 10000,
          date: DateTime(2026, 9, 24),
          description: 'Swiggy refund',
          refundOfId: swiggy,
        ),
      );
      await _tap(tester, find.text('Expenses only'));
      await _tap(tester, find.text('Refunds only'));
      expect(find.text('Swiggy refund'), findsOneWidget);
      expect(find.text('Swiggy order'), findsNothing);
      final totals = find.ancestor(of: find.text('Per day'), matching: find.byType(SkCard));
      expect(find.descendant(of: totals, matching: find.text('Refunds')), findsOneWidget);
      expect(find.descendant(of: totals, matching: find.text('₹100')), findsOneWidget);
      expect(find.text('₹100 back'), findsOneWidget);
    });

    testWidgets('without accounts or the new types, the filters offer neither', (tester) async {
      const off = Features(accounts: false, transfers: false, refunds: false);
      await pumpApp(
        tester,
        location: '/personal/transactions',
        size: tall,
        overrides: [featuresProvider.overrideWithValue(off)],
      );
      expect(find.text('All accounts'), findsNothing);
      expect(find.text('Any way paid'), findsOneWidget);
      await _tap(tester, find.text('Expenses only'));
      expect(find.text('Transfers only'), findsNothing);
      expect(find.text('Refunds only'), findsNothing);
      expect(find.text('Everything'), findsOneWidget);
    });
  });
}
