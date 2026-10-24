import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:app/core/api/api.dart';
import 'package:app/core/finance/allocation_providers.dart';
import 'package:app/core/finance/finance.dart';
import 'package:app/core/integrations.dart';
import 'package:app/core/local/ledger.dart';
import 'package:app/core/local/outbox.dart';
import 'package:app/core/local/providers.dart';
import 'package:app/core/local/store.dart';
import 'package:app/core/local/sync_engine.dart';

import '../../fake_backend.dart';

/// The allocation providers (core/finance/allocation_providers.dart) over a store synced from the
/// seed: John's two rules (10% of each income to the Ladakh trip; ₹5,000 to Emergency savings) and
/// the plans they made from September's salary.
void main() {
  test('the rules, the load, and the plans of the salary, a goal and an account', () async {
    final store = await _seeded();
    final c = _container(store);
    final rules = await c.get(allocationRulesProvider.future);
    expect(
      [for (final r in rules) (r.rule.name, r.rule.kind, r.planCount, r.sourceAccountGone)],
      [(null, AllocationKind.percentage, 1, false), ('Emergency top-up', AllocationKind.fixed, 1, false)],
    );
    expect(await c.get(allocationRuleProvider(rules.first.rule.id).future), same(rules.first.rule));
    expect(await c.get(allocationLoadProvider.future), const AllocationLoad(worstBp: 1000, fixedMinor: 500000));

    final f = store.ledger.finance;
    final ladakh = rules.first.rule.goalId!, savings = rules.last.rule.accountId!;
    final trip = await c.get(goalPlansProvider(ladakh).future);
    expect(
      [for (final v in trip) (v.plan.plannedMinor, v.filledMinor, v.remainingMinor, v.status)],
      [(850000, 200000, 650000, PlanStatus.partial)],
    );
    final salary = trip.single.plan.sourceTransactionId;
    expect([for (final v in await c.get(incomePlansProvider(salary).future)) v.plan.plannedMinor], [850000, 500000]);
    expect([for (final v in await c.get(accountPlansProvider(savings).future)) v.status], [PlanStatus.planned]);

    final sep = await c.get(plannedVsActualProvider(DateTime(2026, 9, 14)).future);
    expect((sep.plannedMinor, sep.actualMinor, sep.rows.length), (1350000, 200000, 2));
    expect(sep, same(f.plannedVsActual(monthRange(2026, 9))));
    final oct = await c.get(plannedVsActualProvider(DateTime(2026, 10)).future);
    expect((oct.isEmpty, oct.hasRules), (true, true));
  });

  test('a rule that isn\'t there, or is deleted, fails like the API\'s 404', () async {
    final store = await _seeded();
    final c = _container(store);
    await expectLater(
      c.get(allocationRuleProvider('a0000000-0000-4000-8000-000000000000').future),
      throwsA(isA<ApiException>().having((e) => e.code, 'status', 404)),
    );
  });

  test('Features.allocationRules off: no rules, no plans, nothing planned', () async {
    final store = await _seeded();
    final c = _container(store, features: const Features(allocationRules: false));
    expect(await c.get(allocationRulesProvider.future), isEmpty);
    expect(await c.get(allocationLoadProvider.future), AllocationLoad.none);
    final ladakh = store.ledger.finance.liveRules.first.goalId!;
    expect(await c.get(goalPlansProvider(ladakh).future), isEmpty);
    final sep = await c.get(plannedVsActualProvider(DateTime(2026, 9)).future);
    expect((sep.isEmpty, sep.hasRules), (true, false));
    final id = store.ledger.finance.liveRules.first.id;
    await expectLater(c.get(allocationRuleProvider(id).future), throwsA(isA<ApiException>()));
  });

  test('worked out again for a personal change, not for a groups one', () async {
    final store = await _seeded();
    final c = _container(store);
    var built = 0;
    c.listen(allocationRulesProvider, (_, next) {
      if (next is AsyncData) built++;
    });
    final before = await c.get(allocationRulesProvider.future);
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
    expect(await c.get(allocationRulesProvider.future), same(before));

    // The trip rule turned off: a personal change.
    final rule = store.ledger.rawRule(before.first.rule.id)!;
    final v2 = (rule['version'] as int) + 1;
    await store.enqueue(
      _op([
        LocalEntity('user:${store.ledger.me}', 'personal_allocation_rule', rule['id'] as String, v2, {
          ...rule,
          'active': false,
          'version': v2,
        }),
      ]),
    );
    await pumpEventQueue();
    expect(built, 1);
    expect((await c.get(allocationRulesProvider.future)).first.rule.active, isFalse);
  });
}

var _n = 0;

/// A store synced from the seed (the fake backend's snapshots for john).
Future<LocalStore> _seeded() async {
  final be = FakeBackend();
  final store = await LocalStore.open(databaseFactoryMemory, 'allocation-providers-${_n++}');
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
  /// What [provider] gives, read while listened to.
  Future<T> get<T>(ProviderListenable<Future<T>> provider) => listen(provider, (_, _) {}).read();
}

OutboxOp _op(List<LocalEntity> entities) =>
    OutboxOp(method: 'POST', path: '/api/v1/x', label: 'Test', entities: entities, createdAt: '2026-09-25T10:00:00Z');
