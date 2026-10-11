import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/design_system/design_system.dart';

import '../fake_backend.dart';
import '../helpers.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('signed out: login shows the server message on bad credentials', (tester) async {
    final be = FakeBackend()
      ..postResponses['/api/v1/auth/login'] = (
        401,
        {'error': {'code': 'bad_credentials', 'message': "That email and password don't match"}},
      );
    await pumpApp(tester, token: null, backend: be);
    expect(find.text('Spend together.\nSettle simply.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'admin@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrong-password');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text("That email and password don't match"), findsOneWidget);
    expect(be.writes.single.$3, {'email': 'admin@example.com', 'password': 'wrong-password'});
  });

  testWidgets('logging in lands on Home with balances and activity', (tester) async {
    final be = FakeBackend();
    be.postResponses['/api/v1/auth/login'] = (200, {...fixture('login'), 'access_token': 't'});
    await pumpApp(tester, token: null, backend: be);
    await tester.enterText(find.byType(TextField).at(0), 'admin@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'dev-password');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Hi, John'), findsOneWidget);
    expect(find.text('Overall, you are owed'), findsOneWidget);
    expect(find.text('₹1,470'), findsOneWidget);
    expect(find.text('Kabir'), findsOneWidget);
    expect(find.text('you owe ₹750'), findsOneWidget);
    expect(find.text('Dinner at Thalassa'), findsOneWidget);
    expect(find.text('Rahul paid ₹1,800 · split 4 ways'), findsOneWidget);
  });

  testWidgets('Home cards use the money language, including settled shares', (tester) async {
    await pumpApp(tester);
    final dinner = tester.widget<TransactionCard>(find.widgetWithText(TransactionCard, 'Dinner at Thalassa'));
    expect((dinner.label, dinner.amount), ('you owe', '₹450'));
    await tester.scrollUntilVisible(find.text('Electricity bill'), 200, scrollable: find.byType(Scrollable).first);
    final bill = tester.widget<TransactionCard>(find.widgetWithText(TransactionCard, 'Electricity bill'));
    expect((bill.label, bill.amount, bill.tone.name), ('your share', '₹800', 'settled'));
    final paid = tester.widget<TransactionCard>(find.widgetWithText(TransactionCard, 'You paid Rahul'));
    expect((paid.subtitle, paid.label), ('Settlement · UPI', 'payment'));
  });

  testWidgets('deep link to group balances', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, location: '/groups/${be.goa['id']}/balances');
    expect(find.text('In this group, overall you are owed'), findsOneWidget);
    expect(find.text('You owe ₹750'), findsOneWidget);
    expect(find.text('Owes you ₹1,550'), findsOneWidget);
    expect(find.text('All square'), findsOneWidget);
    expect(find.text('Settle'), findsNWidgets(2));
    expect(find.text('Record payment'), findsNWidgets(2));
  });

  testWidgets('expense detail shows your part and each share', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, location: '/expenses/${be.dinnerId}');
    expect(find.text('Dinner at Thalassa'), findsOneWidget);
    expect(find.text('You owe Rahul'), findsOneWidget);
    expect(find.text('Split equally between 4'), findsOneWidget);
    expect(find.text('Owes'), findsNWidgets(3));
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Settle up'), findsOneWidget);
  });

  testWidgets('history says what changed in words, and Tricount edits say so', (tester) async {
    final be = FakeBackend();
    const tricount = {'id': '1a352678-7c38-5085-8131-bbcad6d0ae9d', 'name': 'Tricount', 'avatar_url': null, 'is_placeholder': true};
    be.get['/api/v1/expenses/${be.dinnerId}/history'] = [
      {
        'action': 'expense.update',
        'person': tricount,
        'admin': null,
        'at': '2026-09-24T10:00:00Z',
        'diff': {
          'amount_minor': {'from': 165000, 'to': 180000},
          'description': {'from': 'Dinner', 'to': 'Dinner at Thalassa'},
          'via': 'tricount',
        },
      },
      {
        // Older servers sent the new amount on its own.
        'action': 'expense.update',
        'person': tricount,
        'admin': null,
        'at': '2026-09-24T11:00:00Z',
        'diff': {'via': 'tricount', 'amount_minor': 180000},
      },
    ];
    await pumpApp(tester, backend: be, location: '/expenses/${be.dinnerId}');
    await tester.scrollUntilVisible(find.textContaining('Edited in Tricount').first, 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Edited in Tricount · amount ₹1,650 → ₹1,800, description'), findsOneWidget);
    expect(find.textContaining('Edited in Tricount · amount ·'), findsOneWidget);
    expect(find.textContaining('via'), findsNothing);
    expect(find.textContaining('amount_minor'), findsNothing);
  });

  testWidgets('settling up uses the balance currency, not the profile one', (tester) async {
    final be = FakeBackend();
    final me = ((fixture('login') as Map)['user'] as Map)['id'];
    for (final e in (be.snapshots['user:$me'] as Map)['entities'] as List) {
      if (e['entity'] == 'profile') e['data']['currency'] = 'USD'; // every group is in rupees
    }
    await pumpApp(tester, backend: be);

    await tester.dragUntilVisible(find.text('Aman'), find.byType(SingleChildScrollView).first, const Offset(-200, 0));
    await tester.tap(find.text('Aman'));
    await tester.pumpAndSettle();
    expect(find.text('Settle up with Aman'), findsOneWidget);
    expect(find.text('Full balance ₹1,170'), findsOneWidget);
  });

  testWidgets('settle up with a friend across groups', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be);

    await tester.dragUntilVisible(find.text('Aman'), find.byType(SingleChildScrollView).first, const Offset(-200, 0));
    await tester.tap(find.text('Aman'));
    await tester.pumpAndSettle();

    expect(find.text('Settle up with Aman'), findsOneWidget);
    expect(find.text('Full balance ₹1,170'), findsOneWidget);
    expect(find.text('After this, you and Aman are all square.'), findsOneWidget);
    expect(find.text('Recorded in 2 groups: Flatmates ₹320 · Goa Trip ₹850'), findsOneWidget);

    // A part payment pays down the oldest group first.
    await tester.tap(find.text('Part payment'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '500');
    await tester.pumpAndSettle();
    expect(find.text('Aman will still owe you ₹670.'), findsOneWidget);
    expect(find.text('Pays down the oldest group first: Flatmates ₹320 · Goa Trip ₹180'), findsOneWidget);

    await tester.tap(find.text('Record ₹500 payment'));
    await tester.pumpAndSettle();
    // Planned on the device, oldest group first, one payment per group (each with its own id,
    // so a retry can't record it twice).
    final groups = {for (final g in fixture('groups') as List) g['name']: g['id']};
    expect([for (final (m, p, _) in be.writes) (m, p)], [
      ('POST', '/api/v1/groups/${groups['Flatmates']}/settlements'),
      ('POST', '/api/v1/groups/${groups['Goa Trip']}/settlements'),
    ]);
    expect([for (final w in be.writes) (w.$3['from_user'], w.$3['amount_minor'], w.$3['method'])], [
      (be.amanId, 32000, 'upi'),
      (be.amanId, 18000, 'upi'),
    ]);
    expect(be.writes.every((w) => w.$3['id'] != null), isTrue);
    expect(find.text('Payment recorded in 2 groups'), findsOneWidget);
  });

  testWidgets('add split: amount, description, equal split, save', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, location: '/expenses/new?group=${be.goa['id']}');

    expect(find.text('Enter an amount'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '1800');
    await tester.enterText(find.byType(TextField).at(1), 'Dinner at Thalassa');
    await tester.pumpAndSettle();
    expect(find.text('Equally · 6 people'), findsOneWidget);
    expect(find.text('₹300 each'), findsOneWidget);
    expect(find.text('You will be owed'), findsOneWidget);
    expect(find.text('₹1,500'), findsOneWidget);

    await tester.tap(find.text('Food'));
    await tester.tap(find.text('Save split'));
    await tester.pumpAndSettle();
    final (method, path, body) = be.writes.single;
    expect((method, path), ('POST', '/api/v1/groups/${be.goa['id']}/expenses'));
    expect((body['amount_minor'], body['description'], (body['split'] as Map)['method']), (180000, 'Dinner at Thalassa', 'equal'));
    expect(((body['split'] as Map)['inputs'] as List).length, 6);
    expect(body['category_id'], isNotNull);
    expect(body['id'], isNotNull); // made on the device, so a retry can't add it twice
    // Lands on the saved expense, shown from the device before the server has confirmed it.
    expect(find.text('Dinner at Thalassa'), findsOneWidget);
    expect(find.text('Split equally between 6'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
  });
}
