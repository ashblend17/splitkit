import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/integrations.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/local/writes.dart';
import 'package:splitkit/design_system/design_system.dart';
import 'package:splitkit/features/expenses/add_expense_page.dart';
import 'package:splitkit/features/personal/just_in.dart';

import '../fake_backend.dart';
import '../helpers.dart';

/// Tall enough that what a test taps isn't under the floating add button.
const tall = Size(390, 1600);

const pizza = '59424173-0ad9-5fbf-9866-2a081d44a28d'; // Late-night pizza, Goa, ₹1,140, John paid
const uberSplit = '51b0947b-c74e-5296-b0b5-efcb40be6f8e'; // Uber to airport, linked in the seed

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// A spend added on the device (offline, so it stays queued and the test sees its writes).
Future<String> _entry(
  WidgetTester tester, {
  required int amount,
  required DateTime day,
  String? merchant,
  bool reviewed = true,
  PersonalTxnInTypeEnum type = PersonalTxnInTypeEnum.expense,
}) => runWrite(
  tester,
  appContainer(tester).read(writesProvider).createPersonal(
    PersonalTxnIn(
      type: type,
      amountMinor: amount,
      description: merchant ?? 'Card spend',
      merchant: merchant,
      date: day,
      channel: PersonalTxnInChannelEnum.upi,
      source_: PersonalTxnInSource_Enum.sms,
      reviewed: reviewed,
    ),
  ),
);

List<(String, String, Map?)> _queued(WidgetTester tester) => [
  for (final op in appContainer(tester).read(outboxProvider)) (op.method, op.path, op.body as Map?),
];

void main() {
  setUpAll(loadFonts);

  testWidgets('Just in: an SMS entry you haven\'t looked at, and Split it', (tester) async {
    final be = await pumpApp(tester, location: '/personal');
    be.offline = true;
    expect(find.text('Just in'), findsOneWidget);
    expect(find.text('₹32,450'), findsOneWidget);
    // Swiggy names no friend, so the short list doesn't offer a payment.
    expect(find.text('Looks right'), findsOneWidget);
    expect(find.text('Paid a friend'), findsNothing);
    await _tap(tester, find.widgetWithText(SkButton, 'Split it'));
    final page = tester.widget<AddExpensePage>(find.byType(AddExpensePage));
    expect(page.fromTxnId, isNotNull);
    expect(find.text('From your Personal entry. Only you see the link; the group sees a split.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, 'Swiggy order');
    await _tap(tester, find.text('Save split'));

    final [(post, postPath, expense), (put, putPath, link)] = _queued(tester);
    expect((post, postPath.endsWith('/expenses')), ('POST', true));
    expect((expense!['amount_minor'], expense['description']), (48600, 'Swiggy order'));
    expect((put, putPath), ('PUT', '/api/v1/personal/transactions/${page.fromTxnId}'));
    expect((link!['expense_id'], link['reviewed'], link['merchant']), (expense['id'], true, 'SWIGGY'));

    // Back on Overview: no longer "just in", and not counted (your share is, in the group).
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();
    expect(find.text('Just in'), findsNothing);
    expect(find.text('₹31,964'), findsOneWidget);
  });

  testWidgets('Just in: Looks right, and Not mine with Undo', (tester) async {
    final be = await pumpApp(tester, location: '/personal', size: tall);
    be.offline = true;
    await _tap(tester, find.text('Looks right'));
    expect(find.text('Just in'), findsNothing);
    expect(_queued(tester).single.$3!['reviewed'], true);

    final be2 = await pumpApp(tester, location: '/personal', size: tall);
    be2.offline = true;
    await _tap(tester, find.text('Not mine'));
    expect(find.text('Just in'), findsNothing);
    expect(find.text('Removed Swiggy order'), findsOneWidget);
    await _tap(tester, find.text('Undo'));
    expect([for (final w in _queued(tester)) w.$1], ['DELETE', 'POST']);
    expect(find.text('Just in'), findsOneWidget);
  });

  testWidgets('Already split: link a spend to the split you paid with the same amount', (tester) async {
    final be = await pumpApp(tester, location: '/personal', size: tall);
    be.offline = true;
    // Not looked at yet, so it's in "Just in" with its actions.
    final id = await _entry(tester, amount: 114000, day: DateTime.utc(2026, 9, 18), reviewed: false);
    await _tap(tester, find.text('Already split'));
    expect(find.text('Which split was it?'), findsOneWidget);
    await _tap(tester, find.text('Late-night pizza'));
    final (method, path, body) = _queued(tester).last;
    expect((method, path, body!['expense_id']), ('PUT', '/api/v1/personal/transactions/$id', pizza));
    expect(find.text('Card spend'), findsNothing); // looked at now, and dated before Recent's five
  });

  testWidgets('a split that is already linked is not offered again, nor one too far apart', (tester) async {
    final be = await pumpApp(tester, location: '/personal');
    be.offline = true;
    final store = await appContainer(tester).read(localStoreProvider.future);
    final near = await _entry(tester, amount: 62000, day: DateTime.utc(2026, 9, 22)); // the linked Uber's amount
    final far = await _entry(tester, amount: 114000, day: DateTime.utc(2026, 9, 25)); // pizza was the 17th
    final close = await _entry(tester, amount: 114000, day: DateTime.utc(2026, 9, 20));
    expect(store.ledger.linkCandidates(near), isEmpty);
    expect(store.ledger.linkCandidates(far), isEmpty);
    expect([for (final e in store.ledger.linkCandidates(close)) e['id']], [pizza]);
  });

  testWidgets('From a friend: a UPI payment in becomes a settle-up, linked to the entry', (tester) async {
    final be = await pumpApp(tester, location: '/personal');
    be.offline = true;
    final id = await _entry(
      tester,
      amount: 147000,
      day: DateTime.utc(2026, 9, 24),
      merchant: 'VIVEK IYER',
      reviewed: false,
      type: PersonalTxnInTypeEnum.income,
    );
    final card = find.ancestor(of: find.text('VIVEK IYER'), matching: find.byType(SkCard)).first;
    await _tap(tester, find.descendant(of: card, matching: find.text('From a friend')));
    // Only friends who owe you (by the groups' fewest payments), the one the bank named first.
    final options = tester.widgetList<SheetPersonOption>(find.byType(SheetPersonOption)).toList();
    expect([for (final o in options) o.label], ['Vivek Iyer · owes you ₹1,470']);
    await _tap(tester, find.byType(SheetPersonOption).first);
    expect(find.text('Settle up with Vivek'), findsOneWidget);
    await _tap(tester, find.text('Record ₹1,470 payment'));
    final ops = _queued(tester);
    final payment = ops.firstWhere((o) => o.$2.endsWith('/settlements'));
    final link = ops.last;
    expect((link.$1, link.$2, link.$3!['settlement_id']), ('PUT', '/api/v1/personal/transactions/$id', payment.$3!['id']));
    // Looked at, so it has left "Just in".
    expect(find.descendant(of: find.byType(JustIn), matching: find.text('VIVEK IYER')), findsNothing);
  });

  testWidgets('a linked entry says what it became, and Unlink undoes it', (tester) async {
    final be = await pumpApp(tester, location: '/personal/transactions');
    be.offline = true;
    expect(find.text('Transport · Split, not counted'), findsOneWidget); // Uber to airport
    await _tap(tester, find.text('Uber to airport'));
    expect(find.text('Split in Goa Trip'), findsOneWidget);
    expect(find.text('Open split'), findsOneWidget);
    await _tap(tester, find.text('Unlink'));
    final (method, _, body) = _queued(tester).single;
    expect((method, body!.containsKey('expense_id'), body['expense_id']), ('PUT', true, null));
    expect(find.text('Split it'), findsOneWidget);
  });

  testWidgets('the split shows you, only you, which account paid', (tester) async {
    await pumpApp(tester, location: '/expenses/$uberSplit');
    expect(find.text('From your HDFC ··4821'), findsOneWidget);
    await pumpApp(
      tester,
      location: '/expenses/$uberSplit',
      overrides: [integrationsProvider.overrideWithValue(const Integrations(personalNoteOnSplit: false))],
    );
    expect(find.text('From your HDFC ··4821'), findsNothing);
  });

  testWidgets('with the integrations off, Personal offers nothing in Split', (tester) async {
    const off = Integrations(splitFromTransaction: false, linkToExistingSplit: false, paymentFromTransaction: false);
    final be = await pumpApp(
      tester,
      location: '/personal',
      size: tall,
      overrides: [integrationsProvider.overrideWithValue(off)],
    );
    be.offline = true;
    expect(find.text('Just in'), findsOneWidget);
    expect(find.text('Split it'), findsNothing);
    expect(find.text('Looks right'), findsOneWidget);
    await _entry(tester, amount: 75000, day: DateTime.utc(2026, 9, 24), merchant: 'KABIR MEHTA');
    await _tap(tester, find.text('KABIR MEHTA').first);
    expect(find.text('In Split'), findsNothing);
    expect(find.text('Paid a friend'), findsNothing);
  });
}
