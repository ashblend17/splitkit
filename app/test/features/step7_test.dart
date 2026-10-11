import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/data/providers.dart';
import 'package:splitkit/core/layout/layout.dart';
import 'package:splitkit/design_system/design_system.dart';
import 'package:splitkit/features/common/common.dart';
import 'package:splitkit/features/expenses/add_expense_page.dart';
import 'package:splitkit/features/groups/group_detail_page.dart';
import 'package:splitkit/features/shell/sync_banner.dart';

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

  testWidgets('phones: a group floats Add split for itself, and snackbars sit above the button', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, location: '/groups/${be.goa['id']}');
    expect(find.byType(AddSplitFab), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Add expense to Goa Trip')), findsOneWidget);

    showMessage(tester.element(find.byType(GroupDetailPage)), 'Payment deleted', actionLabel: 'Undo', onAction: () {});
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(SnackBar)).bottom, lessThanOrEqualTo(tester.getRect(find.byType(AddSplitFab)).top));

    await tester.tap(find.byType(AddSplitFab));
    await tester.pumpAndSettle();
    expect(tester.widget<AddExpensePage>(find.byType(AddExpensePage)).groupId, be.goa['id']);
  });

  testWidgets('from tablet up a snackbar is a note, not a bar across the window', (tester) async {
    await pumpApp(tester, size: desktop);
    showMessage(tester.element(find.byType(WebSidebar)), 'Flatmates is back');
    await tester.pumpAndSettle();
    final note = find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first;
    expect(tester.getSize(note).width, snackBarWidth);
  });

  testWidgets('Home mentions balances in your other currencies, on every size', (tester) async {
    final b = Map<String, dynamic>.from(fixture('balances') as Map);
    b['totals'] = [
      ...b['totals'] as List,
      {'currency': 'USD', 'net_minor': 2500, 'you_owe_minor': 0, 'you_are_owed_minor': 2500},
      {'currency': 'EUR', 'net_minor': 0, 'you_owe_minor': 0, 'you_are_owed_minor': 0}, // settled: not mentioned
    ];
    final balances = OverallBalancesOut.fromJson(b)!;
    for (final size in [const Size(390, 844), tablet, desktop]) {
      await pumpApp(tester, size: size, overrides: [overallBalancesProvider.overrideWith((ref) async => balances)]);
      expect(find.text('Also: you are owed \$25 in USD groups'), findsOneWidget, reason: '$size');
    }
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

  testWidgets('desktop filters and search narrow the activity table', (tester) async {
    await pumpApp(tester, size: desktop);
    expect(find.text('Electricity bill'), findsOneWidget);

    await tester.tap(find.text('Unsettled only'));
    await tester.pumpAndSettle();
    expect(find.text('Electricity bill'), findsNothing); // you're square with the payer
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text('Any category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('Dinner at Thalassa'), findsOneWidget);
    expect(find.text('Late-night pizza'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'thal');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Dinner at Thalassa'), findsOneWidget);
    expect(find.text('Late-night pizza'), findsNothing);

    // Nothing matches → Clear empties the search box too, not just the filters.
    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Electricity bill'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear search')); // only the search was narrowing it
    await tester.pumpAndSettle();
    expect(find.text('Electricity bill'), findsOneWidget);
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
