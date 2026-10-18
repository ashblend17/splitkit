import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/integrations.dart';
import 'package:splitkit/core/local/ledger.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/design_system/design_system.dart';
import 'package:splitkit/features/personal/personal_txn_sheet.dart';

import '../fake_backend.dart';
import '../helpers.dart';

// The holdings screens (finance revamp design §5.2) on the seed (test/fixtures/sync/john.json),
// on 25 Sep 2026: Zerodha holds the Nifty fund (₹68,450 on 15 Aug, cost ₹60,000, named by the
// ₹5,000 SIP from HDFC on 5 Sep) and Tata shares (₹12,300 on 20 Sep, no cost), ₹85,750 in all.

const zerodha = '3ba3ab40-68eb-5169-bd41-e06f44ea0e71';
const nifty = '4df4e7ab-a0dd-51d0-bf85-5f4a024a292b';
const tata = 'af3e636e-ac31-52d0-94fe-467a6c1c2889';
const hdfc = '21aa8dac-2761-5677-ad69-c1b5e7fe9543';
const sip = '9ca547fb-7076-576a-8278-d6b129425c96';

const tall = Size(390, 1400);
const desktop = Size(1440, 900);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _inRow(String id, String text) =>
    find.descendant(of: find.byKey(ValueKey('holding:$id')), matching: find.text(text));

Finder _holdings() => find.byKey(const ValueKey('holdings:$zerodha'));

/// The text fields of the sheet on top.
Finder _fields() => find.descendant(of: find.byType(BottomSheet).last, matching: find.byType(TextField));

List<(String, String, Map?)> _queued(WidgetTester tester) => [
  for (final op in appContainer(tester).read(outboxProvider)) (op.method, op.path, op.body as Map?),
];

Ledger _ledger(WidgetTester tester) => appContainer(tester).read(localStoreProvider).value!.ledger;

void main() {
  setUpAll(loadFonts);

  group('Accounts page', () {
    for (final (name, size) in [('a phone', tall), ('a tablet', const Size(600, 1000)), ('a desktop', desktop)]) {
      testWidgets('on $name: Zerodha at its holdings, each with its value, age and gain', (tester) async {
        await pumpApp(tester, location: '/personal/accounts', size: size);
        // The account at what it's worth, not its ₹0 balance.
        expect(
          find.descendant(of: find.byKey(const ValueKey('account:$zerodha')), matching: find.text('₹85,750')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _holdings(), matching: find.text('Holdings ₹85,750 · incl. ₹5,000 added since 15 Aug')),
          findsOneWidget,
        );
        // The fund: its value with the SIP at cost, stale (41 days), its gain on its cost.
        expect(_inRow(nifty, 'Nifty 50 index fund'), findsOneWidget);
        expect(_inRow(nifty, '₹73,450'), findsOneWidget);
        expect(_inRow(nifty, 'Mutual fund · Value as of 15 Aug · incl. ₹5,000 added since'), findsOneWidget);
        expect(_inRow(nifty, 'Stale'), findsOneWidget);
        expect(_inRow(nifty, '+₹8,450 · +14.08%'), findsOneWidget);
        // The shares: fresh, and no gain without a cost.
        expect(_inRow(tata, '₹12,300'), findsOneWidget);
        expect(_inRow(tata, 'Shares · Value as of 20 Sep'), findsOneWidget);
        expect(_inRow(tata, 'Stale'), findsNothing);
        expect(
          find.descendant(of: find.byKey(const ValueKey('holding:$tata')), matching: find.textContaining('+')),
          findsNothing,
        );
        expect(find.descendant(of: _holdings(), matching: find.text('Add holding')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('an investment account with no holdings says what to add', (tester) async {
      final be = FakeBackend();
      for (final s in be.snapshots.values) {
        ((s as Map)['entities'] as List).removeWhere((e) => (e as Map)['entity'] == 'personal_holding');
      }
      await pumpApp(tester, backend: be, location: '/personal/accounts', size: tall);
      expect(find.text('Add what you hold here (a fund, shares, gold) to value this account.'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('account:$zerodha')), matching: find.text('₹0')),
        findsOneWidget,
      );
      await _tap(tester, find.text('Add holding'));
      expect(find.text('In Zerodha'), findsOneWidget);
    });

    testWidgets('none of it while holdings are off: Zerodha at its balance', (tester) async {
      const off = Features(holdings: false);
      await pumpApp(
        tester,
        location: '/personal/accounts',
        size: tall,
        overrides: [featuresProvider.overrideWithValue(off)],
      );
      expect(_holdings(), findsNothing);
      expect(
        find.descendant(of: find.byKey(const ValueKey('account:$zerodha')), matching: find.text('₹0')),
        findsOneWidget,
      );
    });
  });

  group('Holding sheets', () {
    testWidgets('Add holding: one POST, shown at once and counted', (tester) async {
      final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
      be.offline = true;
      await _tap(tester, find.descendant(of: _holdings(), matching: find.text('Add holding')));
      await _tap(tester, find.widgetWithText(SelectableChip, 'Gold'));
      await tester.enterText(_fields().at(0), 'Gold coins');
      await tester.enterText(_fields().at(1), '25000');
      await tester.enterText(_fields().at(2), '10.5');
      await tester.enterText(_fields().at(3), '24000');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(SkButton, 'Add holding').last);
      final (method, path, body) = _queued(tester).single;
      expect((method, path), ('POST', '/api/v1/personal/holdings'));
      expect(
        (
          body!['account_id'],
          body['name'],
          body['asset_type'],
          body['market_value_minor'],
          body['valuation_at'],
          body['quantity'],
          body['cost_basis_minor'],
        ),
        (zerodha, 'Gold coins', 'gold', 2500000, '2026-09-25', '10.5', 2400000),
      );
      final id = body['id'] as String;
      expect(_inRow(id, '₹25,000'), findsOneWidget);
      expect(_inRow(id, '+₹1,000 · +4.16%'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('account:$zerodha')), matching: find.text('₹1,10,750')),
        findsOneWidget,
      );
    });

    testWidgets('editing a holding sends what changed; a cost shows its gain', (tester) async {
      final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
      be.offline = true;
      await _tap(tester, _inRow(tata, 'Tata Motors shares'));
      expect(find.text('Shares · In Zerodha'), findsOneWidget);
      expect(find.text('₹12,300'), findsWidgets);
      expect(find.text('Value as of 20 Sep'), findsOneWidget);
      expect(find.textContaining('Gain'), findsNothing);
      await tester.enterText(_fields().at(2), '10000'); // what you paid
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Save changes'));
      final (method, path, body) = _queued(tester).single;
      expect((method, path), ('PUT', '/api/v1/personal/holdings/$tata'));
      expect(
        (body!['name'], body['quantity'], body['cost_basis_minor'], body['market_value_minor']),
        ('Tata Motors shares', '18', 1000000, 1230000),
      );
      expect(_inRow(tata, '+₹2,300 · +23%'), findsOneWidget);
    });

    testWidgets('Update value: today by default, the stale badge goes', (tester) async {
      final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
      be.offline = true;
      await _tap(tester, _inRow(nifty, 'Nifty 50 index fund'));
      expect(find.text('Gain +₹8,450 · +14.08%'), findsOneWidget);
      await _tap(tester, find.widgetWithText(SkButton, 'Update value'));
      expect(find.text('Nifty 50 index fund · ₹68,450 on 15 Aug'), findsOneWidget);
      expect(find.text('Leave it empty to keep ₹60,000.'), findsOneWidget);
      expect(find.textContaining('Today'), findsOneWidget);
      await tester.enterText(_fields().at(0), '75000');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(SkButton, 'Update value').last);
      final (method, path, body) = _queued(tester).single;
      expect((method, path), ('PUT', '/api/v1/personal/holdings/$nifty'));
      expect(
        (body!['market_value_minor'], body['valuation_at'], body['cost_basis_minor'], body['quantity']),
        (7500000, '2026-09-25', 6000000, '412.358'),
      );
      expect(find.text('Updated the value of Nifty 50 index fund'), findsOneWidget);
      Navigator.of(tester.element(find.text('Save changes'))).pop();
      await tester.pumpAndSettle();
      // The SIP was before the new value, so it's in it now.
      expect(_inRow(nifty, '₹75,000'), findsOneWidget);
      expect(_inRow(nifty, 'Stale'), findsNothing);
      expect(find.descendant(of: _holdings(), matching: find.text('Holdings ₹87,300 · as of 20 Sep')), findsOneWidget);
    });

    testWidgets("a value can't be from after today", (tester) async {
      await pumpApp(tester, location: '/personal/accounts', size: tall);
      await _tap(tester, find.descendant(of: _holdings(), matching: find.text('Add holding')));
      await _tap(tester, find.textContaining('Today'));
      final picker = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      expect(picker.lastDate, DateTime(2026, 9, 25));
    });

    testWidgets('deleting a holding, and Undo; one an entry names is refused', (tester) async {
      final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
      be.offline = true;
      await _tap(tester, _inRow(nifty, 'Nifty 50 index fund'));
      await _tap(tester, find.widgetWithText(SkButton, 'Delete'));
      expect(find.text('An entry names this holding. Change or delete them first'), findsOneWidget);
      expect(_queued(tester), isEmpty);
      Navigator.of(tester.element(find.text('Save changes'))).pop();
      await tester.pumpAndSettle();

      await _tap(tester, _inRow(tata, 'Tata Motors shares'));
      await _tap(tester, find.widgetWithText(SkButton, 'Delete'));
      expect(_queued(tester).single.$1, 'DELETE');
      expect(_queued(tester).single.$2, '/api/v1/personal/holdings/$tata');
      expect(find.text('Deleted Tata Motors shares'), findsOneWidget);
      expect(find.byKey(const ValueKey('holding:$tata')), findsNothing);
      // Zerodha is worth what the fund is now: the account and the fund's row.
      expect(
        find.descendant(of: find.byKey(const ValueKey('account:$zerodha')), matching: find.text('₹73,450')),
        findsNWidgets(2),
      );
      await _tap(tester, find.text('Undo'));
      expect(_queued(tester).last.$2, '/api/v1/personal/holdings/$tata/restore');
      expect(_inRow(tata, '₹12,300'), findsOneWidget);
    });
  });

  group('Entry sheet', () {
    Future<void> open(WidgetTester tester, {String? id, String type = 'expense'}) async {
      showPersonalTxnSheet(
        tester.element(find.byType(Scaffold).first),
        existing: id == null ? null : PersonalTxnOut.fromJson(_ledger(tester).personalTransaction(id))!,
        type: type,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an investment names a holding; an edit keeps it', (tester) async {
      final be = await pumpApp(tester, location: '/personal', size: tall);
      be.offline = true;
      await open(tester, id: sip);
      expect(find.text('Holding'), findsOneWidget);
      expect(find.text('Nifty 50 index fund'), findsOneWidget);
      expect(find.text('Zerodha · Mutual fund'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'Monthly SIP');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Save changes'));
      final (method, _, body) = _queued(tester).single;
      expect((method, body!['description'], body['holding_id']), ('PUT', 'Monthly SIP', nifty));
    });

    testWidgets('a new withdrawal picks any of your holdings; another type names none', (tester) async {
      final be = await pumpApp(tester, location: '/personal', size: tall);
      be.offline = true;
      await open(tester, type: 'investment_withdrawal');
      await _tap(tester, find.text('A holding (optional)'));
      expect(find.text('No particular holding'), findsOneWidget);
      expect(find.text('Zerodha · Shares'), findsOneWidget);
      await _tap(tester, find.text('Tata Motors shares'));
      expect(find.text('Zerodha · Shares'), findsOneWidget); // picked
      await tester.enterText(find.byType(TextField).at(0), '2000');
      await tester.enterText(find.byType(TextField).at(1), 'Sold 3 shares');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(SelectableChip, 'HDFC ··4821'));
      await _tap(tester, find.text('Save withdrawal'));
      final body = _queued(tester).single.$3!;
      expect((body['type'], body['holding_id'], body['account_id']), ('investment_withdrawal', tata, hdfc));

      await open(tester, id: sip);
      await _tap(tester, find.widgetWithText(SelectableChip, 'Expense'));
      expect(find.text('Holding'), findsNothing);
      await _tap(tester, find.text('Save changes'));
      expect(_queued(tester).last.$3!['holding_id'], isNull);
    });
  });
}
