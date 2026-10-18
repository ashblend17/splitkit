import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/copy/copy.dart';
import 'package:splitkit/core/local/ledger.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/local/writes.dart';
import 'package:splitkit/core/theme/theme.dart';
import 'package:splitkit/design_system/design_system.dart';
import 'package:splitkit/features/personal/personal_txn_sheet.dart';

import '../fake_backend.dart';
import '../helpers.dart';

/// The seed's accounts and entries (test/fixtures/sync/john.json). The tests run on 25 Sep 2026.
const hdfc = '21aa8dac-2761-5677-ad69-c1b5e7fe9543';
const icici = 'bf514d30-82b8-5c59-adb4-c61a838811a6';
const cash = '6b3de561-066a-5f99-9fba-efd3ea940df7';
const savings = '137b07e8-c67b-5bb2-a5a7-4f58aa342755';
const billOut = 'a8f30587-0742-5495-afde-7ef4b2de808b'; // Credit card bill, ₹4,999 out of HDFC on 5 Sep
const billIn = '4caca038-a686-5544-91a4-7ef77e1cc449'; // …and into the ICICI card
const atmOut = '0e7604c3-3c94-5b47-9db2-0eefbb8e2a7f'; // Cash withdrawal, ₹2,000 out of HDFC on 12 Sep
const atmIn = 'addf3cec-f211-571d-aed7-072a7a8696c4'; // …and into Cash, both made by hand
const rapido = '51a715d3-f751-52e0-bc5c-0d7422e3ca0d'; // ₹400 on HDFC, from an SMS, looked at
const coffee = '3adcf767-affd-568b-a433-2bc47cb3a252'; // Blue Tokai coffee, ₹340 on the ICICI card, Food
const salary = '2676dd92-8311-501e-8c3c-c03c47f029bd'; // ₹85,000 into HDFC on 1 Sep
const sip = '9ca547fb-7076-576a-8278-d6b129425c96'; // Index fund SIP, ₹5,000 invested from HDFC
const priceDrop = 'bf8e01fb-6596-525f-bf8d-4fe5694b9a61'; // a ₹1,490 refund in July
const swiggy = '7519b197-caab-50b4-83b7-16f72b5b9456'; // ₹486 on 23 Sep, HDFC, Food

const tall = Size(390, 1400);
const desktop = Size(1440, 1000);

Ledger _ledger(WidgetTester tester) => appContainer(tester).read(localStoreProvider).value!.ledger;
LocalWrites _writes(WidgetTester tester) => appContainer(tester).read(writesProvider);
PersonalTxnOut _txn(WidgetTester tester, String id) =>
    PersonalTxnOut.fromJson(_ledger(tester).personalTransaction(id))!;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens the sheet over the screen: entry [id], or a new one of [type].
Future<void> _open(WidgetTester tester, {String? id, String type = 'expense'}) async {
  showPersonalTxnSheet(
    tester.element(find.byType(Scaffold).first),
    existing: id == null ? null : _txn(tester, id),
    type: type,
  );
  await tester.pumpAndSettle();
}

/// The chip [label] in the account picker [picker] ('from', 'to' or 'account').
Finder _account(String picker, String label) => find.descendant(
  of: find.byKey(ValueKey('account-picker:$picker')),
  matching: find.widgetWithText(SelectableChip, label),
);

/// Text [text] in the entry sheet (the screen behind has its own).
Finder _inSheet(String text) => find.descendant(of: find.byType(BottomSheet).first, matching: find.text(text));

SelectableChip _chip(WidgetTester tester, Finder f) => tester.widget<SelectableChip>(f);
Finder _type(String label) => find.widgetWithText(SelectableChip, label);

List<OutboxOpView> _queued(WidgetTester tester) => [
  for (final op in appContainer(tester).read(outboxProvider)) (op.method, op.path, op.body as Map?),
];

typedef OutboxOpView = (String, String, Map?);

/// A batch's items: (op, id, type, direction, account).
List<(String, String, String?, String?, String?)> _items(Map body) => [
  for (final i in body['items'] as List)
    (
      i['op'] as String,
      i['id'] as String,
      i['transaction']?['type'] as String?,
      i['transaction']?['direction'] as String?,
      i['transaction']?['account_id'] as String?,
    ),
];

Future<void> _amount(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).at(0), text);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a transfer needs two accounts: Add account adds one and picks it', (tester) async {
    final be = FakeBackend();
    for (final s in be.snapshots.values) {
      ((s as Map)['entities'] as List).removeWhere((e) => (e as Map)['entity'] == 'personal_account');
    }
    await pumpApp(tester, backend: be, location: '/personal', size: tall);
    be.offline = true;
    await _open(tester);
    expect(_chip(tester, _type('Transfer')).onTap, isNull);
    expect(find.text('Transfers need two accounts.'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-picker:account')), findsNothing); // none to pick

    await _tap(
      tester,
      find.descendant(of: find.byType(BottomSheet), matching: find.widgetWithText(TextButton, 'Add account')),
    );
    await tester.enterText(
      find.descendant(of: find.widgetWithText(SkTextField, 'Name'), matching: find.byType(TextField)),
      'Wallet',
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(SkButton, 'Add account').last);
    expect(find.text('Add expense'), findsOneWidget);
    expect(_chip(tester, _account('account', 'Wallet')).selected, isTrue);
    expect(_chip(tester, _type('Transfer')).onTap, isNull, reason: 'still one account');
  });

  testWidgets('a new transfer: From and To, no category, saved as one batch of two halves', (tester) async {
    final be = await pumpApp(tester, location: '/personal', size: tall);
    be.offline = true;
    await _open(tester);
    await _tap(tester, _type('Transfer'));
    expect(find.text('Add transfer'), findsOneWidget);
    expect(find.text('Category'), findsNothing);
    expect(find.widgetWithText(SelectableChip, 'No account'), findsNothing);
    await _amount(tester, '1500');
    await tester.enterText(find.byType(TextField).at(1), 'Swiggy money'); // no category follows the words
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SelectableChip, 'Food'), findsNothing);
    await _tap(tester, _account('from', 'HDFC ··4821'));
    expect(_chip(tester, _account('to', 'HDFC ··4821')).onTap, isNull, reason: 'not into the same account');
    await _tap(tester, _account('to', 'Cash'));
    await _tap(tester, find.text('Save transfer'));

    final (method, path, body) = _queued(tester).single;
    expect((method, path), ('POST', '/api/v1/personal/batch'));
    final items = _items(body!);
    expect(
      [for (final i in items) (i.$1, i.$3, i.$4, i.$5)],
      [('create', 'transfer', 'out', hdfc), ('create', 'transfer', 'in', cash)],
    );
    expect([for (final i in body['items'] as List) i['transaction']['category_id']], [null, null]);
  });

  testWidgets('a transfer half opens the transfer and saves both halves', (tester) async {
    final be = await pumpApp(tester, location: '/personal', size: tall);
    be.offline = true;
    await _open(tester, id: billIn);
    expect(find.text('Edit transfer'), findsOneWidget);
    expect(_chip(tester, _type('Transfer')).selected, isTrue);
    expect(_chip(tester, _account('from', 'HDFC ··4821')).selected, isTrue);
    expect(_chip(tester, _account('to', 'ICICI Credit card ··9012')).selected, isTrue);
    expect(find.text('Category'), findsNothing);
    expect(_inSheet('Split it'), findsNothing);
    await _amount(tester, '5000');
    await _tap(tester, find.text('Save changes'));

    final (_, path, body) = _queued(tester).single;
    expect(path, '/api/v1/personal/batch');
    expect([for (final i in _items(body!)) (i.$1, i.$2, i.$5)], [('update', billOut, hdfc), ('update', billIn, icici)]);
    expect([for (final i in body['items'] as List) i['transaction']['amount_minor']], [500000, 500000]);
    expect(find.text('Edit transfer'), findsNothing);
  });

  testWidgets('deleting a transfer half deletes both, and Undo brings both back', (tester) async {
    final be = await pumpApp(tester, location: '/personal', size: tall);
    be.offline = true;
    await _open(tester, id: billIn);
    await _tap(tester, find.text('Delete'));
    expect(_queued(tester).single.$1, 'DELETE');
    expect(_ledger(tester).rawPersonal(billOut)!['deleted_at'], isNotNull);
    expect(_ledger(tester).rawPersonal(billIn)!['deleted_at'], isNotNull);

    await _tap(tester, find.text('Undo'));
    expect(_ledger(tester).rawPersonal(billOut)!['deleted_at'], isNull);
    expect(_ledger(tester).rawPersonal(billIn)!['deleted_at'], isNull);
  });

  testWidgets('a spend becomes a transfer from its own account', (tester) async {
    final be = await pumpApp(tester, location: '/personal', size: tall);
    be.offline = true;
    await _open(tester, id: rapido);
    await _tap(tester, _type('Transfer'));
    expect(_chip(tester, _account('from', 'HDFC ··4821')).selected, isTrue);
    await _tap(tester, _account('to', 'Cash'));
    await _tap(tester, find.text('Save changes'));

    final (_, path, body) = _queued(tester).single;
    expect(path, '/api/v1/personal/batch');
    expect(
      [for (final i in _items(body!)) (i.$1, i.$3, i.$4, i.$5)],
      [('update', 'transfer', 'out', hdfc), ('create', 'transfer', 'in', cash)],
    );
    expect(_items(body).first.$2, rapido);
  });

  testWidgets('a transfer half made a spend again: the other half, made by hand, goes', (tester) async {
    final be = await pumpApp(tester, location: '/personal', size: tall);
    be.offline = true;
    await _open(tester, id: atmOut);
    expect(find.byKey(const ValueKey('account-picker:account')), findsNothing);
    await _tap(tester, _type('Expense'));
    expect(find.text('Category'), findsOneWidget);
    expect(_chip(tester, _account('account', 'HDFC ··4821')).selected, isTrue);
    await _tap(tester, find.text('Save changes'));

    final (_, path, body) = _queued(tester).single;
    expect(path, '/api/v1/personal/batch');
    expect(
      [for (final i in _items(body!)) (i.$1, i.$2, i.$3)],
      [('update', atmOut, 'expense'), ('delete', atmIn, null)],
    );
    expect(
      (_ledger(tester).rawPersonal(atmOut)!['type'], _ledger(tester).rawPersonal(atmOut)!['transfer_group_id']),
      ('expense', null),
    );
    expect(_ledger(tester).rawPersonal(atmIn)!['deleted_at'], isNotNull);
  });

  group('refunds', () {
    testWidgets('Refund of: picking a spend takes its account and category; no more than is left', (tester) async {
      final be = await pumpApp(tester, location: '/personal', size: tall);
      be.offline = true;
      await runWrite(
        tester,
        _writes(
          tester,
        ).recordRefund(amountMinor: 10000, date: DateTime(2026, 9, 24), description: 'Part back', refundOfId: coffee),
      );
      await _open(tester, type: 'refund');
      expect(find.text('Add refund'), findsOneWidget);
      expect(_chip(tester, _account('account', 'No account')).selected, isTrue);
      await _tap(tester, find.text('A spend (optional)'));
      expect(find.textContaining('₹240 left'), findsOneWidget);
      await _tap(tester, find.text('Blue Tokai coffee').last);
      expect(find.textContaining('₹240 left to refund'), findsOneWidget);
      expect(_chip(tester, _account('account', 'ICICI Credit card ··9012')).selected, isTrue);
      expect(_chip(tester, find.widgetWithText(SelectableChip, 'Food')).selected, isTrue);

      await _amount(tester, '300');
      await tester.enterText(find.byType(TextField).at(1), 'Coffee refund');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Save refund'));
      expect(find.text('Only ₹240 of this spend is left to refund'), findsOneWidget);
      expect(_queued(tester), hasLength(1), reason: 'only the first refund');

      await _amount(tester, '240');
      await _tap(tester, find.text('Save refund'));
      final (method, path, body) = _queued(tester).last;
      expect((method, path), ('POST', '/api/v1/personal/transactions'));
      expect(
        (body!['type'], body['amount_minor'], body['refund_of_id'], body['account_id']),
        ('refund', 24000, coffee, icici),
      );
      expect(body['category_id'], _txn(tester, coffee).category!.id);
    });

    testWidgets('Record a refund on a spend opens a refund of it', (tester) async {
      final be = await pumpApp(tester, location: '/personal', size: tall);
      be.offline = true;
      await _open(tester, id: coffee);
      await _tap(tester, find.text('Record a refund'));
      expect(find.text('Edit expense'), findsNothing);
      expect(find.text('Add refund'), findsOneWidget);
      expect(find.text('Blue Tokai coffee'), findsWidgets);
      expect(find.textContaining('₹340 left to refund'), findsOneWidget);
      expect(_chip(tester, _account('account', 'ICICI Credit card ··9012')).selected, isTrue);
      await _amount(tester, '340');
      await _tap(tester, find.text('Save refund'));
      final body = _queued(tester).single.$3!;
      expect((body['type'], body['refund_of_id'], body['account_id']), ('refund', coffee, icici));
    });
  });

  testWidgets('a balance correction opens read-only, with Delete', (tester) async {
    final be = await pumpApp(tester, location: '/personal', size: tall);
    be.offline = true;
    final id = await runWrite(tester, _writes(tester).reconcile(hdfc, bankSaysMinor: 3993600, checkpointDay: 20260923));
    await _open(tester, id: id);
    expect(_inSheet('Balance correction'), findsOneWidget);
    expect(find.textContaining('A balance correction from Reconcile'), findsOneWidget);
    expect(_inSheet('Balance correction · HDFC ··4821'), findsOneWidget);
    expect(_inSheet('₹56,199'), findsOneWidget);
    for (final gone in ['Expense', 'Transfer', 'Save changes', 'Category']) {
      expect(_inSheet(gone), findsNothing, reason: gone);
    }
    await _tap(tester, find.text('Delete'));
    expect(_queued(tester).last.$1, 'DELETE');
  });

  group('actions', () {
    testWidgets('Track this cash: a cash withdrawal moves into Cash', (tester) async {
      final be = await pumpApp(tester, location: '/personal', size: tall);
      be.offline = true;
      final id = await runWrite(
        tester,
        _writes(tester).createPersonal(
          PersonalTxnIn(
            type: PersonalTxnInTypeEnum.expense,
            amountMinor: 300000,
            description: 'ATM WDL',
            date: DateTime(2026, 9, 24),
            channel: PersonalTxnInChannelEnum.atm,
            accountId: hdfc,
            source_: PersonalTxnInSource_Enum.manual,
          ),
        ),
      );
      await _open(tester, id: id);
      await _tap(tester, _inSheet('Track this cash'));
      expect(find.text('Edit expense'), findsNothing);
      final (_, path, body) = _queued(tester).last;
      expect(path, '/api/v1/personal/batch');
      expect(
        [for (final i in _items(body!)) (i.$1, i.$3, i.$4, i.$5)],
        [('update', 'transfer', 'out', hdfc), ('create', 'transfer', 'in', cash)],
      );
    });

    testWidgets('which are offered for each type', (tester) async {
      await pumpApp(tester, location: '/personal', size: tall);
      Future<void> check(String id, {required List<String> shown, required List<String> hidden}) async {
        await _open(tester, id: id);
        for (final s in shown) {
          expect(_inSheet(s), findsOneWidget, reason: '$id: $s');
        }
        for (final h in hidden) {
          expect(_inSheet(h), findsNothing, reason: '$id: $h');
        }
        Navigator.of(tester.element(find.text('Delete'))).pop();
        await tester.pumpAndSettle();
      }

      await check(coffee, shown: ['Record a refund', 'Split it'], hidden: ['Track this cash', 'This was a transfer']);
      await check(salary, shown: [], hidden: ['Record a refund', 'Split it', 'Track this cash']);
      await check(billOut, shown: [], hidden: ['Record a refund', 'Split it', 'In Split', 'Track this cash']);
      await check(sip, shown: [], hidden: ['Record a refund', 'Split it', 'In Split']);
    });

    testWidgets('This was a transfer, when a suggested pair has the entry', (tester) async {
      final be = await pumpApp(tester, location: '/personal', size: tall);
      be.offline = true;
      Future<String> sms(PersonalTxnInTypeEnum type, String account, DateTime at) => runWrite(
        tester,
        _writes(tester).createPersonal(
          PersonalTxnIn(
            type: type,
            amountMinor: 500000,
            description: 'NEFT',
            date: DateTime.utc(2026, 9, 24),
            accountId: account,
            smsAt: at,
            source_: PersonalTxnInSource_Enum.sms,
            reviewed: true,
          ),
        ),
      );
      final out = await sms(PersonalTxnInTypeEnum.expense, hdfc, DateTime.utc(2026, 9, 24, 10));
      final into = await sms(PersonalTxnInTypeEnum.income, savings, DateTime.utc(2026, 9, 24, 10, 5));
      await _open(tester, id: into);
      await _tap(tester, _inSheet('This was a transfer'));
      expect(find.text('Edit income'), findsNothing);
      final (_, path, body) = _queued(tester).last;
      expect(path, '/api/v1/personal/batch');
      expect(
        [for (final i in _items(body!)) (i.$1, i.$2, i.$3)],
        [('update', out, 'transfer'), ('update', into, 'transfer')],
      );
    });
  });

  testWidgets('personalView reads each of the seven types', (tester) async {
    await pumpApp(tester, location: '/personal', size: tall);
    final finance = _ledger(tester).finance;
    TxnView view(PersonalTxnOut t, {bool brief = false}) => personalView(t, finance: finance, brief: brief);
    (String, String, String, MoneyTone) read(TxnView v) => (v.subtitle, v.label, v.amount, v.tone);

    expect(read(view(_txn(tester, coffee))), ('Food · Card', 'spent', '₹340', MoneyTone.expense));
    expect(view(_txn(tester, coffee), brief: true).subtitle, 'Food');
    expect(read(view(_txn(tester, salary))), ('Income · Bank transfer', 'received', '+₹85,000', MoneyTone.income));
    expect(read(view(_txn(tester, billOut))), (
      'To ICICI Credit card ··9012 · Bank transfer',
      'moved',
      '₹4,999',
      MoneyTone.neutral,
    ));
    expect(read(view(_txn(tester, billIn), brief: true)), ('From HDFC ··4821', 'moved', '+₹4,999', MoneyTone.neutral));
    expect(view(_txn(tester, billIn)).glyph, 'swap');
    final refund = view(_txn(tester, priceDrop));
    expect((refund.label, refund.amount, refund.tone), ('refunded', '+₹1,490', MoneyTone.income));
    expect(refund.subtitle, isNot(contains('Uncategorised')));
    expect(read(view(_txn(tester, sip), brief: true)), ('Investment', 'invested', '₹5,000', MoneyTone.neutral));
    final withdrawal = _txn(tester, sip)
      ..type = PersonalTxnOutTypeEnum.investmentWithdrawal
      ..direction = PersonalTxnOutDirectionEnum.in_;
    expect(read(view(withdrawal, brief: true)), ('Investment', 'withdrawn', '+₹5,000', MoneyTone.neutral));
    final correction = _txn(tester, sip)
      ..type = PersonalTxnOutTypeEnum.adjustment
      ..channel = null;
    expect(read(view(correction)), ('Balance correction · HDFC ··4821', 'correction', '₹5,000', MoneyTone.neutral));
    expect(categoryLabel(_txn(tester, billOut)), 'Transfer');
    expect(categoryLabel(correction), 'Balance correction');
  });

  for (final (name, size) in [('a phone', tall), ('a desktop', desktop)]) {
    testWidgets('on $name, Transactions reads transfers, refunds and corrections as what they are', (tester) async {
      final be = await pumpApp(tester, location: '/personal/transactions', size: size);
      be.offline = true;
      await runWrite(tester, _writes(tester).reconcile(hdfc, bankSaysMinor: 3993600, checkpointDay: 20260923));
      await runWrite(
        tester,
        _writes(tester).recordRefund(
          amountMinor: 10000,
          date: DateTime(2026, 9, 24),
          description: 'Swiggy refund',
          refundOfId: swiggy,
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Expenses only'));
      await _tap(tester, find.text('Everything'));
      expect(find.text('Swiggy refund'), findsOneWidget);
      expect(find.text('+₹100'), findsOneWidget);
      expect(find.text('Balance correction · HDFC ··4821'), findsOneWidget);
      expect(find.text('Uncategorised'), findsNothing);

      await _tap(tester, find.text('Everything'));
      await _tap(tester, find.text('Transfers only'));
      expect(find.text('To ICICI Credit card ··9012'), findsOneWidget);
      expect(find.text('From HDFC ··4821'), findsNWidgets(2)); // the card bill and the cash
      expect(find.text('To Cash'), findsOneWidget);
      expect(find.text('+₹4,999'), findsOneWidget);
      expect(find.text('Uncategorised'), findsNothing);
      // Money moved, in grey, not a spend.
      expect(tester.widget<Text>(find.text('+₹4,999')).style!.color, SkColors.ink2);
      expect(tester.takeException(), isNull);
    });
  }
}
