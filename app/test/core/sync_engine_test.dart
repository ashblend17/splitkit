import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/local/store.dart';
import 'package:splitkit/core/local/sync_engine.dart';

import '../fake_backend.dart';

var _n = 0;

Future<(SyncEngine, LocalStore, FakeBackend, String)> _setup([FakeBackend? backend]) async {
  final be = backend ?? FakeBackend();
  final path = 'sync-test-${_n++}';
  final store = await LocalStore.open(databaseFactoryMemory, path);
  final client = ApiClient(basePath: '')..client = be.client;
  return (SyncEngine(api: SyncApi(client), store: store), store, be, path);
}

String _goaStream(FakeBackend be) => 'group:${be.goa['id']}';

Map<String, dynamic> _change(int seq, String action, String entity, String id, String op, [Map<String, dynamic>? data]) => {
  'seq': seq,
  'action': action,
  'entity': entity,
  'entity_id': id,
  'op': op,
  'version': 2,
  'data': data,
  'actor_id': null,
  'acting_admin_id': null,
  'at': '2026-09-25T10:00:00+00:00',
};

void main() {
  test('first sync loads every stream from snapshots', () async {
    final (engine, store, be, _) = await _setup();
    await engine.pull();
    expect(store.cursors.keys.toSet(), be.snapshots.keys.toSet());
    expect(store.ledger.groups().map((g) => g['name']), ['Goa Trip', 'Flatmates']);
    expect(engine.status.offline, isFalse);
    expect(engine.status.lastSyncedAt, isNotNull);
  });

  test('later syncs apply changes in order and move the cursor', () async {
    final (engine, store, be, _) = await _setup();
    await engine.pull();
    final stream = _goaStream(be);
    final head = store.cursors[stream]!;
    final dinner = Map<String, dynamic>.from(store.ledger.rawExpense(be.dinnerId)!);
    be.pendingChanges[stream] = [
      _change(head + 1, 'expense.update', 'expense', be.dinnerId, 'upsert', {...dinner, 'description': 'Dinner (edited)', 'version': 2}),
      _change(head + 2, 'expense.delete', 'expense', be.dinnerId, 'upsert', {...dinner, 'description': 'Dinner (edited)', 'deleted_at': '2026-09-25T10:00:00+00:00', 'version': 3}),
    ];
    await engine.pull();
    expect(store.cursors[stream], head + 2);
    expect(store.ledger.expense(be.dinnerId)['description'], 'Dinner (edited)');
    expect(store.ledger.feed(groupId: be.goa['id']).map((i) => i['id']), isNot(contains(be.dinnerId)));
    expect(store.ledger.feed(groupId: be.goa['id'], deleted: true).map((i) => i['id']), contains(be.dinnerId));
    // Group activity moves forward with the change time.
    expect(store.ledger.group(be.goa['id'])['last_activity_at'], '2026-09-25T10:00:00+00:00');
  });

  test('a tombstone removes the entity', () async {
    final (engine, store, be, _) = await _setup();
    await engine.pull();
    final stream = _goaStream(be);
    be.pendingChanges[stream] = [_change(store.cursors[stream]! + 1, 'expense.purge', 'expense', be.dinnerId, 'delete')];
    await engine.pull();
    expect(store.ledger.rawExpense(be.dinnerId), isNull);
  });

  test('a stream you lose access to is dropped', () async {
    final (engine, store, be, _) = await _setup();
    await engine.pull();
    final stream = _goaStream(be);
    be.snapshots.remove(stream);
    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/sync') {
        return http.Response(jsonEncode({
          'streams': [
            {'stream': stream, 'status': 'gone', 'head_seq': 0, 'changes': [], 'has_more': false},
          ],
        }), 200);
      }
      return be.client.send(req).then(http.Response.fromStream);
    });
    final gone = SyncEngine(api: SyncApi(ApiClient(basePath: '')..client = client), store: store);
    await gone.pull();
    expect(store.cursors.containsKey(stream), isFalse);
    expect(() => store.ledger.group(be.goa['id']), throwsA(anything));
  });

  test('pages: keeps asking while a stream has more', () async {
    final (_, store, be, _) = await _setup();
    await SyncEngine(api: SyncApi(ApiClient(basePath: '')..client = be.client), store: store).pull();
    final stream = _goaStream(be);
    final head = store.cursors[stream]!;
    var calls = 0;
    final client = MockClient((req) async {
      if (req.url.path != '/api/v1/sync') return be.client.send(req).then(http.Response.fromStream);
      calls++;
      final cursor = ((jsonDecode(req.body) as Map)['cursors'] as Map)[stream] as int;
      final page = cursor == head;
      return http.Response(jsonEncode({
        'streams': [
          {
            'stream': stream,
            'status': 'ok',
            'head_seq': head + 2,
            'changes': [
              if (cursor < head + 2) _change(cursor + 1, 'group.update', 'group', be.goa['id'], 'upsert', {...store.ledger.rawGroup(be.goa['id'])!, 'name': 'Goa ${cursor + 1}'}),
            ],
            'has_more': page,
          },
        ],
      }), 200);
    });
    await SyncEngine(api: SyncApi(ApiClient(basePath: '')..client = client), store: store).pull();
    expect(calls, 2);
    expect(store.cursors[stream], head + 2);
    expect(store.ledger.group(be.goa['id'])['name'], 'Goa ${head + 2}');
  });

  test('what was applied survives reopening the database', () async {
    final (engine, store, be, path) = await _setup();
    await engine.pull();
    final cursors = store.cursors;
    await store.close();
    final reopened = await LocalStore.open(databaseFactoryMemory, path);
    expect(reopened.cursors, cursors);
    expect(reopened.ledger.groups().length, 2);
    expect(reopened.ledger.userOut()['email'], 'ansh.c@cyware.com');
  });

  test('offline: the sync fails softly and the device copy stays', () async {
    final (engine, store, be, _) = await _setup();
    await engine.pull();
    final offline = SyncEngine(
      api: SyncApi(ApiClient(basePath: '')..client = MockClient((_) async => throw http.ClientException('no network'))),
      store: store,
    );
    await expectLater(offline.pull(), throwsA(isA<ApiException>()));
    expect(offline.status.offline, isTrue);
    expect(store.ledger.groups().length, 2);
  });

  test('a sync with no changes leaves the ledger unchanged', () async {
    final (engine, store, _, _) = await _setup();
    await engine.pull();
    final before = jsonEncode(store.ledger.overallBalances());
    var notified = 0;
    final sub = store.watch().skip(1).listen((_) => notified++);
    await engine.pull();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(notified, 0);
    expect(jsonEncode(store.ledger.overallBalances()), before);
  });
}
