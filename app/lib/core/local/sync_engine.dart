import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' show Response;
import 'package:splitkit_api/api.dart';

import 'ledger.dart';
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

/// Brings the local store up to date: one `POST /sync` carrying every cursor, then snapshots for
/// streams that need one, repeated while any stream has more.
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
      do {
        _again = false;
        await _catchUp();
      } while (_again);
      _set(SyncStatus(lastSyncedAt: DateTime.now()));
    } catch (e) {
      final offline = isOfflineError(e);
      _set(SyncStatus(offline: offline, lastSyncedAt: _current.lastSyncedAt, error: offline ? null : e));
      if (e is ApiException && e.code == 401) await onUnauthorized?.call();
      rethrow;
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
