import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/categorise/category_rules.dart';
import 'package:app/core/local/ledger.dart';
import 'package:app/core/local/personal_index.dart';

import '../perf/heavy_data.dart';

/// The Ledger's indexes (core/local/personal_index.dart and the caches in ledger.dart) against
/// straightforward versions of the same rules, on a generated dataset (test/perf/heavy_data.dart,
/// smaller). test/core/local_parity_test.dart checks the views against the API's answers.
void main() {
  late HeavyData data;
  late List<LocalEntity> entities;
  late Ledger ledger;

  /// Who the newest payment from "TIED UP LTD" was with (see [_ties]).
  late String tiedFriend;
  final today = DateTime(2026, 9, 25);

  setUpAll(() {
    data = buildHeavyData(groups: 8, expenses: 1200, settlements: 120, personal: 4000);
    final (ties, friend) = _ties(data);
    entities = [...data.entities, ...ties];
    tiedFriend = friend;
    ledger = Ledger(entities, today: today);
  });

  group('isoMicros, dayKey', () {
    test('daysApart counts calendar days, daylight saving or not (ISS-074)', () {
      // 8 March 2026 is a 23-hour day in the US: local midnights 7 → 9 March are 47 hours.
      expect(daysApart(20260307, 20260309), 2);
      expect(daysApart(20260309, 20260307), 2);
      expect(daysApart(20261031, 20261101), 1);
      expect(daysApart(20261231, 20270101), 1);
      expect(daysApart(20240228, 20240301), 2); // a leap year
      expect(dayKeyOf(DateTime(2026, 9, 5, 23, 59)), 20260905);
    });

    test('read times exactly as DateTime.parse does', () {
      final r = Random(3);
      String two(int n) => n.toString().padLeft(2, '0');
      final times = <String>[
        for (final e in data.entities) ...[
          if (e.data['created_at'] case final String t) t,
          if (e.data['sms_at'] case final String t) t,
        ],
        '2026-09-24T10:00:00Z',
        '2026-09-24T10:00:00.000Z', // toIso8601String
        '2026-09-24T10:00:00.123456+00:00',
        '2026-09-24T10:00:00.1234567891+05:30', // digits after the sixth are dropped
        '2026-09-24 10:00:00-03:00',
        '2026-09-24T10:00:00', // local time
        '2026-09-24T10:00:00.5',
        '2026-13-40T25:61:61Z', // rolls over
        '2026-09-24T10:00Z', // not the usual shape: DateTime.parse reads it
        '2026-09-24',
        '20260924T100000Z',
        '+2026-09-24T10:00:00Z',
        for (var i = 0; i < 2000; i++)
          '${1990 + r.nextInt(50)}-${two(1 + r.nextInt(12))}-${two(1 + r.nextInt(31))}'
              '${r.nextBool() ? 'T' : ' '}${two(r.nextInt(24))}:${two(r.nextInt(60))}:${two(r.nextInt(60))}'
              '${r.nextBool() ? '' : '.${'${r.nextInt(1000000000)}'.padLeft(9, '0').substring(0, 1 + r.nextInt(9))}'}'
              '${switch (r.nextInt(4)) {
                0 => 'Z',
                1 => '',
                _ => '${r.nextBool() ? '+' : '-'}${two(r.nextInt(14))}:${two(r.nextBool() ? 0 : 30)}',
              }}',
      ];
      for (final t in times) {
        expect(isoMicros(t), DateTime.parse(t).microsecondsSinceEpoch, reason: t);
      }
      expect(isoMicros(null), 0);
    });

    test('dayKey and localDay give the day DateTime.parse reads', () {
      for (final d in ['2026-09-24', '2024-02-29', '2026-01-01', '1999-12-31', '2026-09-24T10:00:00']) {
        final parsed = DateTime.parse(d);
        expect(dayKey(d), parsed.year * 10000 + parsed.month * 100 + parsed.day, reason: d);
      }
      // A day that doesn't exist is kept as written; localDay rolls it over as DateTime.parse does.
      expect(dayKey('2026-02-30'), 20260230);
      expect(localDay(dayKey('2026-02-30')), DateTime.parse('2026-02-30'));
      for (final e in data.entities) {
        if (e.entity == 'personal_transaction') {
          final d = e.data['date'] as String;
          expect(localDay(dayKey(d)), DateTime.parse(d), reason: d);
        }
      }
    });
  });

  group('learnedCategory', () {
    test('gives what a scan of every rule, entry and split gives', () {
      final withoutRules = [
        for (final e in entities)
          if (e.entity != 'category_rule') e,
      ];
      final noRules = Ledger(withoutRules, today: today);
      final texts = <String>{
        for (final e in entities)
          if (e.entity == 'personal_transaction' || e.entity == 'expense') ...[
            if (e.data['merchant'] case final String m) m,
            e.data['description'] as String,
          ],
        for (final e in entities)
          if (e.entity == 'category_rule') e.data['pattern'] as String,
      }.toList()..sort();
      final r = Random(9);
      final picks = <String>{
        for (var i = 0; i < 250; i++) texts[r.nextInt(texts.length)],
        for (var i = 0; i < 40; i++)
          () {
            final t = texts[r.nextInt(texts.length)];
            return t.substring(0, 1 + r.nextInt(t.length));
          }(),
        'Pottery',
        'Tied up',
        'TIED UP LTD',
        '',
        '  ',
        'zomato',
        'ZOMATO LIMITED',
        'Zomato o',
      }.toList();
      final mismatches = <String>[];
      var answered = 0;
      for (final (name, l, all) in [('with rules', ledger, entities), ('without rules', noRules, withoutRules)]) {
        final reference = _ReferenceLearned(l, all);
        for (final (i, text) in picks.indexed) {
          final merchant = picks[(i * 7 + 3) % picks.length];
          for (final scope in ['personal', 'group']) {
            for (final income in [false, true]) {
              for (final (t, m) in [(text, null), ('Paid', text), (text, merchant)]) {
                final got = l.learnedCategory(t, merchant: m, scope: scope, income: income);
                final want = reference.learned(t, merchant: m, scope: scope, income: income);
                if (got != null) answered++;
                if (got != want) mismatches.add('$name, $scope, income $income, "$t" from "$m": $got, not $want');
              }
            }
          }
        }
      }
      expect(mismatches, isEmpty);
      expect(answered, greaterThan(1000)); // the data does teach something
    });

    test('as plain maps (learnedCategories) gives what it gives', () {
      final texts = <String>{
        for (final e in entities)
          if (e.entity == 'personal_transaction' || e.entity == 'expense') ...[
            if (e.data['merchant'] case final String m) m,
            e.data['description'] as String,
          ],
        'Tied up',
        'Pottery',
        '',
        'zomato',
      }.toList()..sort();
      final tables = {
        for (final scope in ['personal', 'group']) scope: ledger.learnedCategories(scope),
      };
      final mismatches = <String>[];
      for (final (i, text) in texts.indexed) {
        final merchant = i.isEven ? null : texts[(i * 7) % texts.length];
        for (final scope in ['personal', 'group']) {
          for (final income in [false, true]) {
            final keys = {merchantKey(merchant), merchantKey(text)}..remove('');
            final got = tables[scope]!.lookup(keys, income: income);
            final want = ledger.learnedCategory(text, merchant: merchant, scope: scope, income: income);
            if (got != want) mismatches.add('$scope, income $income, "$text" from "$merchant": $got, not $want');
          }
        }
      }
      expect(mismatches, isEmpty);
    });
  });

  group('reading bank SMS', () {
    const all = 1 << 30;
    List<Json> items(Json list) => (list['items'] as List).cast<Json>();

    test('a notification finds its entry by reference, or by account, merchant and amount', () {
      final live = items(ledger.personalList(limit: all));
      final r = Random(12);
      final rows = [
        for (final e in entities)
          if (e.entity == 'personal_transaction') e.data,
      ];
      var byReference = 0, byPayment = 0;
      for (var i = 0; i < 400; i++) {
        final t = rows[r.nextInt(rows.length)];
        final type = r.nextInt(5) == 0 ? (t['type'] == 'income' ? 'expense' : 'income') : t['type'] as String;
        if (t['reference'] case final String reference) {
          final want = live.where((x) => x['reference'] == reference && x['type'] == type).firstOrNull?['id'];
          expect(ledger.personalWithReference(reference, type), want, reason: '$reference $type');
          if (want != null) byReference++;
        }
        final account = r.nextInt(4) == 0 ? null : t['account'] as String?;
        final merchant = r.nextInt(6) == 0 ? 'NOBODY' : t['merchant'] as String?;
        final amount = r.nextInt(6) == 0 ? 4200 : t['amount_minor'] as int;
        final want = items(
          ledger.personalList(account: account, type: type, limit: all),
        ).where((x) => x['merchant'] == merchant && x['amount_minor'] == amount).firstOrNull?['id'];
        expect(
          ledger.personalPaid(type: type, amount: amount, account: account, merchant: merchant),
          want,
          reason: '$type $amount $account $merchant',
        );
        if (want != null) byPayment++;
      }
      expect(byReference, greaterThan(100));
      expect(byPayment, greaterThan(100));
    });

    test('the ids, references and manual entries a scan gets', () {
      expect(ledger.personalIds(), {
        for (final e in entities)
          if (e.entity == 'personal_transaction') e.data['id'],
      });
      final r = Random(13);
      final live = items(ledger.personalList(limit: all));
      final candidates = ledger.manualCandidates();
      for (var i = 0; i < 200; i++) {
        final t = live[r.nextInt(live.length)];
        final key = (t['type'] as String, t['amount_minor'] as int);
        final want = [
          for (final x in live)
            if (x['source'] == 'manual' && x['account'] == null && (x['type'], x['amount_minor']) == key)
              (x['id'] as String, dayKey(x['date'] as String)),
        ];
        expect(candidates[key] ?? const [], want);
      }
    });
  });

  group('personal views', () {
    const all = 1 << 30;
    List<Json> items(Json list) => (list['items'] as List).cast<Json>();

    test('every filter and date range lists what filtering the whole list would', () {
      final everything = {
        for (final d in [false, true]) d: items(ledger.personalList(deleted: d, limit: all)),
      };
      final dates = [for (final t in everything[false]!) t['date'] as String]..sort();
      final r = Random(4);
      String? someDate() => switch (r.nextInt(5)) {
        0 => null,
        1 => '2020-01-01',
        _ => dates[r.nextInt(dates.length)],
      };
      final accounts = {for (final t in everything[false]!) t['account']}.whereType<String>().toList();
      for (var i = 0; i < 300; i++) {
        final deleted = r.nextInt(5) == 0;
        final start = someDate(), end = someDate();
        final type = r.nextBool() ? null : (r.nextBool() ? 'expense' : 'income');
        final keys = r.nextBool()
            ? null
            : [
                for (final k in ['food', 'transport', 'income', 'pets'])
                  if (r.nextBool()) k,
              ];
        final account = r.nextInt(3) == 0 ? accounts[r.nextInt(accounts.length)] : null;
        final channel = r.nextInt(4) == 0 ? 'upi' : null;
        final source = r.nextInt(4) == 0 ? (r.nextBool() ? 'sms' : 'manual') : null;
        final reviewed = r.nextInt(4) == 0 ? r.nextBool() : null;
        final offset = r.nextInt(3) == 0 ? r.nextInt(50) : 0;
        final limit = r.nextBool() ? 100 : 1 + r.nextInt(30);
        final got = ledger.personalList(
          deleted: deleted,
          start: start,
          end: end,
          type: type,
          categoryKeys: keys,
          account: account,
          channel: channel,
          source: source,
          reviewed: reviewed,
          offset: offset,
          limit: limit,
        );
        final want = [
          for (final t in everything[deleted]!)
            if ((start == null || (t['date'] as String).compareTo(start) >= 0) &&
                (end == null || (t['date'] as String).compareTo(end) <= 0) &&
                (type == null || t['type'] == type) &&
                (keys == null || keys.isEmpty || keys.contains((t['category'] as Map?)?['key'])) &&
                (account == null || t['account'] == account) &&
                (channel == null || t['channel'] == channel) &&
                (source == null || t['source'] == source) &&
                (reviewed == null || t['reviewed'] == reviewed))
              t,
        ];
        int sum(String kind) => [
          for (final t in want)
            if (t['type'] == kind && t['currency'] == 'INR' && t['counted'] == true) t['amount_minor'] as int,
        ].fold(0, (a, b) => a + b);
        final what = 'deleted $deleted, $start to $end, $type, $keys, $account, $channel, $source, $reviewed';
        expect(got['count'], want.length, reason: what);
        expect(items(got), want.skip(offset).take(limit).toList(), reason: what);
        expect((got['spent_minor'], got['income_minor']), (sum('expense'), sum('income')), reason: what);
      }
      for (final t in [...everything[false]!.take(50), ...everything[true]!.take(20)]) {
        expect(ledger.personalTransaction(t['id']), t);
        expect(ledger.rawPersonal(t['id'])!['id'], t['id']);
      }
    });

    test('the live list is in the API order', () {
      final list = items(ledger.personalList(limit: all));
      for (var i = 1; i < list.length; i++) {
        final a = list[i - 1], b = list[i];
        final d = (b['date'] as String).compareTo(a['date'] as String);
        final t = DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at']));
        expect(d < 0 || (d == 0 && (t < 0 || (t == 0 && (b['id'] as String).compareTo(a['id']) < 0))), isTrue);
      }
    });

    test('accounts: the newest entry and the newest reported balance of each', () {
      final list = items(ledger.personalList(limit: all));
      int at(Json t) => DateTime.parse(t['sms_at'] ?? t['created_at']).microsecondsSinceEpoch;
      int when(Json a, Json b) {
        final c = at(a).compareTo(at(b));
        if (c != 0) return c;
        final m = DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at']));
        return m != 0 ? m : (a['id'] as String).compareTo(b['id']);
      }

      final byAccount = <String, List<Json>>{};
      for (final t in list) {
        if (t['account'] case final String a) (byAccount[a] ??= []).add(t);
      }
      Json latest(Iterable<Json> rows) => rows.reduce((a, b) => when(a, b) >= 0 ? a : b);
      final want =
          [
            for (final MapEntry(key: name, value: rows) in byAccount.entries)
              () {
                final reported = rows.where((t) => t['balance_minor'] != null);
                final r = reported.isEmpty ? null : latest(reported);
                return (
                  latest(rows),
                  {
                    'account': name,
                    'currency': latest(rows)['currency'],
                    'balance_minor': r?['balance_minor'],
                    'balance_at': r == null ? null : r['sms_at'] ?? r['created_at'],
                    'count': rows.length,
                  },
                );
              }(),
          ]..sort((a, b) {
            final t = when(b.$1, a.$1);
            return t != 0 ? t : (a.$2['account'] as String).compareTo(b.$2['account']);
          });
      expect(ledger.personalReportedAccounts(), [for (final (_, a) in want) a]);
    });

    test('manualMatch: the newest manual entry without an account, a day either side', () {
      final list = items(ledger.personalList(limit: all));
      final r = Random(6);
      final manual = [
        for (final t in list)
          if (t['source'] == 'manual' && t['account'] == null) t,
      ];
      var found = 0;
      for (var i = 0; i < 300; i++) {
        final probe = manual[r.nextInt(manual.length)];
        final d = DateTime.parse(probe['date']);
        final day = DateTime(d.year, d.month, d.day + r.nextInt(5) - 2, 18);
        final type = probe['type'] as String, amount = probe['amount_minor'] as int;
        final want = manual.where(
          (t) =>
              t['type'] == type &&
              t['amount_minor'] == amount &&
              DateTime.parse(t['date']).difference(DateTime(day.year, day.month, day.day)).inDays.abs() <= 1,
        );
        final got = ledger.manualMatch(type, amount, day);
        expect(got, want.firstOrNull, reason: '$type $amount $day');
        if (got != null) found++;
      }
      expect(found, greaterThan(100));
    });

    test('friendPaidBefore: the newest payment from that merchant; of two made at once, the first synced', () {
      expect(ledger.friendPaidBefore('TIED UP LTD'), tiedFriend);
    });

    test('personalReferences is a copy', () {
      final refs = ledger.personalReferences()..add('x|expense');
      expect(ledger.personalReferences(), isNot(contains('x|expense')));
      expect(refs.length, ledger.personalReferences().length + 1);
    });
  });

  group('feed', () {
    test('a page is the slice of the whole feed', () {
      final r = Random(8);
      final groups = [null, ...ledger.groups().map((g) => g['id'] as String)];
      for (var i = 0; i < 60; i++) {
        final groupId = groups[r.nextInt(groups.length)];
        final deleted = r.nextInt(6) == 0;
        final filters = FeedFilters(
          openOnly: r.nextInt(3) == 0,
          category: r.nextInt(4) == 0 ? 'food' : null,
          search: r.nextInt(4) == 0 ? ['din', 'a', 'Rahul'][r.nextInt(3)] : null,
          start: r.nextInt(4) == 0 ? '2024-01-01' : null,
        );
        final whole = ledger.feed(groupId: groupId, deleted: deleted, filters: filters, limit: 1 << 30);
        for (final (offset, limit) in [(0, 30), (r.nextInt(80), 1 + r.nextInt(40)), (0, 0), (whole.length, 10)]) {
          final end = min(offset + limit, whole.length);
          expect(
            ledger.feed(groupId: groupId, deleted: deleted, filters: filters, offset: offset, limit: limit),
            offset >= whole.length ? isEmpty : whole.sublist(offset, end),
          );
        }
      }
    });
  });
}

/// Rows that tie: two manual entries and two splits with the same words made at the same moment,
/// and two payments from one merchant made at once. Added after everything else, so the first of
/// each pair is the first synced. Also returns who the first payment was with.
(List<LocalEntity>, String) _ties(HeavyData data) {
  final me = data.me;
  final user = 'user:$me';
  final categories = [
    for (final e in data.entities)
      if (e.entity == 'category' && e.data['owner_id'] == null && e.data['scope'] == 'all') e.data['id'] as String,
  ];
  final group = data.entities.firstWhere((e) => e.entity == 'group');
  final payments = [
    for (final e in data.entities)
      if (e.entity == 'settlement' &&
          e.data['deleted_at'] == null &&
          (e.data['from_user'] == me || e.data['to_user'] == me))
        e.data,
  ];
  Json entry(String id, String category, {String? settlement}) => {
    'id': id,
    'user_id': me,
    'type': 'expense',
    'amount_minor': 4200,
    'currency': 'INR',
    'category_id': category,
    'date': '2026-09-20',
    'description': 'Tied up',
    'merchant': settlement == null ? null : 'TIED UP LTD',
    'source': 'manual',
    'reviewed': true,
    'settlement_id': settlement,
    'created_at': '2026-09-20T10:00:00+00:00',
    'deleted_at': null,
  };
  Json split(String id, String category) => {
    'id': id,
    'group_id': group.entityId,
    'description': 'Tied up',
    'amount_minor': 4200,
    'currency': 'INR',
    'payer_id': me,
    'date': '2026-09-20',
    'category_id': category,
    'created_by': me,
    'created_at': '2026-09-20T10:00:00+00:00',
    'deleted_at': null,
    'splits': [
      {'user_id': me, 'share_minor': 4200, 'input_value': null},
    ],
  };
  final s1 = payments[0], s2 = payments[1];
  return (
    [
      LocalEntity(user, 'personal_transaction', 'tie-a', 1, entry('tie-a', categories[0])),
      LocalEntity(user, 'personal_transaction', 'tie-b', 1, entry('tie-b', categories[1])),
      LocalEntity(
        user,
        'personal_transaction',
        'tie-c',
        1,
        entry('tie-c', categories[2], settlement: s1['id'] as String),
      ),
      LocalEntity(
        user,
        'personal_transaction',
        'tie-d',
        1,
        entry('tie-d', categories[3], settlement: s2['id'] as String),
      ),
      LocalEntity(group.stream, 'expense', 'tie-e', 1, split('tie-e', categories[1])),
      LocalEntity(group.stream, 'expense', 'tie-f', 1, split('tie-f', categories[0])),
    ],
    (s1['from_user'] == me ? s1['to_user'] : s1['from_user']) as String,
  );
}

/// Ledger.learnedCategory written the plain way: scan everything, sort what matches.
class _ReferenceLearned {
  _ReferenceLearned(this.ledger, this.entities);

  final Ledger ledger;
  final List<LocalEntity> entities;
  final _keys = <String?, String>{};

  String _key(String? text) => _keys[text] ??= merchantKey(text);

  /// Newest first by [field]; ties stay in the order synced.
  static List<Json> _newestFirst(List<Json> rows, String field) {
    final order = [for (final (i, row) in rows.indexed) (row, DateTime.parse(row[field] as String), i)]
      ..sort((a, b) {
        final t = b.$2.compareTo(a.$2);
        return t != 0 ? t : a.$3.compareTo(b.$3);
      });
    return [for (final (row, _, _) in order) row];
  }

  String? learned(String text, {String? merchant, required String scope, bool income = false}) {
    final keys = {_key(merchant), _key(text)}..remove('');
    if (keys.isEmpty) return null;
    final offered = ledger.categories(scope: scope);
    String? usable(Object? categoryId) {
      if (categoryId == null) return null;
      if (offered.any((c) => c['id'] == categoryId)) return categoryId as String;
      final key = ledger.rawCategory(categoryId as String)?['key'];
      if (key == null) return null;
      return (offered.where((c) => c['key'] == key && c['owner_id'] == null).firstOrNull ??
              offered.where((c) => c['key'] == key).firstOrNull)?['id']
          as String?;
    }

    bool same(Json row) =>
        keys.contains(_key(row['merchant'] as String?)) || keys.contains(_key(row['description'] as String?));
    final rules = _newestFirst([
      for (final e in entities)
        if (e.entity == 'category_rule' &&
            e.data['income'] == income &&
            keys.contains(_key(e.data['pattern'] as String?)))
          e.data,
    ], 'updated_at');
    final chosen = scope == 'personal'
        ? _newestFirst([
            for (final e in entities)
              if (e.entity == 'personal_transaction' &&
                  e.data['deleted_at'] == null &&
                  (e.data['source'] ?? 'manual') == 'manual' &&
                  (e.data['type'] == 'income') == income &&
                  same(e.data))
                e.data,
          ], 'created_at')
        : _newestFirst([
            for (final e in entities)
              if (e.entity == 'expense' &&
                  e.data['deleted_at'] == null &&
                  e.data['created_by'] == ledger.me &&
                  same(e.data))
                e.data,
          ], 'created_at');
    for (final row in [...rules, ...chosen]) {
      if (usable(row['category_id']) case final id?) return id;
    }
    return null;
  }
}
