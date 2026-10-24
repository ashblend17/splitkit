import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/design_system/design_system.dart';

import '../fake_backend.dart';
import '../helpers.dart';

/// Adds [n] spends this month (the tests run on 25 Sep 2026) to the synced copy, "Bulk 0" the
/// newest: 80 a day, going back a day every 80.
FakeBackend _withEntries(int n) {
  final be = FakeBackend();
  final stream = be.snapshots.keys.firstWhere((s) => s.startsWith('user:'));
  final entities = (be.snapshots[stream] as Map)['entities'] as List;
  final template = entities.firstWhere((e) => e['entity'] == 'personal_transaction') as Map;
  for (var i = 0; i < n; i++) {
    final id = '00000000-0000-4000-9000-${i.toString().padLeft(12, '0')}';
    final day = DateTime.utc(2026, 9, 25).subtract(Duration(days: i ~/ 80));
    final made = DateTime.utc(day.year, day.month, day.day, 23).subtract(Duration(seconds: i));
    entities.add({
      ...template,
      'entity_id': id,
      'data': {
        ...(template['data'] as Map),
        'id': id,
        'type': 'expense',
        'description': 'Bulk $i',
        'amount_minor': 1000,
        'date': made.toIso8601String().substring(0, 10),
        'created_at': made.toIso8601String(),
        'category_id': null,
        'account': null,
        'merchant': null,
        'channel': null,
        'reference': null,
        'balance_minor': null,
        'sms_at': null,
        'source': 'manual',
        'reviewed': true,
        'expense_id': null,
        'settlement_id': null,
        'deleted_at': null,
      },
    });
  }
  return be;
}

/// Entry rows built, on screen or just past it.
int _built() => find
    .byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('personal-txn:'),
    )
    .evaluate()
    .length;

final _page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

void main() {
  setUpAll(loadFonts);

  testWidgets('a long month builds only the rows on screen, and the rest as you scroll', (tester) async {
    await pumpApp(tester, backend: _withEntries(2000), location: '/personal/transactions');
    expect(find.text('Bulk 0'), findsOneWidget);
    expect(_built(), inInclusiveRange(5, 40), reason: 'a screenful, not 2,000 (nor the first page of 100)');

    // One long drag, no flings: pages of 100 arrive on the way.
    for (final target in ['Bulk 150', 'Bulk 420']) {
      await tester.scrollUntilVisible(find.text(target), 300, scrollable: _page, maxScrolls: 200, continuous: true);
      expect(find.text(target), findsOneWidget);
      expect(_built(), inInclusiveRange(5, 40));
    }
  });

  testWidgets('the end of the list says how much is shown until it is all there', (tester) async {
    await pumpApp(tester, backend: _withEntries(120), location: '/personal/transactions');
    // 120 here and the seed's 21 this month.
    expect(find.text('Showing the newest 100 of 141.', skipOffstage: false), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Bulk 119'), 300, scrollable: _page, maxScrolls: 200, continuous: true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Showing the newest', skipOffstage: false), findsNothing, reason: 'all 141 are loaded');
  });

  for (final (name, size) in [('a desktop', Size(1440, 900)), ('a tablet', Size(900, 1100))]) {
    testWidgets('on $name the rows line up with the totals above them', (tester) async {
      await pumpApp(tester, backend: _withEntries(50), location: '/personal/transactions', size: size);
      final totals = tester.getRect(find.ancestor(of: find.text('Per day'), matching: find.byType(SkCard)));
      final row = tester.getRect(find.byKey(const ValueKey('personal-txn:00000000-0000-4000-9000-000000000000')));
      expect((row.left, row.width), (totals.left, totals.width));
      expect(tester.takeException(), isNull);
    });
  }
}
