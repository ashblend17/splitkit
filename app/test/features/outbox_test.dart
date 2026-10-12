import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/data/providers.dart';
import 'package:splitkit/core/local/outbox.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/local/writes.dart';

import '../fake_backend.dart';
import '../helpers.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

/// Runs a write started from the test body. Widget tests run on a fake clock and the local
/// database waits on timers, so keep pumping until it finishes.
Future<T> _run<T>(WidgetTester tester, Future<T> write) async {
  var done = false;
  Object? error;
  late T value;
  write.then(
    (v) {
      value = v;
      done = true;
    },
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  for (var i = 0; i < 200 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  if (!done) throw StateError('write did not finish');
  if (error != null) throw error!;
  await tester.pumpAndSettle();
  return value;
}

Future<void> _sync(WidgetTester tester) async {
  refreshLedger(_container(tester).invalidate);
  await tester.pumpAndSettle();
}

ExpenseIn _dinner(FakeBackend be, {String description = 'Dinner at Thalassa', int amount = 180000}) {
  final e = fixture('expense') as Map;
  return ExpenseIn(
    description: description,
    amountMinor: amount,
    payerId: (e['payer'] as Map)['id'],
    date: DateTime.utc(2026, 9, 23),
    split: SplitIn(
      method: 'equal',
      inputs: [for (final s in e['splits'] as List) SplitInputIn(userId: s['user']['id'])],
    ),
  );
}

void main() {
  setUpAll(loadFonts);

  testWidgets('offline: a new expense shows at once and is sent once when back online', (tester) async {
    final be = await pumpApp(tester, location: '/groups/${(fixture('groups') as List).first['id']}');
    be.offline = true;
    final writes = _container(tester).read(writesProvider);
    final goa = be.goa['id'] as String;
    await _run(tester, writes.createExpense(goa, _dinner(be, description: 'Offline snacks', amount: 60000)));
    await tester.pumpAndSettle();

    expect(find.text('Offline snacks'), findsOneWidget);
    expect(find.text("You're offline. 1 change will sync when you're back."), findsOneWidget);
    expect(be.writes, isEmpty);

    be.offline = false;
    await _sync(tester);
    expect(be.writes.length, 1);
    final (method, path, body) = be.writes.single;
    expect((method, path), ('POST', '/api/v1/groups/$goa/expenses'));
    expect(body['description'], 'Offline snacks');
    expect(body['id'], isNotNull);
    expect(find.textContaining("You're offline"), findsNothing);
    // Still shown until the server's copy arrives; nothing is sent twice.
    expect(find.text('Offline snacks'), findsOneWidget);
    await _sync(tester);
    expect(be.writes.length, 1);
  });

  testWidgets('a create that fails half-way is retried with the same id', (tester) async {
    final be = await pumpApp(tester);
    final goa = be.goa['id'] as String;
    be.postResponses['/api/v1/groups/$goa/expenses'] = (
      503,
      {
        'error': {'code': 'unavailable', 'message': 'Try later'},
      },
    );
    await _run(tester, _container(tester).read(writesProvider).createExpense(goa, _dinner(be, description: 'Retry me')));
    await tester.pumpAndSettle();
    be.postResponses.remove('/api/v1/groups/$goa/expenses');
    await _sync(tester);
    expect(be.writes.length, 2);
    expect(be.writes[0].$3['id'], be.writes[1].$3['id']);
    final ops = _container(tester).read(outboxProvider);
    expect(ops.single.status, OutboxStatus.sent);
  });

  testWidgets('a conflicting edit asks what to keep', (tester) async {
    final be = await pumpApp(tester);
    be.postResponses['/api/v1/expenses/${be.dinnerId}'] = (
      409,
      {
        'error': {
          'code': 'version_conflict',
          'message': 'Someone changed this while you were offline',
          'current_version': 2,
        },
      },
    );
    final writes = _container(tester).read(writesProvider);
    await _run(tester, writes.updateExpense(be.dinnerId, _dinner(be, description: 'Dinner (my edit)')));
    await tester.pumpAndSettle();
    expect(be.writes.single.$3['version'], 1);

    // Refused: back to the server's version, and a line to review it.
    expect(find.text('Dinner at Thalassa'), findsWidgets);
    expect(find.text('Dinner (my edit)'), findsNothing);
    expect(find.text("1 change couldn't be saved"), findsOneWidget);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Needs your attention'), findsOneWidget);
    expect(find.textContaining('Edited Dinner (my edit)'), findsOneWidget);
    expect(find.text('Someone changed this while you were offline'), findsOneWidget);

    // Keep mine: sent again on top of the server's current version.
    be.postResponses.remove('/api/v1/expenses/${be.dinnerId}');
    await tester.tap(find.text('Keep mine'));
    await tester.pumpAndSettle();
    expect(be.writes.length, 2);
    expect(be.writes.last.$2, '/api/v1/expenses/${be.dinnerId}');
    expect(find.text("1 change couldn't be saved"), findsNothing);
  });

  testWidgets('keep theirs drops the refused change', (tester) async {
    final be = await pumpApp(tester);
    be.postResponses['/api/v1/expenses/${be.dinnerId}'] = (
      409,
      {
        'error': {'code': 'version_conflict', 'message': 'Someone changed this while you were offline'},
      },
    );
    await _run(tester, _container(tester).read(writesProvider).updateExpense(be.dinnerId, _dinner(be, description: 'Mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep theirs'));
    await tester.pumpAndSettle();
    expect(_container(tester).read(outboxProvider), isEmpty);
    expect(find.text('All your changes are saved.'), findsOneWidget);
  });

  testWidgets('personal entries and deletes work offline too', (tester) async {
    final be = await pumpApp(tester, location: '/personal/transactions');
    be.offline = true;
    final writes = _container(tester).read(writesProvider);
    await _run(
      tester,
      writes.createPersonal(
        PersonalTxnIn(
          type: PersonalTxnInTypeEnum.expense,
          amountMinor: 25000,
          description: 'Offline books',
          date: DateTime.utc(2026, 9, 24),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Offline books'), findsOneWidget);

    final swiggy =
        (fixture('personal_list') as Map)['items'].firstWhere((t) => t['description'] == 'Swiggy order')['id']
            as String;
    await _run(tester, writes.deletePersonal(swiggy));
    await tester.pumpAndSettle();
    expect(find.text('Swiggy order'), findsNothing);
    expect(find.text("You're offline. 2 changes will sync when you're back."), findsOneWidget);

    be.offline = false;
    await _sync(tester);
    expect([for (final w in be.writes) w.$1], ['POST', 'DELETE']);
  });
}
