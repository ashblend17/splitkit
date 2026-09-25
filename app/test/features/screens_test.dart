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

    await tester.enterText(find.byType(TextField).at(0), 'ansh.c@cyware.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrong-password');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text("That email and password don't match"), findsOneWidget);
    expect(be.writes.single.$3, {'email': 'ansh.c@cyware.com', 'password': 'wrong-password'});
  });

  testWidgets('logging in lands on Home with balances and activity', (tester) async {
    final be = FakeBackend();
    be.postResponses['/api/v1/auth/login'] = (200, {...fixture('login'), 'access_token': 't'});
    await pumpApp(tester, token: null, backend: be);
    await tester.enterText(find.byType(TextField).at(0), 'ansh.c@cyware.com');
    await tester.enterText(find.byType(TextField).at(1), 'splitkit-dev');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Ansh'), findsOneWidget);
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

  testWidgets('settle up with a friend across groups', (tester) async {
    final be = FakeBackend();
    be.postResponses['/api/v1/friends/${be.amanId}/settle-up'] = (201, {'settlements': <dynamic>[], 'remaining_net_minor': 0});
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
    final (method, path, body) = be.writes.single;
    expect((method, path), ('POST', '/api/v1/friends/${be.amanId}/settle-up'));
    expect((body['amount_minor'], body['method'], body['currency']), (50000, 'upi', 'INR'));
    expect(find.text('Payment recorded'), findsOneWidget);
  });

  testWidgets('add split: amount, description, equal split, save', (tester) async {
    final be = FakeBackend();
    be.postResponses['/api/v1/groups/${be.goa['id']}/expenses'] = (201, fixture('expense'));
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
    // Lands on the saved expense.
    expect(find.text('You owe Rahul'), findsOneWidget);
  });
}
