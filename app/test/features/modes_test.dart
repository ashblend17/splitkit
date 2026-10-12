import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/integrations.dart';
import 'package:splitkit/core/theme/theme.dart';
import 'package:splitkit/design_system/design_system.dart';
import 'package:splitkit/features/shell/app_mode.dart';

import '../fake_backend.dart';
import '../helpers.dart';

const tablet = Size(834, 1112);
const desktop = Size(1440, 900);

List<String> _tabs(WidgetTester tester) => [
  for (final d in tester.widget<BottomNav>(find.byType(BottomNav)).destinations) d.key,
];

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the switch swaps the tabs, the accent and the add button, and is saved', (tester) async {
    final modes = MemoryModeStore();
    await pumpApp(tester, modes: modes);
    expect(_tabs(tester), ['home', 'groups', 'profile', 'admin']);
    expect(tester.widget<BottomNav>(find.byType(BottomNav)).accent, NavAccent.brand);
    expect(tester.widget<AddSplitFab>(find.byType(AddSplitFab)).label, 'Add split');

    await _tap(tester, find.bySemanticsLabel('Personal mode'));
    expect(_tabs(tester), ['overview', 'transactions', 'insights', 'profile', 'admin']);
    expect(tester.widget<BottomNav>(find.byType(BottomNav)).accent, NavAccent.personal);
    final fab = tester.widget<AddSplitFab>(find.byType(AddSplitFab));
    expect((fab.label, fab.color), ('Add entry', SkColors.personal));
    expect(find.text('Only you see this'), findsOneWidget);
    expect(modes.mode, AppMode.personal);

    // Personal's add button adds a personal entry, not a split.
    await _tap(tester, find.byType(AddSplitFab));
    expect(find.text('Add expense'), findsOneWidget);
  });

  testWidgets('switching back returns to the tab you last used in that mode', (tester) async {
    await pumpApp(tester);
    await _tap(tester, find.bySemanticsLabel('Personal mode'));
    await _tap(tester, find.descendant(of: find.byType(BottomNav), matching: find.text('Insights')));
    expect(find.text('Spending over time'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Split mode'));
    await _tap(tester, find.descendant(of: find.byType(BottomNav), matching: find.text('Groups')));
    await _tap(tester, find.bySemanticsLabel('Personal mode'));
    expect(tester.widget<BottomNav>(find.byType(BottomNav)).current, 'insights');
    await _tap(tester, find.bySemanticsLabel('Split mode'));
    expect(tester.widget<BottomNav>(find.byType(BottomNav)).current, 'groups');
  });

  testWidgets('the app reopens in the mode it was left in', (tester) async {
    await pumpApp(tester, mode: AppMode.personal);
    expect(find.text('Only you see this'), findsOneWidget);
    expect(_tabs(tester).first, 'overview');
  });

  testWidgets("a link to one of Personal's tabs turns Personal on", (tester) async {
    final modes = MemoryModeStore();
    await pumpApp(tester, modes: modes, location: '/personal/insights');
    expect(_tabs(tester).first, 'overview');
    expect(tester.widget<BottomNav>(find.byType(BottomNav)).current, 'insights');
    expect(modes.mode, AppMode.personal);
  });

  testWidgets('Profile keeps whichever mode is on', (tester) async {
    await pumpApp(tester, mode: AppMode.personal);
    await _tap(tester, find.descendant(of: find.byType(BottomNav), matching: find.text('Profile')));
    expect(find.textContaining('Member since'), findsOneWidget);
    expect(_tabs(tester).first, 'overview');
    expect(find.bySemanticsLabel('Personal mode'), findsOneWidget);
  });

  testWidgets('the switch shows on tab roots only, not on pages opened from them', (tester) async {
    await pumpApp(tester, location: '/groups');
    expect(find.byType(ModeSwitch), findsOneWidget);
    await _tap(tester, find.text('Goa Trip').first);
    expect(find.text('Balances'), findsWidgets);
    expect(find.byType(ModeSwitch), findsNothing);
    await _tap(tester, find.bySemanticsLabel('Back to groups'));
    expect(find.byType(ModeSwitch), findsOneWidget);
  });

  testWidgets('tablet rail: the switch, and the add button follows the mode', (tester) async {
    await pumpApp(tester, size: tablet);
    final rail = find.byType(NavRail);
    expect(find.descendant(of: rail, matching: find.byType(ModeSwitch)), findsOneWidget);
    expect(tester.widget<NavRail>(rail).addLabel, 'Add split');
    await _tap(tester, find.descendant(of: rail, matching: find.text('Personal')));
    expect((tester.widget<NavRail>(rail).addLabel, tester.widget<NavRail>(rail).accent), ('Add entry', NavAccent.personal));
    expect(find.descendant(of: rail, matching: find.text('Transactions')), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Add entry'));
    expect(find.text('Add expense'), findsOneWidget);
  });

  testWidgets('screen readers reach the rail and sidebar, not just the page beside them', (tester) async {
    await pumpApp(tester, size: tablet);
    expect(find.bySemanticsLabel('Add split'), findsOneWidget);
    expect(find.bySemanticsLabel('Personal mode'), findsOneWidget);
    expect(find.bySemanticsLabel('Groups'), findsWidgets);
    await pumpApp(tester, size: desktop);
    expect(find.bySemanticsLabel('Add split'), findsOneWidget);
    expect(find.bySemanticsLabel('Personal mode'), findsOneWidget);
  });

  testWidgets('desktop sidebar: the switch and both sets of tabs', (tester) async {
    await pumpApp(tester, size: desktop, mode: AppMode.personal);
    final sidebar = find.byType(WebSidebar);
    expect(find.descendant(of: sidebar, matching: find.byType(ModeSwitch)), findsOneWidget);
    expect(find.descendant(of: sidebar, matching: find.text('Add entry')), findsOneWidget);
    await _tap(tester, find.descendant(of: sidebar, matching: find.text('Split')));
    expect(find.descendant(of: sidebar, matching: find.text('Add split')), findsOneWidget);
    expect(find.descendant(of: sidebar, matching: find.text('Groups')), findsOneWidget);
  });

  group('with groupShareInPersonal', () {
    testWidgets('on: Overview and Insights show your share of groups', (tester) async {
      await pumpApp(tester, location: '/personal');
      expect(find.text('Your share in groups'), findsOneWidget);
      expect(find.text('₹18,210'), findsOneWidget);
      await pumpApp(tester, location: '/personal/insights');
      await tester.scrollUntilVisible(find.text('Personal vs group'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.byType(SplitBar), findsOneWidget);
    });

    testWidgets('off: neither does', (tester) async {
      final off = [integrationsProvider.overrideWithValue(const Integrations(groupShareInPersonal: false))];
      await pumpApp(tester, location: '/personal', overrides: off);
      expect(find.text('Your share in groups'), findsNothing);
      await pumpApp(tester, location: '/personal/insights', overrides: off);
      await tester.scrollUntilVisible(find.text('Average per day'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Personal vs group'), findsNothing);
      expect(find.byType(SplitBar), findsNothing);
    });
  });
}
