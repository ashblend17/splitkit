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
    // What you spent includes your share in groups (₹32,450 on your own + ₹18,210).
    expect(find.text('₹50,660'), findsOneWidget);
    expect(find.text('₹32,450'), findsOneWidget);
    expect(find.text('₹85,000'), findsOneWidget);
    expect(find.text('Left over'), findsOneWidget);
    expect(find.text('₹34,340'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
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
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.text('₹250'), findsWidgets);
    expect(find.text('Overspent'), findsNothing);
    expect(find.text('Left over'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2)); // left over, and saved
    expect(find.text('Saved'), findsOneWidget);
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
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    final (method, path, body) = be.writes.single;
    expect((method, path), ('POST', '/api/v1/personal/transactions'));
    expect((body['type'], body['amount_minor'], body['description']), ('expense', 25000, 'Books'));
    expect(body['category_id'], isNotNull);
  });

  testWidgets('a category is suggested as you type, and tapping it keeps it (ISS-001)', (tester) async {
    final be = FakeBackend();
    be.postResponses['/api/v1/personal/transactions'] = (201, (fixture('personal_list') as Map)['items'][0]);
    await pumpApp(tester, backend: be, location: '/personal');
    await tester.tap(find.byType(AddSplitFab));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '320');
    await tester.enterText(find.byType(TextField).at(1), 'zomatoo');
    await tester.pumpAndSettle();
    bool selected(String label) => tester.widget<SelectableChip>(find.widgetWithText(SelectableChip, label)).selected;
    expect(selected('Food'), isTrue);
    await tester.enterText(find.byType(TextField).at(1), 'ubar ride');
    await tester.pumpAndSettle();
    expect((selected('Food'), selected('Transport')), (false, true));
    await tester.tap(find.widgetWithText(SelectableChip, 'Transport')); // keeps it
    await tester.enterText(find.byType(TextField).at(1), 'ubar ride to dinner');
    await tester.pumpAndSettle();
    expect(selected('Transport'), isTrue); // chosen now, so it no longer follows the words
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    final transport = (fixture('personal_categories') as List).firstWhere((c) => c['key'] == 'transport')['id'];
    expect(be.writes.single.$3['category_id'], transport);
  });

  testWidgets('Add split suggests a category from the description too', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, location: '/expenses/new?group=${be.goa['id']}');
    await tester.enterText(find.byType(TextField).at(1), 'Petrol for the scooter');
    await tester.pumpAndSettle();
    expect(tester.widget<SelectableChip>(find.widgetWithText(SelectableChip, 'Transport')).selected, isTrue);
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
    expect(find.text('₹50.7k'), findsOneWidget); // top of the highlighted bar: your own and your group share
    await tester.scrollUntilVisible(find.text('Average per day'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byType(SplitBar), findsNWidgets(2)); // Personal vs group, Needs and wants
    expect(find.byType(StatBlock), findsNWidgets(2)); // Average per day, Savings rate
    expect(find.text('August averaged ₹1,191 per day'), findsOneWidget);
    // From what entries say: the account, how it was paid, who was paid.
    await tester.scrollUntilVisible(find.text('Top merchants'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('HDFC ··4821'), findsOneWidget);
    expect(find.text('Not said'), findsOneWidget);
    expect(find.text('Swiggy order'), findsOneWidget);
  });

  testWidgets('group analytics and editing the layout', (tester) async {
    final be = FakeBackend();
    be.postResponses['/api/v1/analytics/layout/personal'] = (200, fixture('analytics_layout'));
    await pumpApp(tester, backend: be, location: '/groups/${be.goa['id']}/analytics');
    // The Analytics tab of the group's page, under its header and the other tabs.
    expect(find.text('Goa Trip'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
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
    expect([for (final c in body['cards'] as List) (c as Map)['type']], [
      'spending_trend',
      'spending_by_category',
      'average_daily',
      'spending_by_account',
      'spending_by_channel',
      'top_merchants',
      'savings_rate',
      'need_vs_want',
    ]);
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

  /// The Savings rate and Needs and wants cards, alone on Insights, as [change] leaves them.
  Future<void> newCards(WidgetTester tester, [void Function(Map savings, Map needWant)? change]) async {
    final be = FakeBackend();
    final dash = Map<String, dynamic>.from(fixture('analytics_personal') as Map);
    final cards = [
      for (final c in dash['cards'] as List)
        if (const {'savings_rate', 'need_vs_want'}.contains((c as Map)['type'])) Map<String, dynamic>.from(c),
    ];
    change?.call(cards[0], cards[1]);
    dash['cards'] = cards;
    be.get['/api/v1/analytics/personal'] = dash;
    await pumpApp(tester, backend: be, location: '/personal/insights');
    expect(find.byType(AnalyticsPlaceholder), findsNothing);
  }

  testWidgets('Savings rate: the rate, and what was saved of what came in', (tester) async {
    await newCards(tester);
    expect(find.text('Savings rate'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget); // with your share of group spending
    expect(find.text('₹34,340 saved of ₹85,000 income'), findsOneWidget);

    // Spent more than came in: a typographic minus, whichever the server sent.
    await newCards(tester, (savings, _) => savings['headline'] = '-13%');
    expect(find.text('−13%'), findsOneWidget);
    await newCards(tester, (savings, _) {
      savings['headline'] = '—';
      savings['stat'] = {'value_minor': 0, 'note': 'No income in September'};
    });
    expect(find.text('—'), findsOneWidget);
    expect(find.text('No income in September'), findsOneWidget);
  });

  testWidgets('Needs and wants: both always, never below zero, and what isn\'t sorted', (tester) async {
    await newCards(tester);
    expect(find.text('Needs and wants'), findsOneWidget);
    expect(find.byType(SplitBar), findsOneWidget);
    expect(find.text('Needs · 76%'), findsOneWidget);
    expect(find.text('Wants · 24%'), findsOneWidget);
    expect(find.text('₹37,645'), findsOneWidget);
    expect(find.text('₹12,215'), findsOneWidget);
    expect(find.text('₹800 not sorted'), findsOneWidget); // a group expense under Other

    await newCards(tester, (_, needWant) {
      needWant['headline'] = 'ignored';
      needWant['rows'] = [
        {'label': 'Needs', 'value_minor': 2849100},
        {'label': 'Wants', 'value_minor': -50000},
        {'label': 'Not sorted', 'value_minor': 120000},
      ];
    });
    expect(find.text('Wants · 0%'), findsOneWidget);
    expect(find.text('₹0'), findsOneWidget);
    expect(find.text('₹1,200 not sorted'), findsOneWidget);
    expect(find.text('ignored'), findsNothing);
  });
}
