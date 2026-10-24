import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/api/api.dart';
import 'package:app/core/local/providers.dart';
import 'package:app/core/local/writes.dart';

import '../fake_backend.dart';
import '../helpers.dart';

/// The recovery actions from validation.md, on the Profile page's "This device" card.
void main() {
  setUpAll(loadFonts);

  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('reload from the server keeps unsynced changes; copy puts them on the clipboard', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
      return null;
    });
    final be = await pumpApp(tester, location: '/profile');
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

    // Make a change offline, so there is something unsynced.
    be.offline = true;
    final write = container
        .read(writesProvider)
        .createPersonal(
          PersonalTxnIn(type: PersonalTxnInTypeEnum.expense, amountMinor: 900, description: 'Kept', date: DateTime.utc(2026, 9, 25), source_: PersonalTxnInSource_Enum.manual),
        );
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await write;
    await tester.pumpAndSettle();
    await scrollTo(tester, 'Copy unsynced changes');
    expect(find.text('1 change waiting'), findsOneWidget);

    await tester.tap(find.text('Copy unsynced changes'));
    await tester.pumpAndSettle();
    final copied = jsonDecode(clipboard!) as List;
    expect((copied.single as Map)['label'], 'Added Kept · ₹9');

    // Reload from the server: every stream comes back from a snapshot; the change stays.
    be.offline = false;
    final before = be.syncCalls;
    be.postResponses['/api/v1/personal/transactions'] = (503, {'error': {'code': 'down', 'message': 'Try later'}});
    await tester.tap(find.text('Reload from the server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reload'));
    await tester.pumpAndSettle();
    expect(be.syncCalls, greaterThan(before));
    final store = await container.read(localStoreProvider.future);
    expect(store.cursors.keys.toSet(), be.snapshots.keys.toSet());
    expect(container.read(outboxProvider).single.label, 'Added Kept · ₹9');
    expect(store.ledger.personalList()['items'].any((t) => t['description'] == 'Kept'), isTrue);
  });

  testWidgets('logging out warns when changes would be lost', (tester) async {
    final be = await pumpApp(tester, location: '/profile');
    be.offline = true;
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    final write = container
        .read(writesProvider)
        .createPersonal(
          PersonalTxnIn(type: PersonalTxnInTypeEnum.expense, amountMinor: 900, description: 'Kept', date: DateTime.utc(2026, 9, 25), source_: PersonalTxnInSource_Enum.manual),
        );
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await write;
    await scrollTo(tester, 'Log out');
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.textContaining("1 change(s) on this device haven't reached the server"), findsOneWidget);
  });
}
