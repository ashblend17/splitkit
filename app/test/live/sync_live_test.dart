/// End to end against a real API: sync into a fresh local store, compare every local answer with
/// the API's, make real writes as two users, sync again (incrementally) and compare again.
///
/// Skipped unless LIVE_API is set. It WRITES to that server, so point it at a throwaway,
/// freshly seeded database, never the dev one, e.g.:
///   DATABASE_URL=…/DB_NAME_fixtures uv run python -m app.seed --reset   (in api/)
///   DATABASE_URL=…/DB_NAME_fixtures uv run uvicorn app.main:app --port 8001
///   LIVE_API=http://localhost:8001 SEED_PASSWORD=… flutter test test/live
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sembast/sembast_memory.dart';
import 'package:app/core/api/api.dart';
import 'package:app/core/local/ledger.dart';
import 'package:app/core/local/store.dart';
import 'package:app/core/local/sync_engine.dart';

final _base = Platform.environment['LIVE_API'];
var _n = 0;

class LiveApi {
  LiveApi(this.token);
  final String token;
  final http.Client _http = http.Client();

  static Future<LiveApi> login(String email) async {
    final r = await http.post(
      Uri.parse('$_base/api/v1/auth/login'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'email': email, 'password': Platform.environment['SEED_PASSWORD'] ?? ''}),
    );
    expect(r.statusCode, 200, reason: r.body);
    return LiveApi((jsonDecode(r.body) as Map)['access_token'] as String);
  }

  Future<dynamic> call(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$_base/api/v1$path'))
      ..headers.addAll({'authorization': 'Bearer $token', 'content-type': 'application/json'});
    if (body != null) req.body = jsonEncode(body);
    final r = await http.Response.fromStream(await _http.send(req));
    expect(r.statusCode, lessThan(300), reason: '$method $path → ${r.body}');
    return r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
  }

  Future<(SyncEngine, LocalStore)> device() async {
    final store = await LocalStore.open(databaseFactoryMemory, 'live-${_n++}');
    final client = ApiClient(basePath: _base!)..addDefaultHeader('Authorization', 'Bearer $token');
    return (SyncEngine(api: SyncApi(client), store: store), store);
  }
}

Object? _norm(Object? model) => jsonDecode(jsonEncode(model));

/// Every local view against the API's answer for the same question.
Future<void> expectParity(LiveApi api, Ledger l) async {
  Future<void> same(String path, Object? mine, Object? Function(dynamic) parse) async {
    final theirs = await api.call('GET', path);
    expect(_norm(parse(mine)), _norm(parse(theirs)), reason: path);
  }

  await same('/me', l.userOut(), UserOut.fromJson);
  await same('/groups', l.groups(), GroupOut.listFromJson);
  await same('/balances', l.overallBalances(), OverallBalancesOut.fromJson);
  await same('/feed?limit=100', l.feed(limit: 100), FeedItem.listFromJson);
  await same('/feed?deleted=true&limit=100', l.feed(deleted: true, limit: 100), FeedItem.listFromJson);
  await same('/categories', l.categories(), CategoryOut.listFromJson);
  for (final g in l.groups()) {
    final id = g['id'];
    await same('/groups/$id/balances', l.groupBalances(id), GroupBalancesOut.fromJson);
    for (final item in l.feed(groupId: id, limit: 100)) {
      if (item['kind'] == 'expense') await same('/expenses/${item['id']}', l.expense(item['id']), ExpenseOut.fromJson);
    }
  }
  for (final f in (l.overallBalances()['friends'] as List)) {
    final id = f['user']['id'];
    await same('/friends/$id/settle-up?currency=${f['currency']}', l.settleUpPlan(id, currency: f['currency']), SettleUpPlanOut.fromJson);
  }
  await same('/personal/summary?month=2026-09-01', l.personalSummary(DateTime(2026, 9)), PersonalSummaryOut.fromJson);
  await same('/personal/transactions?limit=500', l.personalList(limit: 500), PersonalListOut.fromJson);
}

void main() {
  test('sync, write, sync again: the device matches the server', () async {
    final john = await LiveApi.login('admin@example.com');
    final rahul = await LiveApi.login('rahul.sharma@example.com');
    final (engine, store) = await john.device();
    await engine.pull();
    await expectParity(john, store.ledger);

    final goa = (await john.call('GET', '/groups') as List).firstWhere((g) => g['name'] == 'Goa Trip');
    final members = {for (final m in goa['members']) m['user']['name']: m['user']['id']};
    final me = members['John Doe'], rahulId = members['Rahul Sharma'];

    // Writes by both users: create, edit (with version), delete, restore, settle, personal.
    final e = await rahul.call('POST', '/groups/${goa['id']}/expenses', {
      'description': 'Live test dinner',
      'amount_minor': 100001,
      'payer_id': rahulId,
      'date': '2026-09-24',
      'split': {'method': 'equal', 'inputs': [for (final id in members.values) {'user_id': id}]},
    });
    final edited = await john.call('PUT', '/expenses/${e['id']}', {
      'version': e['version'],
      'description': 'Live test dinner (edited)',
      'amount_minor': 90000,
      'payer_id': rahulId,
      'date': '2026-09-24',
      'split': {'method': 'shares', 'inputs': [{'user_id': me, 'value': '2'}, {'user_id': rahulId, 'value': '1'}]},
    });
    await john.call('DELETE', '/expenses/${e['id']}?version=${edited['version']}');
    await rahul.call('POST', '/expenses/${e['id']}/restore');
    final s = await john.call('POST', '/groups/${goa['id']}/settlements', {
      'from_user': me, 'to_user': rahulId, 'amount_minor': 12345, 'date': '2026-09-25', 'method': 'cash',
    });
    await john.call('DELETE', '/settlements/${s['id']}');
    await john.call('POST', '/personal/transactions', {
      'type': 'expense', 'amount_minor': 4200, 'description': 'Live test coffee', 'date': '2026-09-25',
    });
    final me0 = await rahul.call('GET', '/me');
    await rahul.call('PATCH', '/me', {'version': me0['version'], 'name': 'Rahul S.'});

    final before = Map.of(store.cursors);
    await engine.pull();
    expect(store.cursors['group:${goa['id']}']!, greaterThan(before['group:${goa['id']}']!), reason: 'incremental, not a snapshot');
    await expectParity(john, store.ledger);
    expect(store.ledger.expense(e['id'])['description'], 'Live test dinner (edited)');

    // A fresh device (snapshots only) ends in exactly the same state.
    final (fresh, freshStore) = await john.device();
    await fresh.pull();
    expect(_norm(OverallBalancesOut.fromJson(freshStore.ledger.overallBalances())), _norm(OverallBalancesOut.fromJson(store.ledger.overallBalances())));
    expect(_norm(FeedItem.listFromJson(freshStore.ledger.feed(limit: 100))), _norm(FeedItem.listFromJson(store.ledger.feed(limit: 100))));
    expect(_norm(GroupOut.listFromJson(freshStore.ledger.groups())), _norm(GroupOut.listFromJson(store.ledger.groups())));
  }, skip: _base == null ? 'set LIVE_API to run against a real server' : false, timeout: const Timeout(Duration(minutes: 2)));
}
