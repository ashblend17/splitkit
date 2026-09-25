import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/layout/layout.dart';
import 'package:splitkit/design_system/design_system.dart';
import 'package:splitkit/features/expenses/add_expense_page.dart';

import '../fake_backend.dart';
import '../helpers.dart';

const tablet = Size(834, 1112);
const desktop = Size(1440, 900);

void main() {
  setUpAll(loadFonts);

  test('size classes follow the handoff breakpoints', () {
    expect(
      [for (final w in <double>[390, 599, 600, 1279, 1280, 1920]) SkLayout.forWidth(w)],
      [SkLayout.compact, SkLayout.compact, SkLayout.medium, SkLayout.medium, SkLayout.expanded, SkLayout.expanded],
    );
  });

  testWidgets('phones get the tab bar and the floating Add split', (tester) async {
    await pumpApp(tester);
    expect(find.byType(BottomNav), findsOneWidget);
    expect(find.byType(NavRail), findsNothing);
    expect(find.byType(AddSplitFab), findsOneWidget);
  });

  testWidgets('tablet: rail, balance and friends beside the activity', (tester) async {
    await pumpApp(tester, size: tablet);
    expect(find.byType(NavRail), findsOneWidget);
    expect(find.byType(BottomNav), findsNothing);
    expect(find.byType(AddSplitFab), findsNothing);
    expect(tester.widget<BalanceCard>(find.byType(BalanceCard)).layout, BalanceCardLayout.stacked);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('you owe ₹750'), findsOneWidget); // Kabir
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.widgetWithText(TransactionCard, 'Dinner at Thalassa'), findsOneWidget);
  });

  testWidgets('the rail switches tabs and adds to the open group', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, size: tablet, location: '/groups/${be.goa['id']}');
    await tester.tap(
      find.descendant(
        of: find.byType(NavRail),
        matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Add split'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<AddExpensePage>(find.byType(AddExpensePage)).groupId, be.goa['id']);
    Navigator.of(tester.element(find.byType(AddExpensePage))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavRail), matching: find.text('Personal')));
    await tester.pumpAndSettle();
    expect(find.text('Only you see this'), findsOneWidget);
  });

  testWidgets('desktop Home: sidebar, balance tiles, table and friends', (tester) async {
    await pumpApp(tester, size: desktop);
    expect(find.byType(WebSidebar), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.byType(AddSplitFab), findsNothing);
    expect(find.text('Overall, you are owed'), findsOneWidget);
    expect(find.text('to Kabir and Rahul'), findsOneWidget);
    expect(find.text('by Priya and Aman'), findsOneWidget);
    expect(find.text('YOUR BALANCE'), findsOneWidget);
    expect(find.text('you owe Rahul'), findsOneWidget); // Dinner at Thalassa
    expect(find.text('Settle'), findsNWidgets(2)); // Kabir and Rahul
    expect(find.text('+₹1,150'), findsOneWidget); // Goa Trip in the groups card
  });

  testWidgets('desktop filters and search go to the feed query', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, size: desktop);
    Map<String, String> lastFeed() => be.gets.lastWhere((u) => u.path == '/api/v1/feed').queryParameters;

    await tester.tap(find.text('Unsettled only'));
    await tester.pumpAndSettle();
    expect(lastFeed()['unsettled'], 'true');

    await tester.tap(find.text('Any category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    expect(lastFeed()['category'], 'food');

    await tester.tap(find.text('Any time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This month').last);
    await tester.pumpAndSettle();
    expect(lastFeed()['start'], isNotNull);

    await tester.enterText(find.byType(TextField), 'thal');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(lastFeed()['q'], 'thal');
    expect(lastFeed()['unsettled'], 'true'); // filters stay while searching
  });

  testWidgets('desktop table drops columns rather than overflowing at 1280px', (tester) async {
    await pumpApp(tester, size: const Size(1280, 800));
    expect(find.text('YOUR BALANCE'), findsOneWidget);
    expect(find.text('SPLIT'), findsNothing);
    await pumpApp(tester, size: const Size(1920, 1080));
    expect(find.text('SPLIT'), findsOneWidget);
    expect(find.text('YOUR SHARE'), findsOneWidget);
  });

  testWidgets('desktop group: breadcrumb, table and your balances', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, size: desktop, location: '/groups/${be.goa['id']}');
    expect(find.text('Groups'), findsWidgets); // sidebar and breadcrumb
    expect(find.text(' / Goa Trip'), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Settlements'), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('In Goa Trip, you are owed'), findsOneWidget);
    expect(find.text('Your balances'), findsOneWidget);
    expect(find.widgetWithText(SkButton, 'Settle'), findsNWidgets(2));
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    expect(find.text('Add member'), findsOneWidget);
    expect(find.text('Your balances'), findsOneWidget); // the side panel stays
  });
}
