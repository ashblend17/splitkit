import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/finance/finance.dart';
import 'package:splitkit/core/finance/holding_providers.dart';
import 'package:splitkit/core/integrations.dart';
import 'package:splitkit/core/local/ledger.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/local/store.dart';
import 'package:splitkit/core/local/sync_engine.dart';

import '../../fake_backend.dart';
import 'finance_helpers.dart';

/// Holdings (core/finance/holdings.dart): gains, stale values, and investment accounts valued by
/// their holdings with each rupee counted once; the seed's Zerodha account; and the providers.
void main() {
  const today = 20260925;

  FinHolding holding(
    String id, {
    String accountId = 'zerodha',
    int market = 50000,
    int day = 20260901,
    int? cost,
    bool deleted = false,
    String currency = 'INR',
  }) => FinHolding(
    id: id,
    accountId: accountId,
    name: id,
    type: HoldingType.mutualFund,
    marketValueMinor: market,
    valuationDay: day,
    currency: currency,
    costBasisMinor: cost,
    deleted: deleted,
  );

  /// [e] naming holding [holdingId].
  FinEntry naming(FinEntry e, String holdingId) => FinEntry({...e.raw, 'holding_id': holdingId});

  final bank = account('bank', opening: 100000);
  final zerodha = account('zerodha', type: AccountType.investment);

  HoldingView view(FinHolding h, {int on = today, List<FinEntry> entries = const [], int staleDays = 30}) =>
      holdingView(h, today: on, namingIt: entries, staleDays: staleDays);

  FinanceEngine engine(List<FinAccount> accounts, List<FinEntry> entries, List<FinHolding> holdings) =>
      FinanceEngine(accounts: accounts, entries: entries, currency: 'INR', holdings: holdings);

  NetWorth worth(FinanceEngine f) => f.netWorth(splitNetMinor: 0, countSplit: false, today: today);

  test('a synced holding is read once per map; a type this build does not know is left out', () {
    final raw = <String, dynamic>{
      'id': 'h1',
      'account_id': 'zerodha',
      'name': 'Nifty 50 index fund',
      'asset_type': 'mutual_fund',
      'quantity': '412.358',
      'cost_basis_minor': 6000000,
      'market_value_minor': 6845000,
      'valuation_at': '2026-08-15',
      'valuation_source': 'manual',
      'currency': 'INR',
      'created_at': '2026-04-10T12:35:00+00:00',
      'deleted_at': null,
      'version': 3,
    };
    final h = FinHolding.read(raw)!;
    expect(
      (h.type, h.quantity, h.costBasisMinor, h.marketValueMinor, h.valuationDay, h.deleted, h.version),
      (HoldingType.mutualFund, '412.358', 6000000, 6845000, 20260815, false, 3),
    );
    expect(h.createdMicros, DateTime.parse('2026-04-10T12:35:00+00:00').microsecondsSinceEpoch);
    expect(FinHolding.read(raw), same(h));
    expect(FinHolding.read({...raw, 'asset_type': 'crypto'}), isNull);
    expect(FinHolding.read({...raw, 'deleted_at': '2026-09-01T00:00:00Z', 'quantity': null})!.deleted, isTrue);
    expect([for (final t in HoldingType.values) holdingTypeFromWire(t.wire)], HoldingType.values);
  });

  group('one holding', () {
    test('a gain only with a cost basis, in basis points of it', () {
      final nifty = view(holding('nifty', market: 6845000, cost: 6000000));
      expect((nifty.gainMinor, nifty.gainBp), (845000, 1408));
      expect((view(holding('tata', market: 1230000)).gainMinor, view(holding('tata')).gainBp), (null, null));
      final loss = view(holding('h', market: 9000, cost: 10000));
      expect((loss.gainMinor, loss.gainBp), (-1000, -1000));
      final free = view(holding('h', market: 9000, cost: 0));
      expect((free.gainMinor, free.gainBp), (9000, null));
    });

    test('day 30 is fresh, day 31 stale, counted in calendar days', () {
      final fresh = view(holding('h', day: 20260826));
      expect((fresh.ageDays, fresh.stale), (30, false));
      final stale = view(holding('h', day: 20260825));
      expect((stale.ageDays, stale.stale), (31, true));
      // Across a year's end, and with a shorter limit.
      expect(view(holding('h', day: 20251231), on: 20260130).stale, isFalse);
      expect(view(holding('h', day: 20251231), on: 20260131).stale, isTrue);
      expect(view(holding('h', day: 20260917), staleDays: 7).stale, isTrue);
      expect(view(holding('h', day: today)).ageDays, 0);
    });

    test('what was put in or taken out after its valuation counts at cost', () {
      final h = holding('h', market: 50000, cost: 40000);
      final added = view(
        h,
        entries: [
          naming(entry(type: 'investment_contribution', amount: 5000, day: 20260905, accountId: 'bank'), 'h'),
          naming(entry(type: 'investment_withdrawal', amount: 2000, day: 20260910, accountId: 'bank'), 'h'),
          // Not counted: on the valuation day or before it, deleted, another holding's, another
          // currency's, or not an investment.
          naming(entry(type: 'investment_contribution', amount: 700, day: 20260901, accountId: 'bank'), 'h'),
          naming(entry(type: 'investment_contribution', amount: 700, day: 20260820, accountId: 'bank'), 'h'),
          naming(
            entry(type: 'investment_contribution', amount: 700, day: 20260905, deletedAt: '2026-09-06T00:00:00Z'),
            'h',
          ),
          naming(entry(type: 'investment_contribution', amount: 700, day: 20260905), 'other'),
          naming(entry(type: 'investment_contribution', amount: 700, day: 20260905, currency: 'USD'), 'h'),
          naming(entry(type: 'expense', amount: 700, day: 20260905), 'h'),
        ],
      );
      expect((added.addedSinceMinor, added.valueMinor), (3000, 53000));
      // Additions raise value and cost alike: the gain is the valuation's.
      expect(added.gainMinor, 10000);
    });
  });

  group('an investment account, valued by its holdings', () {
    test('without live holdings it is worth its balance', () {
      final opening = account('zerodha', type: AccountType.investment, opening: 70000);
      for (final holdings in [
        <FinHolding>[],
        [holding('h', deleted: true)],
        [holding('h', accountId: 'other')],
      ]) {
        final v = engine([opening], const [], holdings).accountValue('zerodha', today: today)!;
        expect((v.byHoldings, v.valueMinor, v.ledgerMinor, v.holdings.length), (false, 70000, 70000, 0));
      }
      // Only an investment account is valued by holdings.
      final v = engine([bank], const [], [holding('h', accountId: 'bank')]).accountValue('bank', today: today)!;
      expect((v.byHoldings, v.valueMinor), (false, 100000));
    });

    test('an opening balance typed in as the portfolio and its entries up to the valuation count once', () {
      final typedIn = account('zerodha', type: AccountType.investment, opening: 80000);
      final (out, into) = transfer(from: 'bank', to: 'zerodha', amount: 5000, day: 20260820);
      final f = engine([bank, typedIn], [out, into], [holding('h', market: 85000)]);
      final v = f.accountValue('zerodha', today: today)!;
      expect(
        (v.byHoldings, v.ledgerMinor, v.valueMinor, v.holdingsMinor, v.addedSinceMinor),
        (true, 85000, 85000, 85000, 0),
      );
      expect(worth(f).assetsMinor, 95000 + 85000);
    });

    test('a transfer in after the valuation counts at cost, and net worth is unchanged by it', () {
      final before = engine([bank, zerodha], const [], [holding('h')]);
      final (out, into) = transfer(from: 'bank', to: 'zerodha', amount: 20000, day: 20260910);
      final after = engine([bank, zerodha], [out, into], [holding('h')]);
      expect(worth(after).totalMinor, worth(before).totalMinor);
      final v = after.accountValue('zerodha', today: today)!;
      expect((v.valueMinor, v.holdingsMinor, v.addedSinceMinor), (70000, 50000, 20000));
      expect(worth(after).investmentsMinor, 70000);
    });

    test('a SIP from the bank naming a holding adds at cost; net worth is unchanged', () {
      final before = engine([bank, zerodha], const [], [holding('h')]);
      final sip = naming(entry(type: 'investment_contribution', amount: 5000, day: 20260905, accountId: 'bank'), 'h');
      final after = engine([bank, zerodha], [sip], [holding('h')]);
      expect(worth(after).totalMinor, worth(before).totalMinor);
      expect(after.accountValue('zerodha', today: today)!.valueMinor, 55000);
      expect(after.holdingsOf('zerodha', today: today).single.addedSinceMinor, 5000);
      expect(after.namingHolding('h'), [sip]);
    });

    test('a buy inside the account nets to zero', () {
      final (out, into) = transfer(from: 'bank', to: 'zerodha', amount: 20000, day: 20260910);
      final cash = engine([bank, zerodha], [out, into], [holding('h')]);
      final buy = naming(
        entry(type: 'investment_contribution', amount: 20000, day: 20260911, accountId: 'zerodha'),
        'h',
      );
      final bought = engine([bank, zerodha], [out, into, buy], [holding('h')]);
      expect(bought.accountValue('zerodha', today: today)!.valueMinor, 70000);
      expect(worth(bought).totalMinor, worth(cash).totalMinor);
      expect(bought.holdingsOf('zerodha', today: today).single.valueMinor, 70000);
    });

    test("its own entries count after its latest valuation; the label's date is its earliest", () {
      final (out, into) = transfer(from: 'bank', to: 'zerodha', amount: 3000, day: 20260910);
      final f = engine([bank, zerodha], [out, into], [
        holding('old', day: 20260801, market: 10000),
        holding('new', day: 20260915, market: 20000),
      ]);
      final v = f.accountValue('zerodha', today: today)!;
      // The 10 Sep transfer is before the latest valuation (15 Sep): taken to be in it.
      expect((v.valueMinor, v.asOfDay, v.latestValuationDay, v.staleCount), (30000, 20260801, 20260915, 1));
      // Made at the same time: by id.
      expect([for (final h in v.holdings) (h.holding.id, h.stale)], [('new', false), ('old', true)]);
    });

    test('with holdings off, net worth counts its balance', () {
      final f = engine([bank, zerodha], const [], [holding('h')]);
      final off = f.netWorth(splitNetMinor: 0, countSplit: false, today: today, holdings: false);
      expect((off.totalMinor, off.investmentsMinor, off.values.length), (100000, 0, 0));
      expect(worth(f).totalMinor, 150000);
    });

    test('remembered per day, for the last two days asked', () {
      final f = engine([bank, zerodha], const [], [holding('h', day: 20260826)]);
      final first = f.accountValues(today: today);
      expect(f.accountValues(today: today), same(first));
      expect(f.investments(today: today), same(f.investments(today: today)));
      // A day later the value is stale.
      expect(f.accountValue('zerodha', today: 20260926)!.staleCount, 1);
      expect(first[1].staleCount, 0);
      expect(f.accountValues(today: today), same(first));
      f.accountValues(today: 20260927);
      expect(f.accountValues(today: today), isNot(same(first)));
    });
  });

  group("the seed's Zerodha account on the test day", () {
    final fixture = jsonDecode(File('test/fixtures/sync/john.json').readAsStringSync()) as Map<String, dynamic>;
    final ledger = Ledger([
      for (final MapEntry(key: stream, :value) in (fixture['snapshots'] as Map<String, dynamic>).entries)
        for (final e in ((value as Map)['entities'] as List).cast<Map<String, dynamic>>())
          LocalEntity(
            stream,
            e['entity'] as String,
            e['entity_id'] as String,
            e['version'] as int?,
            (e['data'] as Map).cast(),
          ),
    ]);
    final f = ledger.finance;
    final id = f.accounts.firstWhere((a) => a.name == 'Zerodha').id;

    test('₹68,450 + ₹12,300 + the ₹5,000 SIP added at cost = ₹85,750', () {
      final v = f.accountValue(id, today: today)!;
      expect(
        (v.byHoldings, v.ledgerMinor, v.holdingsMinor, v.addedSinceMinor, v.valueMinor),
        (true, 0, 8075000, 500000, 8575000),
      );
      expect((v.asOfDay, v.latestValuationDay, v.staleCount), (20260815, 20260920, 1));
      final investments = f.investments(today: today);
      expect((investments.totalMinor, investments.asOfDay, investments.staleCount), (8575000, 20260815, 1));
      expect((investments.holdingCount, investments.addedSinceMinor), (2, 500000));
      final w = f.netWorth(splitNetMinor: 0, countSplit: false, today: today);
      expect((w.investmentsMinor, w.addedSinceMinor, w.asOfDay, w.staleCount), (8575000, 500000, 20260815, 1));
      expect(w.valueOf(f.balanceOf(id)!), 8575000);
      final off = f.netWorth(splitNetMinor: 0, countSplit: false, today: today, holdings: false);
      expect(w.totalMinor - off.totalMinor, 8575000);
    });

    test("the Nifty fund's value is stale at 41 days, with a gain; Tata's is fresh, with none", () {
      final [nifty, tata] = f.holdingsOf(id, today: today);
      expect(
        (nifty.holding.name, nifty.ageDays, nifty.stale, nifty.gainMinor, nifty.gainBp, nifty.addedSinceMinor),
        ('Nifty 50 index fund', 41, true, 845000, 1408, 500000),
      );
      expect(nifty.holding.quantity, '412.358');
      expect(
        (tata.holding.name, tata.ageDays, tata.stale, tata.gainMinor, tata.valueMinor),
        ('Tata Motors shares', 5, false, null, 1230000),
      );
      expect(f.holdingsOf(f.accounts.firstWhere((a) => a.name == 'HDFC ··4821').id, today: today), isEmpty);
      expect(f.holdingsOf('unknown', today: today), isEmpty);
    });
  });

  group('the providers', () {
    test('account values, holdings and investments, by the holdings feature', () async {
      final store = await _seeded();
      final on = _container(store);
      final values = await on.get(accountValuesProvider.future);
      final zerodha = values.firstWhere((v) => v.account.name == 'Zerodha');
      expect((zerodha.byHoldings, zerodha.valueMinor), (true, 8575000));
      expect(values, same(store.ledger.finance.accountValues(today: today)));
      expect((await on.get(holdingsOfProvider(zerodha.account.id).future)).map((h) => h.stale), [true, false]);
      expect((await on.get(investmentsProvider.future)).totalMinor, 8575000);

      final off = _container(store, features: const Features(holdings: false));
      final balances = await off.get(accountValuesProvider.future);
      expect(balances.firstWhere((v) => v.account.id == zerodha.account.id).valueMinor, 0);
      expect(await off.get(holdingsOfProvider(zerodha.account.id).future), isEmpty);
      final investments = await off.get(investmentsProvider.future);
      expect((investments.totalMinor, investments.holdingCount, investments.accounts.length), (0, 0, 1));

      final staleAfterAWeek = _container(store, features: const Features(staleValuationDays: 7));
      expect((await staleAfterAWeek.get(investmentsProvider.future)).staleCount, 1);
      final lenient = _container(store, features: const Features(staleValuationDays: 60));
      expect((await lenient.get(investmentsProvider.future)).staleCount, 0);
    });
  });
}

var _n = 0;

Future<LocalStore> _seeded() async {
  final be = FakeBackend();
  final store = await LocalStore.open(databaseFactoryMemory, 'holdings-${_n++}');
  await SyncEngine(
    api: SyncApi(ApiClient(basePath: '')..client = be.client),
    store: store,
  ).pull();
  addTearDown(store.close);
  return store;
}

ProviderContainer _container(LocalStore store, {Features features = const Features()}) {
  final c = ProviderContainer(
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
  /// What [provider] gives, read while listened to (one nobody listens to is paused).
  Future<T> get<T>(ProviderListenable<Future<T>> provider) => listen(provider, (_, _) {}).read();
}
