/// Offline writes end to end against a real API (see sync_live_test.dart for how to run it
/// against a throwaway database; it WRITES to the server).
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sembast/sembast_memory.dart';
import 'package:app/core/api/api.dart';
import 'package:app/core/local/outbox.dart';
import 'package:app/core/local/providers.dart';
import 'package:app/core/local/writes.dart';
import 'package:app/core/session/session.dart';

final _base = Platform.environment['LIVE_API'];

/// A real HTTP client with an off switch.
class _Flaky extends http.BaseClient {
  final _inner = http.Client();
  bool offline = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (offline) throw http.ClientException('Network is unreachable', request.url);
    return _inner.send(request);
  }
}

class _Tokens extends TokenStore {
  _Tokens(this.token);
  String? token;
  UserOut? user;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
  @override
  Future<UserOut?> readUser() async => user;
  @override
  Future<void> writeUser(UserOut u) async => user = u;
}

Future<String> _login(String email) async {
  final r = await http.post(
    Uri.parse('$_base/api/v1/auth/login'),
    headers: {'content-type': 'application/json'},
    body: jsonEncode({'email': email, 'password': Platform.environment['SEED_PASSWORD'] ?? ''}),
  );
  return (jsonDecode(r.body) as Map)['access_token'] as String;
}

Future<dynamic> _api(String token, String method, String path, [Object? body]) async {
  final req = http.Request(method, Uri.parse('$_base/api/v1$path'))
    ..headers.addAll({'authorization': 'Bearer $token', 'content-type': 'application/json'});
  if (body != null) req.body = jsonEncode(body);
  final r = await http.Response.fromStream(await http.Client().send(req));
  expect(r.statusCode, lessThan(300), reason: '$method $path → ${r.body}');
  return r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
}

void main() {
  test('offline edit, a conflict, keep mine, an offline create sent once', () async {
    final john = await _login('admin@example.com');
    final rahul = await _login('rahul.sharma@example.com');
    final net = _Flaky();
    final container = ProviderContainer(overrides: [
      savedApiOriginProvider.overrideWithValue(_base),
      httpClientProvider.overrideWithValue(net),
      tokenStoreProvider.overrideWithValue(_Tokens(john)),
      localDatabaseFactoryProvider.overrideWithValue(databaseFactoryMemory),
      localDatabasePathProvider.overrideWithValue((u) async => 'live-outbox-$u'),
      syncIntervalProvider.overrideWithValue(null),
      syncOnResumeProvider.overrideWithValue(false),
    ]);
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);
    final engine = await container.read(syncEngineProvider.future);
    final store = await container.read(localStoreProvider.future);
    await engine.pull();
    final writes = container.read(writesProvider);

    final goa = store.ledger.groups().firstWhere((g) => g['name'] == 'Goa Trip');
    final item = store.ledger.feed(groupId: goa['id'], limit: 100).firstWhere((i) => i['title'] == 'Late-night pizza');
    final pizza = store.ledger.expense(item['id']);
    ExpenseIn edit(String description) => ExpenseIn(
      description: description,
      amountMinor: pizza['amount_minor'],
      payerId: pizza['payer']['id'],
      date: DateTime.utc(2026, 9, 17),
      split: SplitIn(method: 'equal', inputs: [for (final s in pizza['splits']) SplitInputIn(userId: s['user']['id'])]),
    );

    // Offline: an edit and a new expense, shown straight away.
    net.offline = true;
    await writes.updateExpense(pizza['id'], edit('Pizza (John, offline)'));
    final snackId = await writes.createExpense(goa['id'], edit('Offline snack'));
    await expectLater(engine.pull(), throwsA(isA<ApiException>()));
    expect(store.ledger.expense(pizza['id'])['description'], 'Pizza (John, offline)');
    expect(store.ledger.expense(snackId)['description'], 'Offline snack');

    // Meanwhile Rahul edits the same expense.
    final server = await _api(rahul, 'GET', '/expenses/${pizza['id']}');
    await _api(rahul, 'PUT', '/expenses/${pizza['id']}', {
      ...jsonDecode(jsonEncode(edit('Pizza (Rahul)').toJson())) as Map,
      'date': '2026-09-17',
      'version': server['version'],
    });

    // Back online: the edit conflicts, the create goes through.
    net.offline = false;
    await engine.pull();
    final ops = store.outbox;
    final conflict = ops.singleWhere((o) => o.status == OutboxStatus.rejected);
    expect(conflict.code, 'version_conflict');
    expect(store.ledger.expense(pizza['id'])['description'], 'Pizza (Rahul)');
    expect((await _api(john, 'GET', '/expenses/$snackId'))['description'], 'Offline snack');

    // Keep mine: sent again on top of Rahul's version.
    await writes.keepMine(conflict);
    await engine.pull();
    await engine.pull();
    expect((await _api(john, 'GET', '/expenses/${pizza['id']}'))['description'], 'Pizza (John, offline)');
    expect(store.ledger.expense(pizza['id'])['description'], 'Pizza (John, offline)');
    expect(store.outbox, isEmpty);

    // The offline create exists exactly once on the server.
    final feed = await _api(john, 'GET', '/feed?group_id=${goa['id']}&limit=100') as List;
    expect(feed.where((i) => i['title'] == 'Offline snack').length, 1);
    // And the device agrees with the server.
    expect(
      jsonDecode(jsonEncode(OverallBalancesOut.fromJson(store.ledger.overallBalances()))),
      jsonDecode(jsonEncode(OverallBalancesOut.fromJson(await _api(john, 'GET', '/balances')))),
    );
  }, skip: _base == null ? 'set LIVE_API to run against a real server' : false, timeout: const Timeout(Duration(minutes: 2)));
}
