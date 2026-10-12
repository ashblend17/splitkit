import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/clock.dart';
import 'package:splitkit/design_system/design_system.dart';

import '../fake_backend.dart';
import '../helpers.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('Personal shows the month, income, left over and top categories', (tester) async {
    await pumpApp(tester, location: '/personal');
    expect(find.text('Only you see this'), findsOneWidget);
    expect(find.text('Spent in September'), findsOneWidget);
    expect(find.text('₹32,450'), findsOneWidget);
    expect(find.text('₹85,000'), findsOneWidget);
    expect(find.text('Left over'), findsOneWidget);
    expect(find.text('₹52,550'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    final swiggy = tester.widget<TransactionCard>(find.widgetWithText(TransactionCard, 'Swiggy order'));
    expect((swiggy.subtitle, swiggy.label, swiggy.amount, swiggy.scope), ('Food · UPI', 'spent', '₹486', TxnScope.personal));
  });

  testWidgets('a month with spending but no income is not "overspent"', (tester) async {
    final before = appClock;
    appClock = Clock.fixed(DateTime(2026, 10, 3, 12));
    addTearDown(() => appClock = before);
    final be = FakeBackend();
    be.postResponses['/api/v1/personal/transactions'] = (201, (fixture('personal_list') as Map)['items'][0]);
    await pumpApp(tester, backend: be, location: '/personal');
    expect(find.text('Spent in October'), findsOneWidget);
    await tester.tap(find.byType(AddSplitFab));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '250');
    await tester.enterText(find.byType(TextField).at(1), 'Books');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SelectableChip, 'Shopping'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.text('₹250'), findsWidgets);
    expect(find.text('Overspent'), findsNothing);
    expect(find.text('Left over'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('adding a personal expense sends the right body', (tester) async {
    final be = FakeBackend();
    be.postResponses['/api/v1/personal/transactions'] = (201, (fixture('personal_list') as Map)['items'][0]);
    await pumpApp(tester, backend: be, location: '/personal');
    await tester.tap(find.bySemanticsLabel('Add entry'));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '250');
    await tester.enterText(find.byType(TextField).at(1), 'Books');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SelectableChip, 'Shopping'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    final (method, path, body) = be.writes.single;
    expect((method, path), ('POST', '/api/v1/personal/transactions'));
    expect((body['type'], body['amount_minor'], body['description']), ('expense', 25000, 'Books'));
    expect(body['category_id'], isNotNull);
  });

  testWidgets('history filters by type and category on the device', (tester) async {
    await pumpApp(tester, location: '/personal/transactions');
    expect(find.bySemanticsLabel('Transactions'), findsWidgets); // the title and the tab
    expect(find.text('Expenses only'), findsOneWidget);
    expect(find.text('Rapido ride'), findsOneWidget);
    await tester.tap(find.text('Food').first);
    await tester.pumpAndSettle();
    expect(find.text('Swiggy order'), findsOneWidget);
    expect(find.text('Rapido ride'), findsNothing);
    expect(find.text('Blue Tokai coffee'), findsOneWidget);
  });

  testWidgets('profile is the account and settings, nothing from either mode', (tester) async {
    await pumpApp(tester, location: '/profile');
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.textContaining('Member since'), findsOneWidget);
    expect(find.text('Import from Tricount'), findsOneWidget);
    expect(find.text('Soon'), findsNothing); // the importer is live (features/import_tricount)
    // This month's spending lives in Personal, balances in Split.
    expect(find.text('Personal spending'), findsNothing);
    expect(find.text('You owe'), findsNothing);
  });

  testWidgets("Profile's old History and Analytics links open Personal's tabs", (tester) async {
    await pumpApp(tester, location: '/profile/history');
    expect(find.text('Expenses only'), findsOneWidget);
    expect(tester.widget<BottomNav>(find.byType(BottomNav)).current, 'transactions');
    await pumpApp(tester, location: '/profile/analytics');
    expect(find.text('Spending over time'), findsOneWidget);
    expect(tester.widget<BottomNav>(find.byType(BottomNav)).current, 'insights');
  });

  testWidgets('personal analytics renders every configured card by type', (tester) async {
    await pumpApp(tester, location: '/personal/insights');
    expect(find.text('Spending over time'), findsOneWidget);
    expect(find.byType(TrendBars), findsOneWidget);
    expect(find.text('₹32.5k'), findsOneWidget); // top of the highlighted bar
    await tester.scrollUntilVisible(find.text('Average per day'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byType(BreakdownBars), findsOneWidget);
    expect(find.byType(SplitBar), findsOneWidget);
    expect(find.byType(StatBlock), findsOneWidget);
    expect(find.text('August averaged ₹993 per day'), findsOneWidget);
  });

  testWidgets('group analytics and editing the layout', (tester) async {
    final be = FakeBackend();
    be.postResponses['/api/v1/analytics/layout/personal'] = (200, fixture('analytics_layout'));
    await pumpApp(tester, backend: be, location: '/groups/${be.goa['id']}/analytics');
    expect(find.text('Goa Trip analytics'), findsOneWidget);
    expect(find.text('12 – 23 Sep · 6 members'), findsOneWidget);
    expect(find.text('Peak ₹19,160 on 12 Sep'), findsOneWidget);
    expect(find.text('₹8,043 per person · your share ₹10,830'), findsOneWidget);

    await pumpApp(tester, backend: be, location: '/personal/insights');
    await tester.tap(find.text('Edit layout'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Remove Personal vs group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save layout'));
    await tester.pumpAndSettle();
    final (method, path, body) = be.writes.single;
    expect((method, path), ('PUT', '/api/v1/analytics/layout/personal'));
    expect([for (final c in body['cards'] as List) (c as Map)['type']], ['spending_trend', 'spending_by_category', 'average_daily']);
  });

  testWidgets('a card type the app does not know shows the placeholder', (tester) async {
    final be = FakeBackend();
    final dash = Map<String, dynamic>.from(fixture('analytics_personal') as Map);
    dash['cards'] = [
      {...(dash['cards'] as List).first as Map, 'type': 'savings_goal', 'title': 'Savings goal'},
    ];
    be.get['/api/v1/analytics/personal'] = dash;
    await pumpApp(tester, backend: be, location: '/personal/insights');
    expect(find.text('Savings goal'), findsOneWidget);
    expect(find.text('renderer for savings_goal'), findsOneWidget);
  });
}
