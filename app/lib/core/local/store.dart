import 'dart:async';

import 'package:sembast/sembast.dart';

import 'ledger.dart';
import 'outbox.dart';

/// This device's copy of the synced streams: entities (full state from snapshots and changes)
/// and, per stream, the last seq applied. One database per signed-in user.
///
/// Every batch is applied together with its cursor in one transaction, so a crash half-way
/// leaves the cursor at the last fully applied change and the next sync fetches the rest.
/// Applying a change twice is harmless: each one replaces the entity with its full state.
class LocalStore {
  LocalStore._(this._db);

  /// Bump when the stored shape changes: the store is wiped and rebuilt from snapshots.
  static const schemaVersion = 1;

  final Database _db;
  final _entities = stringMapStoreFactory.store('entities');
  final _cursors = StoreRef<String, int>('cursors');
  final _meta = StoreRef<String, Object?>('meta');
  final _outbox = intMapStoreFactory.store('outbox');

  final _cache = <String, LocalEntity>{};
  final _ops = <OutboxOp>[];
  final _cursorCache = <String, int>{};
  final _changed = StreamController<Ledger>.broadcast();
  Ledger? _ledger;

  /// Open stores by path, so [delete] can close one before removing its file.
  static final _open = <String, LocalStore>{};

  static Future<LocalStore> open(DatabaseFactory factory, String path) async {
    final db = await factory.openDatabase(path);
    final store = LocalStore._(db);
    await store._load();
    _open[path] = store;
    return store;
  }

  /// Closes the store at [path] if it's open, then deletes its database.
  static Future<void> delete(DatabaseFactory factory, String path) async {
    await _open.remove(path)?.close();
    await factory.deleteDatabase(path);
  }

  Future<void> _load() async {
    final version = await _meta.record('schema').get(_db);
    if (version != schemaVersion) {
      await _db.transaction((txn) async {
        await _entities.delete(txn);
        await _cursors.delete(txn);
        await _meta.record('schema').put(txn, schemaVersion);
      });
    }
    for (final r in await _entities.find(_db)) {
      _cache[r.key] = LocalEntity.fromJson(r.value.cast());
    }
    for (final r in await _cursors.find(_db)) {
      _cursorCache[r.key] = r.value;
    }
    for (final r in await _outbox.find(_db, finder: Finder(sortOrders: [SortOrder(Field.key)]))) {
      _ops.add(OutboxOp.fromJson(r.key, r.value.cast()));
    }
  }

  bool _closed = false;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _changed.close();
    await _db.close();
  }

  /// Streams this device has, with the last seq applied to each.
  Map<String, int> get cursors => Map.unmodifiable(_cursorCache);

  /// Whether every stream has loaded at least once (so screens can trust what they show).
  bool get hasData => _cursorCache.isNotEmpty;

  Iterable<LocalEntity> get entities => _cache.values;

  /// What the screens show: the server's state with writes not confirmed yet laid over it.
  Ledger get ledger => _ledger ??= _build();

  Ledger _build() {
    if (_ops.isEmpty) return Ledger(_cache.values);
    final view = Map.of(_cache);
    for (final op in _ops) {
      if (op.status == OutboxStatus.rejected) continue;
      for (final e in op.entities) {
        view[e.key] = e;
      }
    }
    return Ledger(view.values);
  }

  /// The server's own copy of an entity (without this device's unconfirmed writes).
  LocalEntity? serverEntity(String key) => _cache[key];

  /// The ledger now and after every change.
  Stream<Ledger> watch() async* {
    yield ledger;
    yield* _changed.stream;
  }

  void _notify() {
    _ledger = _build();
    if (!_changed.isClosed) _changed.add(_ledger!);
  }

  /// Replaces everything this device has for [stream] with a snapshot.
  Future<void> replaceStream(String stream, int headSeq, List<LocalEntity> entities) async {
    final stale = [for (final e in _cache.values) if (e.stream == stream) e.key];
    await _db.transaction((txn) async {
      await _entities.records(stale).delete(txn);
      for (final e in entities) {
        await _entities.record(e.key).put(txn, e.toJson());
      }
      await _cursors.record(stream).put(txn, headSeq);
    });
    stale.forEach(_cache.remove);
    for (final e in entities) {
      _cache[e.key] = e;
    }
    _cursorCache[stream] = headSeq;
    _notify();
  }

  /// Applies `changes` (from POST /sync, in seq order) and moves the cursor to the last one.
  Future<void> applyChanges(String stream, List<Map<String, dynamic>> changes) async {
    if (changes.isEmpty) return;
    final puts = <String, LocalEntity>{};
    final deletes = <String>{};
    for (final c in changes) {
      final key = LocalEntity.keyOf(stream, c['entity'], c['entity_id']);
      if (c['op'] == 'delete') {
        puts.remove(key);
        deletes.add(key);
      } else {
        deletes.remove(key);
        puts[key] = LocalEntity(stream, c['entity'], c['entity_id'], c['version'], (c['data'] as Map).cast());
      }
    }
    _bumpActivity(stream, changes, puts);
    final last = changes.last['seq'] as int;
    await _db.transaction((txn) async {
      await _entities.records(deletes.toList()).delete(txn);
      for (final e in puts.values) {
        await _entities.record(e.key).put(txn, e.toJson());
      }
      await _cursors.record(stream).put(txn, last);
    });
    deletes.forEach(_cache.remove);
    _cache.addAll(puts);
    _cursorCache[stream] = last;
    _notify();
  }

  /// A group's "last activity" is the time of its latest write. The snapshot carries it; later
  /// changes move it forward (profile renames re-send members but aren't group activity).
  void _bumpActivity(String stream, List<Map<String, dynamic>> changes, Map<String, LocalEntity> puts) {
    if (!stream.startsWith('group:')) return;
    final groupId = stream.substring('group:'.length);
    final key = LocalEntity.keyOf(stream, 'group', groupId);
    final group = puts[key] ?? _cache[key];
    if (group == null) return;
    String? latest = group.data['last_activity_at'] as String?;
    for (final c in changes) {
      if ((c['action'] as String).startsWith('user.')) continue;
      final at = c['at'] as String;
      if (latest == null || DateTime.parse(at).isAfter(DateTime.parse(latest))) latest = at;
    }
    if (latest == group.data['last_activity_at']) return;
    puts[key] = LocalEntity(stream, 'group', groupId, group.version, {...group.data, 'last_activity_at': latest});
  }

  /// Forgets a stream you no longer have access to.
  Future<void> dropStream(String stream) async {
    final keys = [for (final e in _cache.values) if (e.stream == stream) e.key];
    await _db.transaction((txn) async {
      await _entities.records(keys).delete(txn);
      await _cursors.record(stream).delete(txn);
    });
    keys.forEach(_cache.remove);
    _cursorCache.remove(stream);
    _notify();
  }

  // ---- outbox (writes made on this device) ----

  /// Queued writes, oldest first.
  List<OutboxOp> get outbox => List.unmodifiable(_ops);

  Future<OutboxOp> enqueue(OutboxOp op) async {
    final id = await _outbox.add(_db, op.toJson());
    final saved = op.copyWith(id: id);
    _ops.add(saved);
    _notify();
    return saved;
  }

  Future<void> updateOp(OutboxOp op) async {
    await _outbox.record(op.id!).put(_db, op.toJson());
    final i = _ops.indexWhere((o) => o.id == op.id);
    if (i >= 0) _ops[i] = op;
    _notify();
  }

  Future<void> removeOps(Iterable<int> ids) async {
    final drop = ids.toSet();
    if (drop.isEmpty) return;
    await _outbox.records(drop.toList()).delete(_db);
    _ops.removeWhere((o) => drop.contains(o.id));
    _notify();
  }

  /// Forgets everything that came from the server (keeping this device's unsynced writes), so
  /// the next sync reloads every stream from a snapshot. The in-app "Reload from server".
  Future<void> resetServerCopy() async {
    await _db.transaction((txn) async {
      await _entities.delete(txn);
      await _cursors.delete(txn);
    });
    _cache.clear();
    _cursorCache.clear();
    _notify();
  }

  /// Wipes the device copy (logout). The next sign-in rebuilds it from snapshots.
  Future<void> clear() async {
    await _db.transaction((txn) async {
      await _entities.delete(txn);
      await _cursors.delete(txn);
    });
    _cache.clear();
    _cursorCache.clear();
    _notify();
  }
}
