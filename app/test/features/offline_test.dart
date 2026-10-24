import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/data/providers.dart';
import 'package:app/core/local/providers.dart';
import 'package:app/core/local/writes.dart';

import '../fake_backend.dart';

void main() {
  testWidgets('offline: screens keep the device copy and say so', (tester) async {
    final be = await pumpApp(tester);
    expect(find.text('₹1,470'), findsWidgets);
    expect(find.textContaining("You're offline"), findsNothing);

    be.offline = true;
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    refreshLedger(container.invalidate);
    await tester.pumpAndSettle();

    expect(find.text("You're offline. Showing what's on this device."), findsOneWidget);
    expect(find.text('₹1,470'), findsWidgets);
    expect(find.text('Dinner at Thalassa'), findsOneWidget);

    // Opening a group still works from the device.
    await tester.tap(find.text('Groups').last);
    await tester.pumpAndSettle();
    expect(find.text('Goa Trip'), findsWidgets);

    be.offline = false;
    refreshLedger(container.invalidate);
    await tester.pumpAndSettle();
    expect(find.textContaining("You're offline"), findsNothing);
  });

  testWidgets('back online is noticed within a third of the sync interval', (tester) async {
    final be = await pumpApp(tester, syncInterval: const Duration(seconds: 45));
    be.offline = true;
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    refreshLedger(container.invalidate);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("You're offline. Showing what's on this device."), findsOneWidget);

    be.offline = false;
    await tester.pump(const Duration(seconds: 16)); // well before the next 45 s sync
    await tester.pump();
    expect(find.textContaining("You're offline"), findsNothing);

    await tester.pumpWidget(const SizedBox()); // stop the sync timer
    container.dispose();
  });

  testWidgets('full-screen pages say they are offline too', (tester) async {
    final be = await pumpApp(tester);
    be.offline = true;
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    refreshLedger(container.invalidate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dinner at Thalassa'));
    await tester.pumpAndSettle();
    expect(find.text('Your share is settled'), findsOneWidget, reason: 'the expense page is open');
    expect(find.text("You're offline. Showing what's on this device."), findsOneWidget);
  });

  testWidgets('offline: a transfer is one change, sent as one batch when back online', (tester) async {
    final be = await pumpApp(tester, location: '/personal');
    be.offline = true;
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    final accounts = container.read(localStoreProvider).value!.ledger.personalAccountList();
    String account(String name) => accounts.firstWhere((a) => a['name'] == name)['id'] as String;
    await runWrite(
      tester,
      container.read(writesProvider).createTransfer(
        fromAccountId: account('HDFC ··4821'),
        toAccountId: account('Cash'),
        amountMinor: 150000,
        date: DateTime(2026, 9, 24),
        description: 'ATM on MG Road',
      ),
    );
    expect(find.text("You're offline. 1 change will sync when you're back."), findsOneWidget);
    final cash = container.read(localStoreProvider).value!.ledger.finance.balanceOf(account('Cash'))!;
    expect(cash.balanceMinor, 50000 + 200000 + 150000, reason: 'the opening, the seed\'s withdrawal and this one');
    expect(be.writes, isEmpty);

    be.offline = false;
    refreshLedger(container.invalidate);
    await tester.pumpAndSettle();
    final (method, path, body) = be.writes.single;
    expect((method, path), ('POST', '/api/v1/personal/batch'));
    expect([for (final i in body['items'] as List) (i['op'], i['transaction']['direction'])], [('create', 'out'), ('create', 'in')]);
    expect(find.textContaining("You're offline"), findsNothing);
  });

  testWidgets('restarting offline opens the saved sign-in from the device', (tester) async {
    final tokens = MemoryTokenStore('test-token');
    await pumpApp(tester, tokens: tokens, database: 'restart-offline');
    expect(find.text('₹1,470'), findsWidgets);

    await pumpApp(tester, tokens: tokens, database: 'restart-offline', backend: FakeBackend()..offline = true);
    expect(find.text('Hi, John'), findsOneWidget);
    expect(find.text('₹1,470'), findsWidgets);
    expect(find.text("You're offline. Showing what's on this device."), findsOneWidget);
  });

  testWidgets('opening the app online swaps the token for a fresh one', (tester) async {
    final tokens = MemoryTokenStore('old-token');
    await pumpApp(tester, tokens: tokens, backend: FakeBackend()..refreshTo = 'fresh-token');
    expect(tokens.token, 'fresh-token');
    expect(find.text('₹1,470'), findsWidgets);
  });
}
