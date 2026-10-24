import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/api/api.dart';
import 'package:app/core/data/providers.dart';
import 'package:app/core/layout/layout.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/common/common.dart';
import 'package:app/features/expenses/add_expense_page.dart';
import 'package:app/features/groups/group_detail_page.dart';
import 'package:app/features/shell/sync_banner.dart';

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
    expect(find.text('owes you ₹1,470'), findsOneWidget); // Vivek, by the groups' fewest payments
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
    expect(find.text("You don't owe anyone"), findsOneWidget);
    expect(find.text('by Vivek'), findsOneWidget);
    expect(find.text('YOUR BALANCE'), findsOneWidget);
    expect(find.text('you owe Rahul'), findsNothing); // Dinner at Thalassa: you pay nobody in Goa Trip
    expect(find.text('Settle'), findsNothing); // only beside friends you pay
    expect(find.text('+₹1,150'), findsOneWidget); // Goa Trip in the groups card
  });

  testWidgets('desktop filters and search narrow the activity table', (tester) async {
    await pumpApp(tester, size: desktop);
    expect(find.text('Electricity bill'), findsOneWidget);

    await tester.tap(find.text('Unsettled only'));
    await tester.pumpAndSettle();
    // Both groups' fewest payments have you paying nobody: others' bills are settled, and
    // what you paid for others is still open.
    expect(find.text('Electricity bill'), findsNothing);
    expect(find.text('Dinner at Thalassa'), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text('Any category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('Late-night pizza'), findsOneWidget);
    await tester.tap(find.text('Unsettled only'));
    await tester.pumpAndSettle();
    expect(find.text('Dinner at Thalassa'), findsOneWidget);

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

  testWidgets('desktop group: breadcrumb, table and your payments to settle up', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, size: desktop, location: '/groups/${be.goa['id']}');
    expect(find.text('Groups'), findsWidgets); // sidebar and breadcrumb
    expect(find.text(' / Goa Trip'), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Balances'), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('In Goa Trip, you are owed'), findsOneWidget);
    expect(find.text('To settle up'), findsOneWidget);
    expect(find.text('Pays you ₹1,150'), findsOneWidget); // Vivek, from the fewest payments
    expect(find.widgetWithText(SkButton, 'Settle'), findsNothing);
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    expect(find.text('Add member'), findsOneWidget);
    expect(find.text('To settle up'), findsOneWidget); // the side panel stays
  });

  testWidgets("desktop group: every tab keeps the group's header, tabs, side panel and width", (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, size: desktop, location: '/groups/${be.goa['id']}');
    final left = tester.getTopLeft(find.text('Expenses')).dx;
    final right = tester.getTopRight(find.text('Add expense')).dx;
    for (final (tab, shows) in [
      ('Analytics', 'Peak ₹19,160 on 12 Sep'),
      ('Balances', 'ONE-TO-ONE BALANCES'),
      ('Members', 'Add member'),
      ('Expenses', 'Dinner at Thalassa'),
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text(shows), findsWidgets, reason: tab);
      expect(find.byType(WebSidebar), findsOneWidget, reason: tab);
      expect(find.text(' / Goa Trip'), findsOneWidget, reason: tab);
      expect(tester.getTopLeft(find.text('Expenses')).dx, left, reason: '$tab: the tabs stay put');
      expect(tester.getTopRight(find.text('Add expense')).dx, right, reason: '$tab: the full width');
      for (final t in ['Expenses', 'Balances', 'Analytics', 'Members']) {
        expect(find.text(t), findsOneWidget, reason: '$tab shows the $t tab');
      }
      expect(find.text('To settle up'), findsOneWidget, reason: tab);
    }
    final router = GoRouter.of(tester.element(find.text('Expenses')));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/groups/${be.goa['id']}');
  });
}
