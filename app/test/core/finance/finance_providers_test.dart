import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/finance/finance.dart';
import 'package:splitkit/core/finance/finance_providers.dart';
import 'package:splitkit/core/integrations.dart';
import 'package:splitkit/core/local/ledger.dart';
import 'package:splitkit/core/local/outbox.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/local/store.dart';
import 'package:splitkit/core/local/sync_engine.dart';

import '../../fake_backend.dart';

/// The finance providers (core/finance/finance_providers.dart) over a store synced from the seed:
/// what each gives, how the flags shape it, which changes make each work its answer out again,
/// and the "Not a transfer" pairs this device keeps.
void main() {
  final answers = (jsonDecode(File('test/fixtures/sync/john.json').readAsStringSync()) as Map)['answers'] as Map;
  final summary = answers['personal_summary:2026-09-01'] as Map;
  final splitNet = ((answers['balances'] as Map)['totals'] as List).single['net_minor'] as int;
  final sep = DateTime(2026, 9);

  test('accounts and balances: the live accounts, oldest first, each with its balance', () async {
    final store = await _seeded();
    final c = _container(store);
    final accounts = await c.get(accountsProvider.future);
    expect(accounts.map((a) => a.name), [
      for (final a in (answers['personal_accounts'] as List).cast<Map>()) a['name'],
    ]);
    final balances = await c.get(accountBalancesProvider.future);
    expect([for (final b in balances) b.account.id], [for (final a in accounts) a.id]);
    final engine = await c.get(financeEngineProvider.future);
    expect(engine, same(store.ledger.finance));
    expect(balances, same(engine.balances));
    // HDFC: opening ₹27,480, then the month's salary, SIP, card bill, cash withdrawal and spends.
    final hdfc = balances.firstWhere((b) => b.account.smsLabel == 'HDFC ··4821');
    expect((hdfc.balanceMinor, hdfc.entryCount), (9613500, 9));
  });

  group('cash flow', () {
    test("spending is the summary's; any day gives its month", () async {
      final store = await _seeded();
      final c = _container(store);
      final flow = await c.get(cashFlowProvider(sep).future);
      expect(flow.period, monthRange(2026, 9));
      expect(
        (flow.spendingMinor, flow.incomeMinor, flow.refundsMinor, flow.groupShareMinor),
        (summary['spent_minor'], summary['income_minor'], summary['refunds_minor'], summary['group_share_minor']),
      );
      expect(
        [for (final x in flow.byCategory) (x.label, x.amountMinor)],
        [for (final x in (summary['by_category'] as List).cast<Map>()) (x['label'], x['amount_minor'])],
      );
      final mid = await c.get(cashFlowProvider(DateTime(2026, 9, 17)).future);
      expect((mid.period, mid.consumptionMinor), (flow.period, flow.consumptionMinor));
    });

    for (final (inPersonal, inCashFlow) in [(true, true), (true, false), (false, true), (false, false)]) {
      final counted = inPersonal && inCashFlow;
      test('group share in Personal $inPersonal, in cash flow $inCashFlow: ${counted ? '' : 'not '}counted', () async {
        final store = await _seeded();
        final c = _container(
          store,
          links: Integrations(groupShareInPersonal: inPersonal, groupShareInCashFlow: inCashFlow),
        );
        final flow = await c.get(cashFlowProvider(sep).future);
        final spent = summary['spent_minor'] as int, share = summary['group_share_minor'] as int;
        expect(flow.groupShareCounted, counted);
        expect(flow.groupShareMinor, share);
        expect(flow.consumptionMinor, spent + (counted ? share : 0));
        expect(flow.netMinor, (summary['income_minor'] as int) - spent - (counted ? share : 0));
      });
    }
  });

  group('net worth', () {
    for (final countSplit in [true, false]) {
      test('the Split line ${countSplit ? 'counts' : "is given but doesn't count"}', () async {
        final store = await _seeded();
        final c = _container(store, links: Integrations(splitInNetWorth: countSplit));
        final worth = await c.get(netWorthProvider.future);
        final balances = await c.get(accountBalancesProvider.future);
        expect((worth.splitMinor, worth.splitCounted), (splitNet, countSplit));
        var accounts = 0;
        // Each at its value: Zerodha by its holdings (holdings_test.dart).
        for (final b in balances) {
          accounts += worth.values[b.account.id]!.netWorthMinor;
        }
        expect(worth.assetsMinor - worth.liabilitiesMinor, accounts);
        expect(worth.totalMinor, accounts + (countSplit ? splitNet : 0));
      });
    }
  });

  test('each is worked out again only when a part it reads changes', () async {
    final store = await _seeded();
    final c = _container(store);
    final heard = <String, int>{};
    void count(String name, ProviderListenable<Object?> provider) =>
        c.listen(provider, (_, _) => heard[name] = (heard[name] ?? 0) + 1);
    count('engine', financeEngineProvider);
    count('accounts', accountsProvider);
    count('balances', accountBalancesProvider);
    count('cash flow', cashFlowProvider(sep));
    count('net worth', netWorthProvider);
    count('suggestions', transferSuggestionsProvider);
    await c.get(transferSuggestionsProvider.future);
    await c.get(cashFlowProvider(sep).future);
    await c.get(netWorthProvider.future);
    final engine = await c.get(financeEngineProvider.future);
    final user = 'user:${store.ledger.me}';

    Future<Set<String>> after(LocalEntity e) async {
      heard.clear();
      await store.enqueue(_op([e]));
      await pumpEventQueue();
      return heard.keys.toSet();
    }

    final group = store.ledger.groups().first['id'] as String;
    final raw = store.ledger.rawGroup(group)!;
    final v = (raw['version'] as int) + 1;
    expect(await after(LocalEntity('group:$group', 'group', group, v, {...raw, 'name': 'Renamed', 'version': v})), {
      'cash flow',
      'net worth',
      'suggestions',
    });
    expect(c.read(financeEngineProvider).value, same(engine));
    final rule = LocalEntity(user, 'category_rule', 'rule-1', null, {
      'id': 'rule-1',
      'pattern': 'chai',
      'income': false,
    });
    expect(await after(rule), {'cash flow'});
    // Your profile has your currency.
    expect(await after(store.serverEntity(LocalEntity.keyOf(user, 'profile', store.ledger.me))!), {
      'engine',
      'cash flow',
      'net worth',
    });
    final ofProfile = c.read(financeEngineProvider).value;
    expect(ofProfile, isNot(same(engine)));
    expect(await after(_entry(store.ledger.me, 'entry-1', amount: 1200)), {
      'engine',
      'accounts',
      'balances',
      'cash flow',
      'net worth',
      'suggestions',
    });
    expect(c.read(financeEngineProvider).value, isNot(same(ofProfile)));
  });

  group('transfer suggestions', () {
    /// A spend from HDFC and the same amount arriving in Emergency savings, [apart] later.
    Future<void> pair(LocalStore store, {Duration apart = const Duration(minutes: 4)}) async {
      final l = store.ledger;
      final savings = l.finance.accounts.firstWhere((a) => a.name == 'Emergency savings').id;
      final hdfc = l.finance.accountForLabel('HDFC ··4821')!.id;
      final at = DateTime.utc(2026, 9, 24, 6);
      await store.enqueue(
        _op([
          _entry(l.me, 'move-out', amount: 1500000, accountId: hdfc, smsAt: at),
          _entry(l.me, 'move-in', type: 'income', amount: 1500000, accountId: savings, smsAt: at.add(apart)),
        ]),
      );
    }

    test('a pair is offered until you say it is not a transfer, which this device keeps', () async {
      final store = await _seeded();
      final c = _container(store);
      expect(await c.get(transferSuggestionsProvider.future), isEmpty);
      await pair(store);
      await pumpEventQueue();
      final found = await c.get(transferSuggestionsProvider.future);
      expect([for (final s in found) (s.outflow.id, s.inflow.id, s.minutesApart)], [('move-out', 'move-in', 4)]);

      await c.read(notTransferProvider.notifier).dismiss(found.single);
      expect(await c.get(transferSuggestionsProvider.future), isEmpty);
      expect(await store.deviceValue(FinanceKeys.notTransfer), [found.single.key]);
      // Dismissed again (a second tap): kept once.
      await c.read(notTransferProvider.notifier).dismiss(found.single);
      expect(await store.deviceValue(FinanceKeys.notTransfer), [found.single.key]);
      // As after a restart.
      expect(await _container(store).get(transferSuggestionsProvider.future), isEmpty);
    });

    test('none when they are off, nor further apart than the window', () async {
      final store = await _seeded();
      await pair(store, apart: const Duration(minutes: 10));
      expect(await _container(store).get(transferSuggestionsProvider.future), hasLength(1));
      final off = _container(store, features: const Features(transferSuggestions: false));
      expect(await off.get(transferSuggestionsProvider.future), isEmpty);
      final narrow = _container(store, features: const Features(transferSuggestionMinutes: 5));
      expect(await narrow.get(transferSuggestionsProvider.future), isEmpty);
    });
  });
}

var _n = 0;

/// A store synced from the seed (the fake backend's snapshots for john).
Future<LocalStore> _seeded() async {
  final be = FakeBackend();
  final store = await LocalStore.open(databaseFactoryMemory, 'finance-providers-${_n++}');
  await SyncEngine(
    api: SyncApi(ApiClient(basePath: '')..client = be.client),
    store: store,
  ).pull();
  addTearDown(store.close);
  return store;
}

/// The providers over [store], with these flags.
ProviderContainer _container(
  LocalStore store, {
  Integrations links = const Integrations(),
  Features features = const Features(),
}) {
  final c = ProviderContainer(
    overrides: [
      localStoreProvider.overrideWith((ref) async => store),
      ledgerProvider.overrideWith((ref) => store.watch()),
      integrationsProvider.overrideWithValue(links),
      featuresProvider.overrideWithValue(features),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// A personal entry as synced; read from bank SMS at [smsAt] when given.
LocalEntity _entry(
  String me,
  String id, {
  String type = 'expense',
  int amount = 1000,
  String? accountId,
  DateTime? smsAt,
}) {
  final at = (smsAt ?? DateTime.utc(2026, 9, 25, 10)).toIso8601String();
  return LocalEntity('user:$me', 'personal_transaction', id, 1, {
    'id': id,
    'user_id': me,
    'type': type,
    'direction': type == 'income' ? 'in' : 'out',
    'amount_minor': amount,
    'currency': 'INR',
    'category_id': null,
    'date': at.substring(0, 10),
    'description': id,
    'account_id': accountId,
    'source': smsAt == null ? 'manual' : 'sms',
    'sms_at': smsAt == null ? null : at,
    'reviewed': true,
    'created_at': at,
    'deleted_at': null,
    'version': 1,
  });
}

extension on ProviderContainer {
  /// What [provider] gives, read while listened to: one nobody listens to is paused, and never
  /// gives it.
  Future<T> get<T>(ProviderListenable<Future<T>> provider) => listen(provider, (_, _) {}).read();
}

OutboxOp _op(List<LocalEntity> entities) =>
    OutboxOp(method: 'POST', path: '/api/v1/x', label: 'Test', entities: entities, createdAt: '2026-09-25T10:00:00Z');
