/// VM benchmarks of the device-side code over the heavy dataset (heavy_data.dart): building the
/// Ledger, the views the screens read, category suggestions while typing, and a first read of
/// 2,000 bank SMS. Each prints its median and worst and fails over a ceiling about 4× the median
/// when it was last tightened (at least a millisecond or so), to catch a big regression.
///
/// These are JIT timings on a desktop, not AOT on a phone: compare them with each other and across
/// changes, and look for work that grows with the data, not at the absolute numbers. The table is
/// printed at the end: `flutter test test/perf`.
///
/// A Ledger works out what its views share the first time one asks for it (the personal index,
/// each group's flows, the feed's order, the suggestion lookups), so a view timed on its own is
/// the cost on a Ledger already in use. The "rebuild" and "first" rows include that work: after a
/// change the store builds a new Ledger, keeping the synced maps of everything that didn't change
/// (which rows read from a map are reused), and a cold start reads every map for the first time.
@Tags(['perf'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/categorise/category_guesser.dart';
import 'package:splitkit/core/finance/finance.dart';
import 'package:splitkit/core/integrations.dart';
import 'package:splitkit/core/local/ledger.dart';
import 'package:splitkit/core/local/outbox.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/local/store.dart';
import 'package:splitkit/core/local/sync_engine.dart';
import 'package:splitkit/core/local/writes.dart';
import 'package:splitkit/core/session/session.dart';
import 'package:splitkit/core/sms/sms.dart';
import 'package:splitkit/core/sms/sms_ids.dart';
import 'package:splitkit/core/sms/sms_parser.dart';
import 'package:splitkit/core/sms/sms_scan.dart';
import 'package:splitkit/core/theme/theme.dart';
import 'package:splitkit/design_system/design_system.dart' show IconTile;
import 'package:splitkit/features/personal/personal_history_page.dart';
import 'package:splitkit/features/sms/sms_importer.dart' show smsImportUnits, smsScanInput;

import '../helpers.dart';
import 'heavy_data.dart';
import 'heavy_seed.dart';

/// One line of the report. Times in milliseconds.
class _Row {
  _Row(this.name, this.median, this.worst, this.n, {this.note = ''});
  final String name;
  final double median;
  final double worst;
  final int n;
  final String note;
}

final _rows = <_Row>[];
final _notes = <String>[];

/// smsScanInput's median on a new Ledger, for the import's UI-isolate total.
var _inputMs = 0.0;

double _ms(Stopwatch s) => s.elapsedMicroseconds / 1000;

double _median(List<double> xs) {
  final s = [...xs]..sort();
  return s.length.isOdd ? s[s.length ~/ 2] : (s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2;
}

/// 12.34 (ms), or seconds, minutes or hours once it's long.
String _fmt(double ms) => switch (ms) {
  < 10000 => ms.toStringAsFixed(2),
  < 600000 => '${(ms / 1000).toStringAsFixed(0)} s',
  < 3600000 * 3 => '${(ms / 60000).toStringAsFixed(0)} min',
  _ => '${(ms / 3600000).toStringAsFixed(0)} h',
};

_Row _record(String name, List<double> times, {String note = ''}) {
  final row = _Row(name, _median(times), times.reduce(max), times.length, note: note);
  _rows.add(row);
  return row;
}

/// One warm-up run of [body], then [runs] timed ones.
_Row _bench(String name, void Function() body, {int runs = 5, String note = ''}) {
  body();
  final times = <double>[];
  for (var i = 0; i < runs; i++) {
    final s = Stopwatch()..start();
    body();
    times.add(_ms(s));
  }
  return _record(name, times, note: note);
}

/// One warm-up run of [prepare] and [body], then [runs] timed runs of [body] on what [prepare]
/// (not timed) gives.
_Row _benchPrepared<T>(String name, T Function() prepare, void Function(T) body, {int runs = 5, String note = ''}) {
  body(prepare());
  final times = <double>[];
  for (var i = 0; i < runs; i++) {
    final input = prepare();
    final s = Stopwatch()..start();
    body(input);
    times.add(_ms(s));
  }
  return _record(name, times, note: note);
}

/// One warm-up run on the first input, then one timed run per input.
_Row _benchEach<T>(String name, List<T> inputs, void Function(T) body, {String note = ''}) {
  body(inputs.first);
  final times = <double>[];
  for (final x in inputs) {
    final s = Stopwatch()..start();
    body(x);
    times.add(_ms(s));
  }
  return _record(name, times, note: note);
}

/// Fails when [row]'s median is over [ceilingMs].
void _under(_Row row, double ceilingMs) {
  expect(row.median, lessThan(ceilingMs), reason: '${row.name}: median ${_fmt(row.median)} ms, ceiling $ceilingMs ms');
}

void main() {
  late HeavyData data;
  late List<RawSms> sms;

  late Ledger ledger;

  /// Live group expenses you created (what a group suggestion learns from).
  late int mySplits;
  final month = DateTime(2026, 9);
  final random = Random(7);

  bool mine(LocalEntity e) => e.entity == 'expense' && e.data['deleted_at'] == null && e.data['created_by'] == data.me;

  setUpAll(loadFonts);

  setUpAll(() {
    final s = Stopwatch()..start();
    data = buildHeavyData();
    _notes.add('Heavy dataset built in ${_ms(s).toStringAsFixed(0)} ms.');
    s.reset();
    sms = heavySms(data);
    _notes.add('${sms.length} SMS built in ${_ms(s).toStringAsFixed(0)} ms.');
    ledger = Ledger(data.entities);
    mySplits = data.entities.where(mine).length;
  });

  /// The entities with every map copied: as the store holds them on a cold start, with nothing
  /// read from them yet.
  List<LocalEntity> freshEntities() => [
    for (final e in data.entities) LocalEntity(e.stream, e.entity, e.entityId, e.version, Map.of(e.data)),
  ];

  tearDownAll(() {
    final b = StringBuffer()
      ..writeln()
      ..writeln('Ledger benchmarks: heavy dataset, VM (JIT, asserts on) on a desktop, not AOT on a phone.')
      ..writeln('Times in ms unless marked; median of the timed runs (after one warm-up), and the worst.')
      ..writeln()
      ..writeln('${'Operation'.padRight(66)}${'median'.padLeft(10)}${'worst'.padLeft(10)}${'n'.padLeft(6)}');
    for (final r in _rows) {
      final worst = r.n <= 1 ? '' : _fmt(r.worst);
      b.writeln(
        '${r.name.padRight(66)}${_fmt(r.median).padLeft(10)}${worst.padLeft(10)}${'${r.n}'.padLeft(6)}'
        '${r.note.isEmpty ? '' : '  ${r.note}'}',
      );
    }
    b
      ..writeln()
      ..writeln(
        'Dataset: ${[for (final e in data.counts.entries) '${e.key} ${e.value}'].join(', ')}, '
        'live splits you created $mySplits.',
      );
    for (final n in _notes) {
      b.writeln(n);
    }
    // ignore: avoid_print
    print(b);
  });

  test("heavy_seed.dart is still the sync fixture's global stream and profile", () {
    final fixture = jsonDecode(File('test/fixtures/sync/john.json').readAsStringSync()) as Map<String, dynamic>;
    final seed = heavySeedOf((fixture['snapshots'] as Map).cast());
    expect(
      jsonDecode(heavySeedJson),
      seed,
      reason: 'heavy_seed.dart should be:\n${const JsonEncoder.withIndent('  ').convert(seed)}',
    );
  });

  test('the dataset is the size the plan asks for', () {
    expect(data.counts['expenses (live)'], 5000);
    expect(data.counts['settlements (live)'], 500);
    expect(data.counts['personal (all)'], 20000);
    expect(data.counts['category rules'], 300);
    expect(data.counts['merchants'], 200);
    expect(ledger.groups().length + ledger.groups(archived: true).length, 30);
    expect(ledger.personalList()['count'], greaterThan(19000));
    expect(ledger.personalList(source: 'sms')['count'], greaterThan(15000));
    expect(ledger.personalReportedAccounts().map((a) => a['account']).toSet(), containsAll(heavyAccounts));
  });

  test('most generated SMS parse as payments', () {
    final parsed = sms.where((m) => parseSms(m) is SmsParsed).length;
    _notes.add('SMS parsed as payments: $parsed of ${sms.length}.');
    expect(parsed / sms.length, greaterThanOrEqualTo(0.9));
  });

  test('building the Ledger', () {
    _under(_bench('Ledger(entities)', () => Ledger(data.entities)), 12);
    _under(
      _benchPrepared(
        'cold start: Ledger + personalList(), every map read anew',
        freshEntities,
        (entities) => Ledger(entities).personalList(),
      ),
      240,
    );
    _under(
      _benchPrepared('cold start: Ledger + Home (overallBalances, groups, feed 30)', freshEntities, (entities) {
        final l = Ledger(entities);
        l.overallBalances();
        l.groups();
        l.feed();
      }),
      90,
    );
  });

  group('Personal views', () {
    test('personalList', () {
      _under(_bench('personalList() (limit 100)', () => ledger.personalList()), 10);
      _under(_bench('personalList(account: HDFC ··4821)', () => ledger.personalList(account: heavyAccounts.first)), 6);
      _under(
        _bench(
          'personalList(limit: 100000) (everything)',
          () => ledger.personalList(limit: 100000),
          note: 'what importOne listed before step 0.4',
        ),
        280,
      );
    });

    test('personalSummary, personalReportedAccounts', () {
      _under(_bench('personalSummary(Sep 2026)', () => ledger.personalSummary(month)), 2);
      _under(_bench('personalReportedAccounts()', () => ledger.personalReportedAccounts()), 13);
    });

    test('one entry by id', () {
      final ids = [for (var i = 0; i < 20; i++) data.livePersonalIds[random.nextInt(data.livePersonalIds.length)]];
      _under(_benchEach('rawPersonal(id), random id', ids, ledger.rawPersonal), 1);
      _under(_benchEach('personalTransaction(id), random id', ids, ledger.personalTransaction), 1);
    });

    test('manualMatch (the SMS import, per message)', () {
      final days = [for (var i = 0; i < 10; i++) heavyEnd.subtract(Duration(days: random.nextInt(180)))];
      _under(_benchEach('manualMatch(expense, amount, day)', days, (d) => ledger.manualMatch('expense', 45000, d)), 1);
    });

    test('JSON to models (the providers)', () {
      final page = ledger.personalList();
      _under(
        _bench('PersonalListOut.fromJson(personalList()) (convert only)', () => PersonalListOut.fromJson(page)),
        6,
      );
      _under(
        _bench('personalList() + PersonalListOut.fromJson', () => PersonalListOut.fromJson(ledger.personalList())),
        16,
      );
      final accounts = ledger.personalReportedAccounts();
      _under(
        _bench(
          'AccountOut.listFromJson(personalReportedAccounts()) (convert only)',
          () => AccountOut.listFromJson(accounts),
        ),
        1,
      );
    });
  });

  test('the finance engine (core/finance): built, a month of cash flow and net worth', () {
    // The heavy entries as migration 0013's backfill leaves them: an account for each bank label,
    // entries linked to it, a direction from the type. Read here, untimed: a rebuilt Ledger
    // reuses the rows of the entries that didn't change.
    final accounts = [
      for (final (i, label) in heavyAccounts.indexed)
        FinAccount(
          id: smsAccountId(data.me, label),
          name: label,
          type: accountTypeForLabel(label),
          currency: 'INR',
          smsLabel: label,
          createdMicros: i,
        ),
    ];
    final ids = {for (final a in accounts) a.smsLabel: a.id};
    final entries = [
      for (final e in data.entities)
        if (e.entity == 'personal_transaction')
          FinEntry({
            ...e.data,
            'account_id': ids[e.data['account']],
            'direction': e.data['type'] == 'income' ? 'in' : 'out',
          }),
    ];
    final notCounted = {
      for (final e in entries)
        if (e.expenseId != null || e.settlementId != null) e.id,
    };
    final sep = monthRange(2026, 9);
    String label(String? id) => id ?? 'Uncategorised';
    void overview(FinanceEngine f) {
      f.cashFlow(sep, notCounted: notCounted, groupShareMinor: 0, countGroupShare: true, label: label);
      f.netWorth(splitNetMinor: 0, countSplit: true);
    }

    _under(
      _bench(
        'FinanceEngine + cashFlow(Sep 2026) + netWorth (a new engine)',
        () => overview(FinanceEngine(accounts: accounts, entries: entries, currency: 'INR')),
        note: '${entries.length} entries, ${accounts.length} accounts',
      ),
      60,
    );
    final engine = FinanceEngine(accounts: accounts, entries: entries, currency: 'INR');
    _under(_bench('FinanceEngine cashFlow(Sep 2026) + netWorth, remembered', () => overview(engine)), 1);
    var month = 0;
    _under(
      _bench(
        'FinanceEngine cashFlow(a month not asked for yet) on a built engine',
        () => engine.cashFlow(
          monthRange(2025, ++month),
          notCounted: notCounted,
          groupShareMinor: 0,
          countGroupShare: true,
          label: label,
        ),
      ),
      2,
    );

    // Goals (Phase 2): 50 goals (25 counting contributions, 5 following an account, 20 by hand;
    // 40 active, 4 paused, 4 completed, 2 archived; dates from 6 months ago to 3 years ahead, a
    // third with none) and 5,000 contributions, 30% with an entry.
    const statuses = [GoalStatus.paused, GoalStatus.completed];
    final goals = [
      for (var i = 0; i < 50; i++)
        FinGoal(
          id: 'goal-$i',
          name: 'Goal $i',
          currency: 'INR',
          targetMinor: 10000000 + i * 100000,
          targetDay: i % 3 == 0 ? null : addDays(20260925, -180 + i * 25),
          mode: i < 25
              ? GoalMode.contribution
              : i < 30
              ? GoalMode.linkedBalance
              : GoalMode.manual,
          linkedAccountId: i >= 25 && i < 30 ? accounts[(i - 25) % accounts.length].id : null,
          manualProgressMinor: i >= 30 ? i * 50000 : null,
          status: i >= 48
              ? GoalStatus.archived
              : i >= 40
              ? statuses[i % 2]
              : GoalStatus.active,
          startDay: 20260101,
          createdMicros: i,
        ),
    ];
    final live = [
      for (final e in entries)
        if (!e.deleted) e,
    ];
    final contributions = [
      for (var i = 0; i < 5000; i++)
        FinContribution(
          id: 'contribution-$i',
          goalId: 'goal-${i % 25}',
          amountMinor: 1000 + i,
          currency: 'INR',
          day: addDays(20260925, -(i % 600)),
          transactionId: i % 10 < 3 ? live[i * 7 % live.length].id : null,
          createdMicros: i,
        ),
    ];
    FinanceEngine withGoals() {
      final f = FinanceEngine(
        accounts: accounts,
        entries: entries,
        currency: 'INR',
        goals: goals,
        contributions: contributions,
      );
      f.balances; // as on Overview, built before Goals asks
      return f;
    }

    _under(
      _benchPrepared(
        'FinanceEngine goals(today), first call (balances built)',
        withGoals,
        (FinanceEngine f) => f.goals(today: 20260925),
        note: '${goals.length} goals, ${contributions.length} contributions',
      ),
      // ~5 ms when added, most of it indexing the 20,000 entries by id the first time.
      20,
    );
    final goalsEngine = withGoals();
    final first = goalsEngine.goals(today: 20260925);
    expect(goalsEngine.goals(today: 20260925), same(first), reason: 'remembered for the day');
  });

  group("Ledger.finance: what the finance providers read (the heavy data with migration 0013's accounts)", () {
    late List<LocalEntity> entities;
    late Ledger inUse;
    final sep = monthRange(2026, 9);
    const window = Duration(minutes: 30);
    setUpAll(() {
      entities = _withAccounts(data);
      inUse = Ledger(entities);
    });

    // As cashFlowProvider, netWorthProvider and transferSuggestionsProvider ask.
    CashFlow cashFlow(Ledger l, DayRange month) => l.finance.cashFlow(
      month,
      notCounted: l.notCounted,
      groupShareMinor: l.groupShareFor(month),
      countGroupShare: true,
      label: l.categoryLabel,
    );
    NetWorth netWorth(Ledger l) => l.finance.netWorth(splitNetMinor: l.splitNet(l.finance.currency), countSplit: true);
    List<TransferSuggestion> suggestions(Ledger l, Set<String> dismissed) =>
        l.finance.transferSuggestions(notCounted: l.notCounted, dismissed: dismissed, window: window);

    test('after a change to personal entries: a new Ledger, a new engine', () {
      _under(
        _bench(
          'Ledger() + finance.balances (engine built: entries sorted, balances)',
          () => Ledger(entities).finance.balances,
          note: '${heavyAccounts.length} accounts',
        ),
        60,
      );
      // Also notCounted, the group share and (for net worth) overallBalances, worked out anew.
      _under(_bench('Ledger() + cashFlowProvider(Sep 2026)', () => cashFlow(Ledger(entities), sep)), 90);
      _under(_bench('Ledger() + netWorthProvider (balances, splitNet)', () => netWorth(Ledger(entities))), 90);
      _under(
        _bench(
          'Ledger() + transferSuggestionsProvider',
          () => suggestions(Ledger(entities), const {}),
          note: 'pairs found: ${suggestions(inUse, const {}).length}',
        ),
        90,
      );
    });

    test('on a Ledger in use', () {
      cashFlow(inUse, sep);
      netWorth(inUse);
      var month = 0;
      _under(
        _bench('cashFlowProvider(a month not asked for yet)', () => cashFlow(inUse, monthRange(2025, ++month))),
        1,
      );
      _under(_bench('cashFlowProvider(Sep 2026), remembered', () => cashFlow(inUse, sep)), 0.5);
      _under(_bench('netWorthProvider', () => netWorth(inUse)), 0.5);
      _under(
        _bench('transferSuggestionsProvider (dismissals changed: worked out again)', () => suggestions(inUse, {})),
        30,
      );
    });

    test('after a groups-only change the engine carries over; after a personal one it is built again', () async {
      final store = await _heavyStore(data, 'perf-carry', entities: entities);
      addTearDown(store.close);
      final user = entities.firstWhere((e) => e.entity == 'profile').stream;
      final group = entities.firstWhere((e) => e.entity == 'group');
      final entry = entities.firstWhere((e) => e.entity == 'personal_transaction' && e.data['deleted_at'] == null);
      var run = 0;
      // The store's next Ledger and the Overview's finance answers on it, after [change] is queued.
      Future<(double, FinanceEngine)> after(LocalEntity Function(int version) change) async {
        await store.enqueue(
          OutboxOp(
            method: 'PUT',
            path: '/api/v1/x',
            label: 'Perf',
            entities: [change(++run + 1)],
            createdAt: '2026-09-25T10:00:00Z',
          ),
        );
        final s = Stopwatch()..start();
        final l = store.ledger;
        cashFlow(l, sep);
        netWorth(l);
        return (_ms(s), l.finance);
      }

      LocalEntity renamed(int v) =>
          LocalEntity(group.stream, 'group', group.entityId, v, {...group.data, 'name': 'Renamed $v', 'version': v});
      LocalEntity edited(int v) => LocalEntity(user, 'personal_transaction', entry.entityId, v, {
        ...entry.data,
        'notes': 'Edit $v',
        'version': v,
      });

      final engine = store.ledger.finance;
      cashFlow(store.ledger, sep);
      final groupsOnly = [for (var i = 0; i < 6; i++) await after(renamed)];
      for (final (_, e) in groupsOnly) {
        expect(e, same(engine));
      }
      _under(
        _record(
          'groups-only change: store.ledger + cash flow + net worth',
          [for (final (ms, _) in groupsOnly.skip(1)) ms],
          note: 'the engine carried over',
        ),
        80,
      );
      final personal = [for (var i = 0; i < 6; i++) await after(edited)];
      expect(personal.map((p) => p.$2).toSet(), hasLength(6));
      _under(
        _record(
          'personal change: store.ledger + cash flow + net worth',
          [for (final (ms, _) in personal.skip(1)) ms],
          note: 'a new engine',
        ),
        120,
      );
    });
  });

  group('Split views', () {
    test('overallBalances, groups, feed, groupBalances, expense', () {
      _under(_bench('overallBalances()', () => ledger.overallBalances()), 8);
      _under(_bench('groups()', () => ledger.groups()), 1);
      _under(_bench('feed(limit: 100)', () => ledger.feed(limit: 100)), 2);
      _under(_bench('groupBalances(largest group)', () => ledger.groupBalances(data.largestGroupId)), 2);
      final ids = [for (var i = 0; i < 20; i++) data.liveExpenseIds[random.nextInt(data.liveExpenseIds.length)]];
      _under(_benchEach('expense(id), random id', ids, ledger.expense), 1);
    });

    test('JSON to models (the providers)', () {
      final feed = ledger.feed(limit: 100);
      _under(_bench('FeedItem.listFromJson(feed(limit: 100)) (convert only)', () => FeedItem.listFromJson(feed)), 3);
      _under(
        _bench('feed(limit: 100) + FeedItem.listFromJson', () => FeedItem.listFromJson(ledger.feed(limit: 100))),
        6,
      );
      _under(
        _bench(
          'overallBalances() + OverallBalancesOut.fromJson',
          () => OverallBalancesOut.fromJson(ledger.overallBalances()),
        ),
        10,
      );
    });
  });

  test('a sync burst: three writes sent, three streams of changes, the outbox settled', () async {
    final run = await _SyncBurst.start(data);
    final times = <double>[];
    final events = <int>[];
    final builds = <int>[];
    for (var i = 0; i < 4; i++) {
      final (ms, n, b) = await run.once();
      times.add(ms);
      events.add(n);
      builds.add(b);
    }
    // The first run warms up.
    final row = _record(
      'sync burst + Home views per Ledger event (rebuilds: ${builds.last})',
      times.skip(1).toList(),
      note: '${events.last} Ledger events',
    );
    _notes.add(
      'Sync burst: ${events.skip(1).join(', ')} Ledger events and ${builds.skip(1).join(', ')} rebuilds per run.',
    );
    await run.close();
    // Before the store held a sync's changes back: 7 Ledger events and rebuilds, ~94 ms.
    expect(events.last, 1);
    _under(row, 80);
  });

  test('opening the device store: sembast on disk, every entity read', () async {
    // The phone's store (sembast_io, one JSON line per entity), written once.
    final dir = await Directory.systemTemp.createTemp('splitkit-perf-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/store.db';
    await (await _heavyStore(data, path, factory: databaseFactoryIo)).close();
    final bytes = File(path).lengthSync();

    // The longest stretch the isolate spent without a break while opening: sembast reads the file
    // in chunks, so the screen can still draw frames in between (a 1 ms timer measures the gaps).
    var busiest = 0.0;
    Future<double> open({void Function(LocalStore store)? then}) async {
      final gaps = Stopwatch()..start();
      final ticks = Timer.periodic(const Duration(milliseconds: 1), (_) {
        busiest = max(busiest, _ms(gaps));
        gaps.reset();
      });
      final s = Stopwatch()..start();
      final store = await LocalStore.open(databaseFactoryIo, path);
      ticks.cancel();
      then?.call(store);
      final ms = _ms(s);
      expect(store.entities.length, data.entities.length);
      await store.close();
      return ms;
    }

    // The first open in this process is the cold one (sembast's file code not compiled yet).
    final cold = await open();
    busiest = 0;
    final opens = [for (var i = 0; i < 5; i++) await open()];
    final row = _record(
      'LocalStore.open: ${data.entities.length} entities from disk',
      opens,
      note: '${(bytes / 1048576).toStringAsFixed(1)} MB; the first, cold: ${_fmt(cold)}',
    );
    _notes.add(
      'LocalStore.open: the longest stretch without a break was ${busiest.toStringAsFixed(0)} ms: sembast reads the '
      'file in chunks (10-25 ms), then the entities are read back and wrapped in one go.',
    );
    // What a cold start waits for before Overview has its numbers: the store, a new Ledger, the
    // Overview's views.
    _record('LocalStore.open + first Ledger + Overview views', [
      for (var i = 0; i < 3; i++)
        await open(
          then: (store) {
            final l = store.ledger;
            PersonalSummaryOut.fromJson(l.personalSummary(month));
            PersonalListOut.fromJson(l.personalList(limit: 5));
          },
        ),
    ]);
    // Over the plan's 400 ms for moving decoding off the UI isolate (~750 ms here, step 0.6), but in
    // chunks, not one long freeze. Sembast keeps every record on the isolate that opened it, so that
    // would mean running the whole store on another isolate (ISS-084).
    _under(row, 3000);
  });

  test('after a write: the whole Ledger is rebuilt, and a visible tab reads its views again', () {
    // ~28 ms before D2; the summary now comes from the finance engine, which sorts the entries
    // once per new engine (~12 ms more; a change that isn't to Personal keeps the engine).
    _under(
      _bench('rebuild + Personal Overview (summary, accounts, list)', () {
        final l = Ledger(data.entities);
        PersonalSummaryOut.fromJson(l.personalSummary(month));
        AccountOut.listFromJson(l.personalReportedAccounts());
        PersonalListOut.fromJson(l.personalList());
      }),
      90,
    );
    _under(
      _bench('rebuild + Home (overallBalances, groups, feed 30)', () {
        final l = Ledger(data.entities);
        OverallBalancesOut.fromJson(l.overallBalances());
        GroupOut.listFromJson(l.groups());
        FeedItem.listFromJson(l.feed());
      }),
      50,
    );
  });

  testWidgets('Transactions: the first frame with data, on the heavy data', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final user = UserOut.fromJson(data.entities.firstWhere((e) => e.entity == 'profile').data)!;
    final times = <double>[];
    var rows = 0;
    for (var run = 0; run < 6; run++) {
      await tester.pumpWidget(const SizedBox());
      final s = Stopwatch()..start();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(() => _SignedIn(Session(token: 'perf', user: user))),
            meProvider.overrideWithValue(user),
            ledgerProvider.overrideWith((ref) => Stream.value(ledger)),
            // No store: views read the ledger above.
            localStoreProvider.overrideWith((ref) => Completer<LocalStore>().future),
          ],
          child: MaterialApp(theme: buildSplitkitTheme(), home: const PersonalHistoryPage()),
        ),
      );
      for (var i = 0; i < 20 && find.text('Per day').evaluate().isEmpty; i++) {
        await tester.pump();
      }
      if (run > 0) times.add(_ms(s)); // the first run warms up
      rows = find.byType(IconTile).evaluate().length;
    }
    expect(find.text('Per day'), findsOneWidget);
    // Before the list was lazy (step 0.5): ~250 ms, every row of the month built (241).
    _under(_record('Transactions: first frame with data (this month)', times, note: '$rows rows built'), 400);
    await tester.pumpWidget(const SizedBox());
  });

  test('category suggestions while typing (categoryFor per keystroke)', () {
    const descriptions = [
      'Zomato order', 'Uber to airport', 'Groceries at DMart', 'Electricity bill', 'Dinner with Rahul', //
      'Chai', 'Netflix subscription', 'Medicines', 'Petrol', 'Amazon Pay',
    ];
    final prefixes = [
      for (final d in descriptions)
        for (var i = 1; i <= d.length; i++)
          if (d.substring(0, i).trim().isNotEmpty) d.substring(0, i),
    ];
    // As suggestCategory calls it (core/data/providers.dart): learned, then keywords with typos.
    final keywords = _benchEach(
      'categoryFor per keystroke, keywords only (learn: false)',
      prefixes,
      (text) => categoryFor(ledger, text, scope: 'personal', learn: false),
      note: '${descriptions.length} descriptions typed',
    );
    _under(keywords, 1);
    _under(
      _benchEach(
        'categoryFor per keystroke, Personal',
        prefixes,
        (text) => categoryFor(ledger, text, scope: 'personal'),
      ),
      2,
    );
    _under(
      _benchEach('categoryFor per keystroke, a group', prefixes, (text) => categoryFor(ledger, text, scope: 'group')),
      2,
    );
    // After a change the Ledger is new, and its first suggestion files everything by merchant.
    _under(
      _bench(
        'first categoryFor on a new Ledger, Personal (+ Ledger())',
        () => categoryFor(Ledger(data.entities), 'Zomato order', scope: 'personal'),
      ),
      30,
    );
    _under(
      _bench(
        'first categoryFor on a new Ledger, a group (+ Ledger())',
        () => categoryFor(Ledger(data.entities), 'Zomato order', scope: 'group'),
      ),
      22,
    );
  });

  test('SMS import: parsing alone', () {
    _under(
      _bench('parseSms + smsEntryId, all ${sms.length} SMS (total)', () {
        for (final m in sms) {
          if (parseSms(m) case SmsParsed(:final txn)) smsEntryId(data.me, m, txn);
        }
      }, runs: 3),
      350,
    );
  });

  test('SMS import: the scan (core/sms/sms_scan.dart), inline and on another isolate', () async {
    // The heavy data as migration 0013 leaves it (an account per label, as on a phone since), and
    // as it was before (no accounts: the read makes one per label, and each takes in the label's
    // entries, which its opening balance counts).
    final accounts = Ledger(_withAccounts(data));
    // On the UI isolate: what the scan needs, taken from the device's data.
    _under(_bench('smsScanInput: from a Ledger in use', () => smsScanInput(accounts, sms, const Features())), 20);
    _under(
      _bench('smsScanInput: from a Ledger in use, no accounts yet', () => smsScanInput(ledger, sms, const Features())),
      20,
    );
    final withAccounts = _withAccounts(data);
    final inputCold = _bench(
      'smsScanInput: the first time on a new Ledger (+ Ledger())',
      () => smsScanInput(Ledger(withAccounts), sms, const Features()),
    );
    _under(inputCold, 150);
    for (final (l, made, name) in [(accounts, 4, ''), (ledger, 10, ', no accounts yet')]) {
      final input = smsScanInput(l, sms, const Features());
      final out = scanSms(input);
      // The heavy SMS are all plain payments (no refunds, card bills, own transfers or ATM): the
      // same entries as before, now each in its account; the labels with none get one.
      expect((out.created.length, out.attached.length, out.known, out.skipped.length), (1719, 81, 200, 0));
      expect((out.newAccounts.length, out.convert.length), (made, 0));
      _notes.add(
        'SMS scan$name: ${out.created.length} created, ${out.attached.length} attached, ${out.known} known, '
        '${out.skipped.length} skipped, ${out.newAccounts.length} accounts made.',
      );
      _under(_bench('scanSms, all ${sms.length} SMS, inline (total)$name', () => scanSms(input), runs: 3), 600);
      // Off the UI isolate: the whole wait, sending the input and the answer included.
      await Isolate.run(() => scanSms(input));
      final wall = <double>[];
      for (var i = 0; i < 3; i++) {
        final s = Stopwatch()..start();
        await Isolate.run(() => scanSms(input));
        wall.add(_ms(s));
      }
      _record('scanSms, all ${sms.length} SMS, on another isolate (wall time)$name', wall, note: 'off the UI isolate');
    }
    _inputMs = inputCold.median;
  });

  test('SMS import: queueing what a first read found', () async {
    final q = await _ImportQueue.start(data, entities: _withAccounts(data));
    final read = scanSms(smsScanInput(q.store.ledger, sms, const Features()));
    Future<(double, int)> once(Future<void> Function() queue) async {
      final ops = q.store.outbox.length;
      final builds = q.store.ledgerBuilds;
      final s = Stopwatch()..start();
      await queue();
      final ms = _ms(s);
      final built = q.store.ledgerBuilds - builds;
      await pumpEventQueue();
      await q.store.removeOps([for (final op in q.store.outbox.skip(ops)) op.id!]);
      q.store.ledger; // as the screens would, before the next read
      return (ms, built);
    }

    Future<_Row> bench(String name, Future<void> Function() queue) async {
      await once(queue);
      final runs = [for (var i = 0; i < 4; i++) await once(queue)];
      return _record('$name (rebuilds: ${runs.last.$2})', [for (final (ms, _) in runs) ms]);
    }

    final writes = q.container.read(writesProvider);
    final queued = await bench(
      'importUnits: ${read.created.length} new + ${read.attached.length} attached + ${read.newAccounts.length} '
      'accounts, one enqueueAll',
      // As the importer queues: a refused unit would be left out (none is here).
      () => writes.importUnits(smsImportUnits(q.store.ledger, read), onRefused: (unit, why) => fail('$unit: $why')),
    );
    await q.close();
    // Before step 0.4: new entries, then one write (and rebuild) per attached entry: ~1.1 s,
    // 82 rebuilds.
    _under(queued, 250);
    _rows.add(
      _Row(
        'SMS import, ${sms.length} SMS: on the UI isolate (input + queueing)',
        _inputMs + queued.median,
        0,
        0,
        note: 'the scan runs on another isolate',
      ),
    );
  });
}

/// A pull on a store holding the heavy dataset, as the sync engine runs it against the API: three
/// writes queued on this device are sent, POST /sync brings changes on three streams (the server's
/// copies of those writes among them), and the outbox settles. After each Ledger the store emits,
/// Home's views are read again, as a visible Home tab would.
class _SyncBurst {
  _SyncBurst._(this.store, this.engine, this.data);

  final LocalStore store;
  final SyncEngine engine;
  final HeavyData data;
  var _seq = 1000;
  var _run = 0;
  List<Map<String, dynamic>> _serverChanges = const [];

  static var _n = 0;

  static Future<_SyncBurst> start(HeavyData data) async {
    final store = await _heavyStore(data, 'perf-burst-${_n++}');
    late _SyncBurst burst;
    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/sync') {
        final changes = burst._serverChanges;
        burst._serverChanges = const [];
        final byStream = <String, List<Map<String, dynamic>>>{};
        for (final c in changes) {
          (byStream[c['stream'] as String] ??= []).add(c);
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'streams': [
                for (final MapEntry(key: stream, value: list) in byStream.entries)
                  {'stream': stream, 'status': 'ok', 'head_seq': list.last['seq'], 'changes': list, 'has_more': false},
              ],
            }),
          ),
          200,
        );
      }
      return http.Response('{}', 200);
    });
    final engine = SyncEngine(
      api: SyncApi(ApiClient(basePath: '')..client = client),
      store: store,
    );
    burst = _SyncBurst._(store, engine, data);
    return burst;
  }

  /// One burst: (ms, Ledger events, Ledger builds).
  Future<(double, int, int)> once() async {
    _run++;
    final user = data.entities.firstWhere((e) => e.entity == 'profile').stream;
    final groups = [
      for (final id in data.groupIds.take(2)) data.entities.firstWhere((e) => e.entity == 'group' && e.entityId == id),
    ];
    final personal = store.ledger.rawPersonal(data.livePersonalIds[_run])!;
    final expense = data.entities.firstWhere((e) => e.entity == 'expense' && e.stream == groups[0].stream);
    final settlement = data.entities.firstWhere((e) => e.entity == 'settlement' && e.stream == groups[1].stream);
    LocalEntity edited(String stream, String entity, String id, Map<String, dynamic> data, String field, String value) {
      final version = (data['version'] as int? ?? 1) + _run;
      return LocalEntity(stream, entity, id, version, {...data, field: value, 'version': version});
    }

    final writes = [
      edited(user, 'personal_transaction', personal['id'] as String, personal, 'notes', 'burst $_run'),
      edited(expense.stream, 'expense', expense.entityId, expense.data, 'notes', 'burst $_run'),
      edited(settlement.stream, 'settlement', settlement.entityId, settlement.data, 'note', 'burst $_run'),
    ];
    await store.enqueueAll([
      for (final e in writes)
        OutboxOp(
          method: 'PUT',
          path: '/api/v1/x/${e.entityId}',
          label: 'Burst',
          entities: [e],
          createdAt: '2026-09-25T10:00:00Z',
        ),
    ]);
    await pumpEventQueue();
    // The server's copies of the three writes, and another change on each stream.
    _serverChanges = [
      for (final e in writes) ...[
        _change(e.stream, e.entity, e.entityId, e.version!, e.data),
        if (e.entity == 'expense')
          _change(e.stream, 'group', groups[0].entityId, 1, groups[0].data)
        else if (e.entity == 'settlement')
          _change(e.stream, 'group', groups[1].entityId, 1, groups[1].data)
        else
          _change(e.stream, 'profile', data.me, 1, data.entities.firstWhere((x) => x.entity == 'profile').data),
      ],
    ];
    var events = 0;
    final sub = store.watch().skip(1).listen((l) {
      events++;
      OverallBalancesOut.fromJson(l.overallBalances());
      GroupOut.listFromJson(l.groups());
      FeedItem.listFromJson(l.feed());
    });
    final builds = store.ledgerBuilds;
    final s = Stopwatch()..start();
    await engine.pull();
    await pumpEventQueue();
    final ms = _ms(s);
    await sub.cancel();
    expect(store.outbox, isEmpty);
    return (ms, events, store.ledgerBuilds - builds);
  }

  Map<String, dynamic> _change(String stream, String entity, String id, int version, Map<String, dynamic> data) => {
    'stream': stream,
    'seq': ++_seq,
    'action': '$entity.update',
    'entity': entity,
    'entity_id': id,
    'op': 'upsert',
    'version': version,
    'data': data,
    'actor_id': null,
    'acting_admin_id': null,
    'at': '2026-09-25T10:00:00+00:00',
  };

  Future<void> close() async {
    await engine.dispose();
    await store.close();
  }
}

/// The heavy dataset as migration 0013's backfill leaves it: an account for each bank label, the
/// entries that carry one linked to it, and a direction from each entry's type.
List<LocalEntity> _withAccounts(HeavyData data) {
  final user = data.entities.firstWhere((e) => e.entity == 'profile').stream;
  final ids = {for (final label in heavyAccounts) label: smsAccountId(data.me, label)};
  return [
    for (final (i, label) in heavyAccounts.indexed)
      LocalEntity(user, 'personal_account', ids[label]!, 1, {
        'id': ids[label],
        'user_id': data.me,
        'name': label,
        'type': accountTypeForLabel(label).wire,
        'currency': 'INR',
        'opening_balance_minor': 0,
        'sms_label': label,
        'status': 'active',
        'acting_admin_id': null,
        'created_at': DateTime.utc(2021, 1, 1, 0, i).toIso8601String(),
        'updated_at': DateTime.utc(2021, 1, 1, 0, i).toIso8601String(),
        'deleted_at': null,
        'version': 1,
      }),
    for (final e in data.entities)
      if (e.entity == 'personal_transaction')
        LocalEntity(e.stream, e.entity, e.entityId, e.version, {
          ...e.data,
          'account_id': ids[e.data['account']],
          'direction': e.data['type'] == 'income' ? 'in' : 'out',
        })
      else
        e,
  ];
}

/// A device store holding the heavy dataset (or [entities] made from it), every stream at seq 100.
Future<LocalStore> _heavyStore(
  HeavyData data,
  String path, {
  DatabaseFactory? factory,
  List<LocalEntity>? entities,
}) async {
  final store = await LocalStore.open(factory ?? databaseFactoryMemory, path);
  final byStream = <String, List<LocalEntity>>{};
  for (final e in entities ?? data.entities) {
    (byStream[e.stream] ??= []).add(e);
  }
  for (final MapEntry(key: stream, value: entities) in byStream.entries) {
    await store.replaceStream(stream, 100, entities);
  }
  return store;
}

/// The app's writes over a store holding the heavy dataset, signed in as its user, offline (so
/// what's queued stays queued).
class _ImportQueue {
  _ImportQueue._(this.store, this.engine, this.container);

  final LocalStore store;
  final SyncEngine engine;
  final ProviderContainer container;

  static Future<_ImportQueue> start(HeavyData data, {List<LocalEntity>? entities}) async {
    final store = await _heavyStore(data, 'perf-import-${DateTime.now().microsecondsSinceEpoch}', entities: entities);
    final offline = MockClient((req) async => throw http.ClientException('offline', req.url));
    final engine = SyncEngine(
      api: SyncApi(ApiClient(basePath: '')..client = offline),
      store: store,
    );
    final user = UserOut.fromJson(data.entities.firstWhere((e) => e.entity == 'profile').data)!;
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _SignedIn(Session(token: 'perf', user: user))),
        localStoreProvider.overrideWith((ref) async => store),
        syncEngineProvider.overrideWith((ref) async => engine),
      ],
    );
    await container.read(sessionProvider.future);
    return _ImportQueue._(store, engine, container);
  }

  Future<void> close() async {
    container.dispose();
    await engine.dispose();
    await store.close();
  }
}

class _SignedIn extends SessionController {
  _SignedIn(this.session);
  final Session session;

  @override
  Future<Session?> build() async => session;
}
