import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('a short list has no "Show older"', (tester) async {
    await pumpApp(tester, location: '/groups/${FakeBackend().goa['id']}');
    await tester.scrollUntilVisible(find.text('Train to Goa'), 500, scrollable: _page);
    expect(find.text('Show older'), findsNothing);
  });
}
