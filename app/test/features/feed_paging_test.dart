import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/expenses/activity_table.dart';

import '../fake_backend.dart';
import '../helpers.dart';

/// Adds [n] old expenses ("Old 0" is the newest of them) to Goa Trip's synced copy.
void _addOldExpenses(FakeBackend be, int n) {
  final entities = (be.snapshots['group:${be.goa['id']}'] as Map)['entities'] as List;
  final template = entities.firstWhere((e) => e['entity'] == 'expense') as Map;
  for (var i = 0; i < n; i++) {
    final id = '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';
    final day = DateTime.utc(2026, 8, 1).subtract(Duration(days: i));
    entities.add({
      ...template,
      'entity_id': id,
      'data': {
        ...(template['data'] as Map),
        'id': id,
        'description': 'Old $i',
        'date': '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
      },
    });
  }
}

/// The page's own vertical list (not the tabs or avatar rows).
final _page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

/// Feed cards (phone and tablet) and activity table rows (desktop) that are built, on screen or not.
int _rowsBuilt() =>
    find.byType(TransactionCard, skipOffstage: false).evaluate().length +
    find
        .descendant(of: find.byType(ActivityTable), matching: find.byType(InkWell), skipOffstage: false)
        .evaluate()
        .length;

const _tablet = Size(834, 1112);
const _desktop = Size(1440, 900);

/// The desktop activity table's own list.
final _table = find.descendant(of: find.byType(ActivityTable), matching: find.byType(Scrollable)).first;

void main() {
  setUpAll(loadFonts);

  testWidgets('a long group shows 100 at first and the rest on "Show older"', (tester) async {
    final be = FakeBackend();
    _addOldExpenses(be, 120);
    await pumpApp(tester, backend: be, location: '/groups/${be.goa['id']}');
    final list = _page;
    await tester.scrollUntilVisible(find.text('Show older'), 2000, scrollable: list);
    expect(find.text('Old 119'), findsNothing, reason: 'past the first page');

    await tester.drag(list, const Offset(0, -400)); // to the end, clear of the Add split button
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show older'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Old 119'), 2000, scrollable: list);
    expect(find.text('Old 119'), findsOneWidget);
    expect(find.text('Show older'), findsNothing, reason: 'everything is shown now');
  });

  testWidgets('a long group builds only the cards on screen', (tester) async {
    final be = FakeBackend();
    _addOldExpenses(be, 120);
    await pumpApp(tester, backend: be, location: '/groups/${be.goa['id']}');
    expect(find.byType(TransactionCard, skipOffstage: false).evaluate().length, lessThan(20), reason: 'not 100');
    await tester.scrollUntilVisible(find.text('Old 60'), 300, scrollable: _page, maxScrolls: 200, continuous: true);
    expect(find.byType(TransactionCard, skipOffstage: false).evaluate().length, lessThan(20));
  });

  testWidgets('a short list has no "Show older"', (tester) async {
    await pumpApp(tester, location: '/groups/${FakeBackend().goa['id']}');
    await tester.scrollUntilVisible(find.text('Train to Goa'), 500, scrollable: _page);
    expect(find.text('Show older'), findsNothing);
  });

  // Tablet Home and the desktop activity tables build only the rows on screen too (ISS-083).

  testWidgets('tablet Home builds only the cards on screen, and shows older ones on "Show older"', (tester) async {
    final be = FakeBackend();
    _addOldExpenses(be, 220);
    await pumpApp(tester, backend: be, size: _tablet, location: '/home');
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget, reason: 'the balances column beside the activity');
    expect(_rowsBuilt(), inInclusiveRange(1, 25), reason: 'a screenful, not the 100 loaded');

    await tester.scrollUntilVisible(find.text('Show older'), 600, scrollable: _page, maxScrolls: 100);
    expect(_rowsBuilt(), lessThan(25));
    expect(find.text('Old 150'), findsNothing, reason: 'past the first page');
    await tester.tap(find.text('Show older'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Old 150'), 600, scrollable: _page, maxScrolls: 100);
    expect(_rowsBuilt(), lessThan(25));
  });

  testWidgets('tablet Home in a narrow window stacks the balances over the activity', (tester) async {
    final be = FakeBackend();
    _addOldExpenses(be, 120);
    await pumpApp(tester, backend: be, size: const Size(700, 1000), location: '/home');
    final friends = tester.getTopLeft(find.text('Friends'));
    final activity = tester.getTopLeft(find.text('Recent activity'));
    expect(activity.dy, greaterThan(friends.dy), reason: 'one column');
    expect(_rowsBuilt(), lessThan(25));
  });

  testWidgets('the desktop Home table builds only the rows on screen, and shows older ones on "Show older"', (
    tester,
  ) async {
    final be = FakeBackend();
    _addOldExpenses(be, 220);
    await pumpApp(tester, backend: be, size: _desktop, location: '/home');
    expect(find.byType(ActivityTable), findsOneWidget);
    expect(_rowsBuilt(), inInclusiveRange(1, 25), reason: 'a screenful, not the 100 loaded');

    await tester.scrollUntilVisible(find.text('Show older'), 600, scrollable: _table, maxScrolls: 100);
    expect(_rowsBuilt(), lessThan(25));
    await tester.tap(find.text('Show older'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Old 150'), 600, scrollable: _table, maxScrolls: 100);
    expect(_rowsBuilt(), lessThan(25));
  });

  testWidgets("a group's desktop table builds only the rows on screen", (tester) async {
    final be = FakeBackend();
    _addOldExpenses(be, 220);
    await pumpApp(tester, backend: be, size: _desktop, location: '/groups/${be.goa['id']}');
    expect(find.byType(ActivityTable), findsOneWidget);
    expect(_rowsBuilt(), inInclusiveRange(1, 25), reason: 'a screenful, not the 100 loaded');
    await tester.scrollUntilVisible(find.text('Old 80'), 600, scrollable: _table, maxScrolls: 100);
    expect(_rowsBuilt(), lessThan(25));
  });
}
