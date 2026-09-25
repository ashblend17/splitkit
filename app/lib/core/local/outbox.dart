import 'ledger.dart';

/// Where a queued write stands.
enum OutboxStatus {
  /// Waiting to be sent.
  pending,

  /// The server took it; shown from the device until the server's copy arrives by sync.
  sent,

  /// The server refused it (a conflict or a check only the server can make). Shown in "Needs
  /// your attention"; its effect is no longer shown.
  rejected,
}

/// A write made on this device: the request to replay, and the full state it will leave
/// behind, which the screens show until the server confirms it.
///
/// Creates carry their own id, so replaying one twice makes one row. Edits and deletes carry the
/// version they started from, so a stale one gets a 409 instead of overwriting someone's change.
class OutboxOp {
  const OutboxOp({
    this.id,
    required this.method,
    required this.path,
    this.query = const {},
    this.body,
    required this.label,
    required this.entities,
    this.status = OutboxStatus.pending,
    this.code,
    this.error,
    this.syncsSinceSent = 0,
    required this.createdAt,
  });

  final int? id;
  final String method;

  /// API path, e.g. /api/v1/groups/{id}/expenses.
  final String path;
  final Map<String, String> query;
  final Map<String, dynamic>? body;

  /// What it was, in words: "Dinner at Thalassa · ₹1,800".
  final String label;

  /// The full state of every entity this write changes, as the server will send it back.
  final List<LocalEntity> entities;
  final OutboxStatus status;

  /// The server's error code and human message, for rejected writes.
  final String? code;
  final String? error;

  /// Syncs finished since it was sent without the server's copy arriving. After a few the
  /// overlay is dropped anyway, so a write the server stored differently can't stick around.
  final int syncsSinceSent;
  final String createdAt;

  bool get isConflict => code == 'version_conflict';

  OutboxOp copyWith({int? id, OutboxStatus? status, String? code, String? error, int? syncsSinceSent, Map<String, String>? query, Map<String, dynamic>? body}) =>
      OutboxOp(
        id: id ?? this.id,
        method: method,
        path: path,
        query: query ?? this.query,
        body: body ?? this.body,
        label: label,
        entities: entities,
        status: status ?? this.status,
        code: code ?? this.code,
        error: error ?? this.error,
        syncsSinceSent: syncsSinceSent ?? this.syncsSinceSent,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
    'method': method,
    'path': path,
    'query': query,
    'body': body,
    'label': label,
    'entities': [for (final e in entities) e.toJson()],
    'status': status.name,
    'code': code,
    'error': error,
    'syncs_since_sent': syncsSinceSent,
    'created_at': createdAt,
  };

  static OutboxOp fromJson(int id, Map<String, dynamic> j) => OutboxOp(
    id: id,
    method: j['method'] as String,
    path: j['path'] as String,
    query: (j['query'] as Map? ?? const {}).cast<String, String>(),
    body: (j['body'] as Map?)?.cast<String, dynamic>(),
    label: j['label'] as String,
    entities: [for (final e in j['entities'] as List) LocalEntity.fromJson((e as Map).cast())],
    status: OutboxStatus.values.byName(j['status'] as String),
    code: j['code'] as String?,
    error: j['error'] as String?,
    syncsSinceSent: j['syncs_since_sent'] as int? ?? 0,
    createdAt: j['created_at'] as String,
  );
}
