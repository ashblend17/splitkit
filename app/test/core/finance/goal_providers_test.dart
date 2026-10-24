import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:app/core/api/api.dart';
import 'package:app/core/finance/goal_providers.dart';
import 'package:app/core/finance/today.dart';
import 'package:app/core/integrations.dart';
import 'package:app/core/local/ledger.dart';
import 'package:app/core/local/outbox.dart';
import 'package:app/core/local/providers.dart';
import 'package:app/core/local/store.dart';
import 'package:app/core/local/sync_engine.dart';

import '../../fake_backend.dart';

/// The goal providers (core/finance/goal_providers.dart) over a store synced from the seed: what
/// each gives, Features.goals, a goal that isn't there, and which changes work them out again.
void main() {
  test('today is the fixtures\' day, as a day key', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(todayProvider), 20260925);
    expect(dayKeyOf(DateTime(2026, 1, 5)), 20260105);
  });

  test('goals: every live goal today, by priority, with the engine\'s figures', () async {
    final store = await _seeded();
    final c = _container(store);
    final goals = await c.get(goalsProvider.future);
    expect([for (final g in goals) g.goal.name], ['Emergency fund', 'Ladakh trip', 'Gold coins']);
    expect(goals, same(store.ledger.finance.goals(today: 20260925)));
    final ladakh = goals[1];
    expect((ladakh.progressMinor, ladakh.monthsLeft, ladakh.requiredMonthlyMinor), (1700000, 9, 477778));
    expect(await c.get(goalProvider(ladakh.goal.id).future), same(ladakh));
    expect(
      [for (final g in await c.get(topGoalsProvider.future)) g.goal.name],
      ['Emergency fund', 'Ladakh trip', 'Gold coins'],
    );
  });

  test('a goal that isn\'t there fails like the API\'s 404', () async {
    final store = await _seeded();
    final c = _container(store);
    await expectLater(
      c.get(goalProvider('a0000000-0000-4000-8000-000000000000').future),
      throwsA(isA<ApiException>().having((e) => e.code, 'status', 404)),
    );
    await expectLater(
      c.get(goalGuardsProvider('a0000000-0000-4000-8000-000000000000').future),
      throwsA(isA<ApiException>().having((e) => e.code, 'status', 404)),
    );
    expect(await c.get(goalContributionsProvider('a0000000-0000-4000-8000-000000000000').future), isEmpty);
  });

  test("contributions with their entries; guards; the accounts a goal can follow", () async {
    final store = await _seeded();
    final c = _container(store);
    final goals = await c.get(goalsProvider.future);
    final (fund, ladakh, gold) = (goals[0].goal, goals[1].goal, goals[2].goal);
    final views = await c.get(goalContributionsProvider(ladakh.id).future);
    expect(
      [for (final v in views) (v.contribution.amountMinor, v.contribution.note, v.entryDescription, v.accountName)],
      [(200000, 'Trip jar', 'Cash withdrawal', 'Cash'), (1500000, 'Saved before I started tracking', null, null)],
    );
    final guards = await c.get(goalGuardsProvider(gold.id).future);
    expect(guards.followedBy(fund.linkedAccountId!)?.name, 'Emergency fund');
    expect(guards.canArchiveOrSwitch, isTrue);
    expect(
      [for (final a in await c.get(followableAccountsProvider(null).future)) a.name],
      ['Zerodha', 'HDFC ··4821', 'Cash'],
    );
    expect([
      for (final a in await c.get(followableAccountsProvider(fund.id).future)) a.name,
    ], contains('Emergency savings'));
  });

  test('Features.goals off: no goals, and a goal is not found', () async {
    final store = await _seeded();
    final c = _container(store, features: const Features(goals: false));
    expect(await c.get(goalsProvider.future), isEmpty);
    expect(await c.get(topGoalsProvider.future), isEmpty);
    final id = store.ledger.personalGoalList().first['id'] as String;
    expect(await c.get(goalContributionsProvider(id).future), isEmpty);
    await expectLater(c.get(goalProvider(id).future), throwsA(isA<ApiException>()));
  });

  test('worked out again for a personal change, not for a groups one', () async {
    final store = await _seeded();
    final c = _container(store);
    var built = 0;
    c.listen(goalsProvider, (_, next) {
      if (next is AsyncData) built++;
    });
    final before = await c.get(goalsProvider.future);
    built = 0;
    final group = store.ledger.groups().first['id'] as String;
    final raw = store.ledger.rawGroup(group)!;
    final v = (raw['version'] as int) + 1;
    await store.enqueue(
      _op([
        LocalEntity('group:$group', 'group', group, v, {...raw, 'name': 'Renamed', 'version': v}),
      ]),
    );
    await pumpEventQueue();
    expect(built, 0);
    expect(await c.get(goalsProvider.future), same(before));

    // Gold coins' progress typed in again: a personal change.
    final gold = store.ledger.personalGoalList().last;
    final raw2 = store.ledger.rawGoal(gold['id'] as String)!;
    final v2 = (raw2['version'] as int) + 1;
    await store.enqueue(
      _op([
        LocalEntity('user:${store.ledger.me}', 'personal_goal', gold['id'] as String, v2, {
          ...raw2,
          'manual_progress_minor': 10000000,
          'version': v2,
        }),
      ]),
    );
    await pumpEventQueue();
    expect(built, 1);
    final after = await c.get(goalsProvider.future);
    expect((after.last.progressMinor, after.last.percentShown), (10000000, 50));
  });
}

var _n = 0;

/// A store synced from the seed (the fake backend's snapshots for john).
Future<LocalStore> _seeded() async {
  final be = FakeBackend();
  final store = await LocalStore.open(databaseFactoryMemory, 'goal-providers-${_n++}');
  await SyncEngine(
    api: SyncApi(ApiClient(basePath: '')..client = be.client),
    store: store,
  ).pull();
  addTearDown(store.close);
  return store;
}

/// The providers over [store], with these flags.
ProviderContainer _container(LocalStore store, {Features features = const Features()}) {
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      localStoreProvider.overrideWith((ref) async => store),
      ledgerProvider.overrideWith((ref) => store.watch()),
      featuresProvider.overrideWithValue(features),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

extension on ProviderContainer {
  /// What [provider] gives, read while listened to: one nobody listens to is paused, and never
  /// gives it.
  Future<T> get<T>(ProviderListenable<Future<T>> provider) => listen(provider, (_, _) {}).read();
}

OutboxOp _op(List<LocalEntity> entities) =>
    OutboxOp(method: 'POST', path: '/api/v1/x', label: 'Test', entities: entities, createdAt: '2026-09-25T10:00:00Z');
