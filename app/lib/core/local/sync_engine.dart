import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' show Response;
import 'package:api_client/api.dart';

import '../clock.dart';
import 'ledger.dart';
import 'outbox.dart';
import 'store.dart';

/// Where syncing stands, for the "offline" line and the pull-to-refresh spinner.
class SyncStatus {
  const SyncStatus({this.syncing = false, this.offline = false, this.lastSyncedAt, this.error});

  final bool syncing;

  /// The last attempt couldn't reach the server. Screens keep showing what's on the device.
  final bool offline;
  final DateTime? lastSyncedAt;

  /// The last attempt failed for another reason (a server error).
  final Object? error;

  SyncStatus copyWith({bool? syncing, bool? offline, DateTime? lastSyncedAt, Object? error}) => SyncStatus(
    syncing: syncing ?? this.syncing,
    offline: offline ?? this.offline,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    error: error,
  );
}

/// No connection (or the server is down): the request never got an HTTP answer.
bool isOfflineError(Object error) =>
    error is ApiException && (error.code == 0 || error.innerException != null || '${error.message}'.contains('Socket'));

/// Brings the local store up to date. Each pass first replays writes made on this device (the
/// outbox, oldest first), then sends one `POST /sync` carrying every cursor, loads snapshots for
/// streams that need one and repeats while any stream has more, then settles the outbox: writes
/// whose result has arrived stop being overlaid.
class SyncEngine {
  SyncEngine({required this.api, required this.store, this.onUnauthorized});

  final SyncApi api;
  final LocalStore store;

  /// Called on a 401 (the token expired). The local data stays for the next sign-in.
  final Future<void> Function()? onUnauthorized;

  final _status = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = const SyncStatus();
  Future<void>? _running;
  bool _again = false;

  SyncStatus get status => _current;
  Stream<SyncStatus> get statusChanges => _status.stream;

  void _set(SyncStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  Future<void> dispose() => _status.close();

  /// Syncs now. Calls while one is running share it and trigger one more pass afterwards, so a
  /// write made during a sync is always picked up.
  Future<void> pull() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final run = _loop();
    _running = run;
    return run.whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    _set(_current.copyWith(syncing: true, error: _current.error));
    try {
      // The screens hear of everything a pull changes at once, when it's done (writes made on
      // them meanwhile still show straight away).
      final pushError = await store.batch(() async {
        Object? pushError;
        do {
          _again = false;
          try {
            await _push();
          } on ApiException catch (e) {
            // No connection or no sign-in stops everything. A server error on one write only
            // stops sending; incoming changes still arrive.
            if (isOfflineError(e) || e.code == 401) rethrow;
            pushError = e;
          }
          await _catchUp();
          await _settle();
        } while (_again);
        return pushError;
      });
      if (pushError != null) throw pushError;
      _set(SyncStatus(lastSyncedAt: appClock.now()));
    } catch (e) {
      final offline = isOfflineError(e);
      _set(SyncStatus(offline: offline, lastSyncedAt: _current.lastSyncedAt, error: offline ? null : e));
      if (e is ApiException && e.code == 401) await onUnauthorized?.call();
      rethrow;
    }
  }

  /// Sends pending writes in order. No connection (or a server error) stops here and leaves
  /// them queued; a refusal marks that write rejected and moves on.
  Future<void> _push() async {
    for (final op in store.outbox) {
      if (op.status != OutboxStatus.pending) continue;
      final r = await api.apiClient.invokeAPI(
        op.path,
        op.method,
        [for (final q in op.query.entries) QueryParam(q.key, q.value)],
        op.body,
        {},
        {},
        'application/json',
      );
      if (r.statusCode < 300) {
        await store.updateOp(op.copyWith(status: OutboxStatus.sent));
        continue;
      }
      final text = utf8.decode(r.bodyBytes);
      if (r.statusCode == 401 || r.statusCode == 408 || r.statusCode == 429 || r.statusCode >= 500) {
        throw ApiException(r.statusCode, text);
      }
      final (code, message) = _error(text);
      await store.updateOp(op.copyWith(status: OutboxStatus.rejected, code: code, error: message));
    }
  }

  /// After a sync: a sent write is done once the server's copy of everything it touched has
  /// arrived (at its version or later), or after a few syncs regardless. A conflict on a write
  /// the server already has (its reply was lost and the retry looked stale) is done too.
  Future<void> _settle() async {
    final done = <int>[];
    for (final op in store.outbox) {
      if (op.status == OutboxStatus.sent) {
        if (_confirmed(op) || op.syncsSinceSent >= 2) {
          done.add(op.id!);
        } else {
          await store.updateOp(op.copyWith(syncsSinceSent: op.syncsSinceSent + 1));
        }
      } else if (op.status == OutboxStatus.rejected && op.isConflict && _alreadyOnServer(op)) {
        done.add(op.id!);
      }
    }
    await store.removeOps(done);
  }

  bool _confirmed(OutboxOp op) => op.entities.every((e) {
    final server = store.serverEntity(e.key);
    return server != null && (e.version == null || (server.version ?? 0) >= e.version!);
  });

  // sms_at: the server writes "+00:00", Dart "Z" with milliseconds; the same instant either way.
  static const _volatile = {'version', 'created_at', 'updated_at', 'deleted_at', 'last_activity_at', 'category', 'sms_at'};

  bool _alreadyOnServer(OutboxOp op) => op.entities.every((e) {
    final server = store.serverEntity(e.key)?.data;
    if (server == null) return false;
    if ((server['deleted_at'] == null) != (e.data['deleted_at'] == null)) return false;
    return e.data.keys.where((k) => !_volatile.contains(k)).every((k) => jsonEncode(server[k]) == jsonEncode(e.data[k]));
  });

  static (String?, String) _error(String text) {
    try {
      final error = (jsonDecode(text) as Map)['error'] as Map;
      return (error['code'] as String?, error['message'] as String? ?? 'The server refused this change');
    } catch (_) {
      return (null, 'The server refused this change');
    }
  }

  Future<void> _catchUp() async {
    for (var round = 0; round < 1000; round++) {
      final body = _json(await api.callSyncWithHttpInfo(SyncIn(cursors: store.cursors, limit: 500)));
      var more = false;
      for (final s in (body['streams'] as List).cast<Map<String, dynamic>>()) {
        final stream = s['stream'] as String;
        switch (s['status']) {
          case 'ok':
            await store.applyChanges(stream, (s['changes'] as List).cast<Map<String, dynamic>>());
            more |= s['has_more'] == true;
          case 'snapshot_required':
            await loadSnapshot(stream);
          case 'gone':
            await store.dropStream(stream);
        }
      }
      if (!more) return;
    }
  }

  Future<void> loadSnapshot(String stream) async {
    final snap = _json(await api.snapshotWithHttpInfo(stream));
    await store.replaceStream(stream, snap['head_seq'] as int, [
      for (final e in (snap['entities'] as List).cast<Map<String, dynamic>>())
        LocalEntity(stream, e['entity'], e['entity_id'], e['version'], (e['data'] as Map).cast()),
    ]);
  }

  static Map<String, dynamic> _json(Response r) {
    final text = utf8.decode(r.bodyBytes);
    if (r.statusCode >= 400) throw ApiException(r.statusCode, text);
    return (jsonDecode(text) as Map).cast();
  }
}
