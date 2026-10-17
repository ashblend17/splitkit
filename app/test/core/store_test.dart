import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/local/ledger.dart';
import 'package:splitkit/core/local/outbox.dart';
import 'package:splitkit/core/local/store.dart';
import 'package:splitkit/core/local/sync_engine.dart';

import '../fake_backend.dart';

var _n = 0;

/// A store synced from the seed (the fake backend), with what it tells the screens counted.
Future<(LocalStore, SyncEngine, FakeBackend, _Heard)> _setup() async {
  final be = FakeBackend();
  final store = await LocalStore.open(databaseFactoryMemory, 'store-test-${_n++}');
  final engine = SyncEngine(
    api: SyncApi(ApiClient(basePath: '')..client = be.client),
    store: store,
  );
  await engine.pull();
  final heard = _Heard(store);
  addTearDown(() async {
    await heard.cancel();
    await store.close();
  });
  return (store, engine, be, heard);
}

/// Counts the ledgers and outboxes a store hands out after it's set up.
class _Heard {
  _Heard(LocalStore store) {
    _subs = [store.watch().skip(1).listen((_) => ledgers++), store.watchOutbox().skip(1).listen((_) => outboxes++)];
  }

  late final List<StreamSubscription<Object>> _subs;
  var ledgers = 0, outboxes = 0;

  /// (ledgers, outboxes) heard since the last call, once everything pending has been delivered.
  Future<(int, int)> take() async {
    await pumpEventQueue();
    final out = (ledgers, outboxes);
    ledgers = outboxes = 0;
    return out;
  }

  Future<void> cancel() async {
    for (final s in _subs) {
      await s.cancel();
    }
  }
}

LocalEntity _renamed(LocalStore store, String groupId, String name, {int? version}) {
  final g = store.ledger.rawGroup(groupId)!;
  final v = version ?? (g['version'] as int) + 1;
  return LocalEntity('group:$groupId', 'group', groupId, v, {...g, 'name': name, 'version': v});
}

LocalEntity _entry(LocalStore store, String id, String description) =>
    LocalEntity('user:${store.ledger.me}', 'personal_transaction', id, 1, {
      'id': id,
      'user_id': store.ledger.me,
      'type': 'expense',
      'amount_minor': 1200,
      'currency': 'INR',
      'category_id': null,
      'date': '2026-09-25',
      'description': description,
      'source': 'manual',
      'reviewed': true,
      'created_at': '2026-09-25T10:00:00Z',
      'deleted_at': null,
      'version': 1,
    });

OutboxOp _op(String label, List<LocalEntity> entities, {String path = '/api/v1/x'}) =>
    OutboxOp(method: 'PUT', path: path, label: label, entities: entities, createdAt: '2026-09-25T10:00:00Z');

Map<String, dynamic> _change(int seq, LocalEntity e) => {
  'seq': seq,
  'action': '${e.entity}.update',
  'entity': e.entity,
  'entity_id': e.entityId,
  'op': 'upsert',
  'version': e.version,
  'data': e.data,
  'actor_id': null,
  'acting_admin_id': null,
  'at': '2026-09-25T10:00:00+00:00',
};

void main() {
  test('a write shows in store.ledger the moment it is queued', () async {
    final (store, _, be, heard) = await _setup();
    final before = store.ledgerBuilds;
    await store.enqueue(_op('Renamed', [_renamed(store, be.goa['id'], 'Goa (renamed)')]));
    expect(store.ledger.group(be.goa['id'])['name'], 'Goa (renamed)');
    expect(await heard.take(), (1, 1));
    expect(store.ledgerBuilds - before, 1);
  });

  test('writes made together are heard as one change, with one rebuild', () async {
    final (store, _, be, heard) = await _setup();
    final before = store.ledgerBuilds;
    await Future.wait([
      store.enqueue(_op('One', [_renamed(store, be.goa['id'], 'Goa 1')])),
      store.enqueue(_op('Two', [_entry(store, 'entry-2', 'Two')])),
      store.enqueue(_op('Three', [_entry(store, 'entry-3', 'Three')])),
    ]);
    expect(await heard.take(), (1, 1));
    expect(store.ledgerBuilds - before, 1);
    expect(store.ledger.personalList()['items'].map((t) => t['description']), containsAll(['Two', 'Three']));
  });

  test('a pull is one change: writes sent, three streams of changes, the outbox settled', () async {
    final (store, engine, be, heard) = await _setup();
    final flatmates = be.snapshots.keys.firstWhere((s) => s.startsWith('group:') && s != 'group:${be.goa['id']}');
    final user = be.snapshots.keys.firstWhere((s) => s.startsWith('user:'));
    final rename = _renamed(store, be.goa['id'], 'Goa (renamed)');
    final entry = _entry(store, 'entry-1', 'Coffee');
    await store.enqueueAll([
      _op('Renamed', [rename]),
      _op('Coffee', [entry]),
    ]);
    expect(await heard.take(), (1, 1));
    // The server's copies of both writes, and a change on a third stream.
    final other = _renamed(store, flatmates.substring('group:'.length), 'Flat (renamed)');
    for (final (stream, e) in [('group:${be.goa['id']}', rename), (user, entry), (flatmates, other)]) {
      be.pendingChanges[stream] = [_change(store.cursors[stream]! + 1, e)];
    }
    final before = store.ledgerBuilds;
    await engine.pull();
    expect(await heard.take(), (1, 1));
    expect(store.ledgerBuilds - before, 1);
    expect(store.outbox, isEmpty);
    expect(store.ledger.group(flatmates.substring('group:'.length))['name'], 'Flat (renamed)');
  });

  test('sending and confirming a write changes the outbox, not the data', () async {
    final (store, _, be, heard) = await _setup();
    final op = await store.enqueue(_op('Renamed', [_renamed(store, be.goa['id'], 'Goa (renamed)')]));
    await heard.take();
    final builds = store.ledgerBuilds;
    await store.updateOp(op.copyWith(status: OutboxStatus.sent));
    expect(await heard.take(), (0, 1));
    await store.updateOp(op.copyWith(status: OutboxStatus.sent, syncsSinceSent: 1));
    expect(await heard.take(), (0, 1));
    expect(store.ledgerBuilds, builds);
    await store.removeOps([op.id!]);
    expect(await heard.take(), (1, 1)); // the overlay is gone: the server's copy shows
    expect(store.ledger.group(be.goa['id'])['name'], 'Goa Trip');
  });

  test('a refused write stops showing; discarding it changes only the outbox', () async {
    final (store, _, be, heard) = await _setup();
    final op = await store.enqueue(_op('Renamed', [_renamed(store, be.goa['id'], 'Goa (renamed)')]));
    await heard.take();
    await store.updateOp(op.copyWith(status: OutboxStatus.rejected, code: 'version_conflict', error: 'Changed'));
    expect(await heard.take(), (1, 1));
    expect(store.ledger.group(be.goa['id'])['name'], 'Goa Trip');
    await store.removeOps([op.id!]);
    expect(await heard.take(), (0, 1));
  });

  test('a write made during a sync is heard at once; the sync when it ends', () async {
    final (store, _, be, heard) = await _setup();
    final user = be.snapshots.keys.firstWhere((s) => s.startsWith('user:'));
    final release = Completer<void>();
    final sync = store.batch(() async {
      await store.applyChanges(user, [_change(store.cursors[user]! + 1, _entry(store, 'entry-s', 'From the server'))]);
      await release.future;
    });
    await pumpEventQueue();
    expect(await heard.take(), (0, 0)); // held back
    await store.enqueue(_op('Renamed', [_renamed(store, be.goa['id'], 'Goa (renamed)')]));
    expect(await heard.take(), (1, 1)); // the write, with what the sync had applied so far
    expect(store.ledger.group(be.goa['id'])['name'], 'Goa (renamed)');
    release.complete();
    await sync;
    expect(await heard.take(), (0, 0)); // nothing left to tell
    await store.batch(
      () => store.applyChanges(user, [_change(store.cursors[user]! + 1, _entry(store, 'entry-t', 'Later'))]),
    );
    expect(await heard.take(), (1, 0));
  });

  test('each change counts against the parts of the data it touches', () async {
    final (store, _, be, _) = await _setup();
    final user = be.snapshots.keys.firstWhere((s) => s.startsWith('user:'));
    LedgerRevisions now() => store.ledger.revisions;
    Map<LedgerDomain, int> diff(LedgerRevisions a, LedgerRevisions b) => {
      for (final d in LedgerDomain.values)
        if (b[d] != a[d]) d: b[d] - a[d],
    };
    var before = now();
    await store.enqueue(_op('Entry', [_entry(store, 'entry-1', 'Coffee')]));
    expect(diff(before, before = now()), {LedgerDomain.personal: 1});
    await store.enqueue(_op('Renamed', [_renamed(store, be.goa['id'], 'Goa (renamed)')]));
    expect(diff(before, before = now()), {LedgerDomain.groups: 1});
    final rule = LocalEntity(user, 'category_rule', 'rule-1', null, {
      'id': 'rule-1',
      'pattern': 'coffee',
      'income': false,
    });
    await store.enqueue(_op('Rule', [rule, _entry(store, 'entry-2', 'Tea')]));
    expect(diff(before, before = now()), {LedgerDomain.categories: 1, LedgerDomain.personal: 1});
    final profile = store.serverEntity(LocalEntity.keyOf(user, 'profile', store.ledger.me))!;
    await store.applyChanges(user, [_change(store.cursors[user]! + 1, profile)]);
    expect(diff(before, before = now()), {LedgerDomain.profile: 1});
    // Something this app doesn't know yet touches everything.
    final mystery = LocalEntity(user, 'mystery', 'm-1', 1, {'id': 'm-1'});
    await store.applyChanges(user, [_change(store.cursors[user]! + 1, mystery)]);
    expect(diff(before, before = now()).keys, LedgerDomain.values.toSet());
    await store.dropStream('group:${be.goa['id']}');
    expect(diff(before, before = now()), {LedgerDomain.groups: 1});
    // Another store counts on its own.
    final other = await LocalStore.open(databaseFactoryMemory, 'store-test-${_n++}');
    addTearDown(other.close);
    expect(other.ledger.revisions.of(LedgerDomain.values.toSet()), isNot(now().of(LedgerDomain.values.toSet())));
  });

  test('a sync with nothing new tells nobody anything', () async {
    final (_, engine, _, heard) = await _setup();
    await engine.pull();
    expect(await heard.take(), (0, 0));
  });
}
