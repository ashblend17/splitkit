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
///
/// What the screens show ([ledger]) is current the moment a change is made; [watch] hears of it
/// when the write is done, once for writes made at the same time, and once for a whole sync
/// ([batch]) however much it brings. Each change counts against the parts of the
/// data it touches ([LedgerRevisions]), so a screen can skip changes to parts it doesn't read.
/// Sending and confirming writes changes only the outbox ([watchOutbox]), not the screens.
class LocalStore {
  LocalStore._(this._db);

  /// Bump when the stored shape changes: the store is wiped and rebuilt from snapshots. 2: what
  /// migration 0013 filled in (accounts, directions) reaches a device only through a snapshot.
  static const schemaVersion = 2;

  final Database _db;
  final _entities = stringMapStoreFactory.store('entities');
  final _cursors = StoreRef<String, int>('cursors');
  final _meta = StoreRef<String, Object?>('meta');
  final _outbox = intMapStoreFactory.store('outbox');
  final _device = StoreRef<String, Object?>('device');

  final _cache = <String, LocalEntity>{};
  final _ops = <OutboxOp>[];
  final _cursorCache = <String, int>{};
  final _ledgerChanges = StreamController<Ledger>.broadcast();
  final _outboxChanges = StreamController<List<OutboxOp>>.broadcast();
  Ledger? _ledger;

  static var _stores = 0;

  /// Which store this is (see [LedgerRevisions.store]).
  final int _id = ++_stores;

  /// Changes per domain (LedgerDomain.index).
  final _revisions = List<int>.filled(LedgerDomain.values.length, 0);
  int _builds = 0;

  /// Changes [watch] or [watchOutbox] haven't heard of yet.
  bool _ledgerDue = false, _outboxDue = false;

  /// Some of them were made outside a [batch], so they're not held back by it.
  bool _dueNow = false;

  /// Writes to the store in progress, and [batch]es running.
  int _busy = 0, _batches = 0;

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
    Ledger.forgetCarried(_id);
    await _ledgerChanges.close();
    await _outboxChanges.close();
    await _db.close();
  }

  /// Streams this device has, with the last seq applied to each.
  Map<String, int> get cursors => Map.unmodifiable(_cursorCache);

  /// Whether every stream has loaded at least once (so screens can trust what they show).
  bool get hasData => _cursorCache.isNotEmpty;

  Iterable<LocalEntity> get entities => _cache.values;

  /// What the screens show: the server's state with writes not confirmed yet laid over it.
  /// Built when first read after a change, so it already shows a write the moment it's queued.
  Ledger get ledger => _ledger ??= _build();

  /// How many times [ledger] has been built, for tests and benchmarks.
  int get ledgerBuilds => _builds;

  /// The changes so far, per part of the data.
  LedgerRevisions get revisions => LedgerRevisions(_id, _revisions);

  Ledger _build() {
    _builds++;
    if (_ops.isEmpty) return Ledger(_cache.values, revisions: revisions);
    final view = Map.of(_cache);
    for (final op in _ops) {
      if (op.status == OutboxStatus.rejected) continue;
      for (final e in op.entities) {
        view[e.key] = e;
      }
    }
    return Ledger(view.values, revisions: revisions);
  }

  /// The server's own copy of an entity (without this device's unconfirmed writes).
  LocalEntity? serverEntity(String key) => _cache[key];

  /// The ledger now and after every change (one per write, or per writes made together).
  Stream<Ledger> watch() async* {
    yield ledger;
    yield* _ledgerChanges.stream;
  }

  /// The outbox now and after every change to it: a write queued, sent, refused or settled.
  Stream<List<OutboxOp>> watchOutbox() async* {
    yield outbox;
    yield* _outboxChanges.stream;
  }

  /// Runs [body], holding back what [watch] and [watchOutbox] hear of the changes it makes until
  /// it's done, so a sync (several streams, the outbox sent and settled) is one change. Changes
  /// made meanwhile from outside [body] (a write on a screen) are heard as usual.
  Future<T> batch<T>(Future<T> Function() body) async {
    if (identical(Zone.current[_batchZone], this)) return body();
    _batches++;
    try {
      return await runZoned(body, zoneValues: {_batchZone: this});
    } finally {
      _batches--;
      _flushIfIdle();
    }
  }

  static final _batchZone = Object();

  /// Runs one write to the store: changes made while any is in progress are heard together.
  Future<T> _writing<T>(Future<T> Function() body) async {
    _busy++;
    try {
      return await body();
    } finally {
      _busy--;
      _flushIfIdle();
    }
  }

  /// A change to these entities (their names): counts it against their domains and drops the
  /// built ledger.
  void _touched(Iterable<String> entities) => _touchedDomains({for (final e in entities) ...domainsOf(e)});

  void _touchedDomains(Set<LedgerDomain> domains) {
    if (domains.isEmpty) return;
    for (final d in domains) {
      _revisions[d.index]++;
    }
    _ledger = null;
    _ledgerDue = true;
    _due();
  }

  void _outboxTouched() {
    _outboxDue = true;
    _due();
  }

  void _due() {
    if (!identical(Zone.current[_batchZone], this)) _dueNow = true;
    _flushIfIdle();
  }

  /// Tells [watch] and [watchOutbox] what changed, once no write is in progress and, unless a
  /// change was made outside one, no [batch] is running.
  void _flushIfIdle() {
    if (_closed || _busy > 0 || !(_ledgerDue || _outboxDue) || (_batches > 0 && !_dueNow)) return;
    _dueNow = false;
    if (_ledgerDue) {
      _ledgerDue = false;
      _ledgerChanges.add(ledger);
    }
    if (_outboxDue) {
      _outboxDue = false;
      _outboxChanges.add(outbox);
    }
  }

  /// Replaces everything this device has for [stream] with a snapshot.
  Future<void> replaceStream(String stream, int headSeq, List<LocalEntity> entities) => _writing(() async {
    final stale = [for (final e in _cache.values) if (e.stream == stream) e];
    await _db.transaction((txn) async {
      await _entities.records([for (final e in stale) e.key]).delete(txn);
      for (final e in entities) {
        await _entities.record(e.key).put(txn, e.toJson());
      }
      await _cursors.record(stream).put(txn, headSeq);
    });
    for (final e in stale) {
      _cache.remove(e.key);
    }
    for (final e in entities) {
      _cache[e.key] = e;
    }
    _cursorCache[stream] = headSeq;
    _touched({for (final e in stale) e.entity, for (final e in entities) e.entity});
  });

  /// Applies `changes` (from POST /sync, in seq order) and moves the cursor to the last one.
  Future<void> applyChanges(String stream, List<Map<String, dynamic>> changes) async {
    if (changes.isEmpty) return;
    await _writing(() => _apply(stream, changes));
  }

  Future<void> _apply(String stream, List<Map<String, dynamic>> changes) async {
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
    _touched({for (final c in changes) c['entity'] as String, for (final e in puts.values) e.entity});
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
  Future<void> dropStream(String stream) => _writing(() async {
    final gone = [for (final e in _cache.values) if (e.stream == stream) e];
    await _db.transaction((txn) async {
      await _entities.records([for (final e in gone) e.key]).delete(txn);
      await _cursors.record(stream).delete(txn);
    });
    for (final e in gone) {
      _cache.remove(e.key);
    }
    _cursorCache.remove(stream);
    _touched({for (final e in gone) e.entity});
  });

  // ---- outbox (writes made on this device) ----

  /// Queued writes, oldest first.
  List<OutboxOp> get outbox => List.unmodifiable(_ops);

  Future<OutboxOp> enqueue(OutboxOp op) async => (await enqueueAll([op])).single;

  /// Queues [ops] in order, in one transaction and with one rebuild: writes that belong
  /// together (a split and the personal entry linked to it) show at once or not at all, and a
  /// big import doesn't rebuild the ledger once per entry.
  Future<List<OutboxOp>> enqueueAll(List<OutboxOp> ops) => _writing(() async {
    final saved = await _db.transaction((txn) async => [
      for (final op in ops) op.copyWith(id: await _outbox.add(txn, op.toJson())),
    ]);
    _ops.addAll(saved);
    _outboxTouched();
    _touched({for (final op in saved) for (final e in op.entities) e.entity});
    return saved;
  });

  /// A write's new status. Being sent or waiting for its confirmation changes only the outbox;
  /// being refused (or sent again after a refusal) changes what's laid over the server's copy.
  Future<void> updateOp(OutboxOp op) => _writing(() async {
    await _outbox.record(op.id!).put(_db, op.toJson());
    final i = _ops.indexWhere((o) => o.id == op.id);
    final before = i >= 0 ? _ops[i] : null;
    if (i >= 0) _ops[i] = op;
    _outboxTouched();
    final (was, now) = (before == null ? const <LocalEntity>[] : _overlaid(before), _overlaid(op));
    if (!identical(was, now)) _touched({for (final e in [...was, ...now]) e.entity});
  });

  /// What [op] lays over the server's copy.
  static List<LocalEntity> _overlaid(OutboxOp op) => op.status == OutboxStatus.rejected ? const [] : op.entities;

  Future<void> removeOps(Iterable<int> ids) async {
    final drop = ids.toSet();
    if (drop.isEmpty) return;
    await _writing(() async {
      await _outbox.records(drop.toList()).delete(_db);
      final gone = [for (final o in _ops) if (drop.contains(o.id)) o];
      _ops.removeWhere((o) => drop.contains(o.id));
      _outboxTouched();
      _touched({for (final o in gone) for (final e in _overlaid(o)) e.entity});
    });
  }

  /// Forgets everything that came from the server (keeping this device's unsynced writes), so
  /// the next sync reloads every stream from a snapshot. The in-app "Reload from server".
  Future<void> resetServerCopy() => _writing(() async {
    await _db.transaction((txn) async {
      await _entities.delete(txn);
      await _cursors.delete(txn);
    });
    _cache.clear();
    _cursorCache.clear();
    _touchedDomains(LedgerDomain.values.toSet());
  });

  // ---- this device's own values ----

  /// What only this device knows (its bank SMS settings, the messages it read): never synced,
  /// kept by "Reload from server", gone on logout.
  Future<Object?> deviceValue(String key) => _device.record(key).get(_db);

  Future<void> setDeviceValue(String key, Object? value) async {
    value == null ? await _device.record(key).delete(_db) : await _device.record(key).put(_db, value);
  }

  /// Several at once, in one transaction.
  Future<void> setDeviceValues(Map<String, Object?> values) => _db.transaction((txn) async {
    for (final MapEntry(:key, :value) in values.entries) {
      value == null ? await _device.record(key).delete(txn) : await _device.record(key).put(txn, value);
    }
  });

  /// Wipes the device copy (logout). The next sign-in rebuilds it from snapshots.
  Future<void> clear() => _writing(() async {
    await _db.transaction((txn) async {
      await _entities.delete(txn);
      await _cursors.delete(txn);
      await _device.delete(txn);
    });
    _cache.clear();
    _cursorCache.clear();
    _touchedDomains(LedgerDomain.values.toSet());
  });
}
