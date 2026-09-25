import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../api/api.dart';
import '../money/money.dart';
import '../session/session.dart';
import '../splits/split_engine.dart';
import 'balance_engine.dart';
import 'ledger.dart';
import 'outbox.dart';
import 'providers.dart';

/// Writes that work offline: each one is queued in the outbox with the full state it leaves
/// behind, shows on every screen straight away, and is sent by the next sync (which starts
/// right away when there is a connection).
///
/// The entity shapes mirror the server's sync entries (api/app/modules/sync/log.py), so the
/// ledger reads a queued write exactly as it will read the server's copy of it. Adding members,
/// profile, categories and analytics layouts still go straight to the API.
final writesProvider = Provider<LocalWrites>((ref) => LocalWrites(ref));

/// The write was refused before it was queued (e.g. a read-only view-as session).
class WriteRefused implements Exception {
  const WriteRefused(this.message);
  final String message;

  @override
  String toString() => message;
}

class LocalWrites {
  LocalWrites(this._ref);
  final Ref _ref;

  static const _uuid = Uuid();

  Future<Ledger> _ledger() async => (await _ref.read(localStoreProvider.future)).ledger;

  String _now() => DateTime.now().toUtc().toIso8601String();
  static String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _queue(OutboxOp op) async {
    final session = _ref.read(sessionProvider).value;
    if (session?.readOnly ?? false) throw const WriteRefused('You are viewing as this user in read-only mode');
    final store = await _ref.read(localStoreProvider.future);
    await store.enqueue(op);
    final engine = await _ref.read(syncEngineProvider.future);
    engine.pull().ignore();
  }

  LocalEntity _entity(String stream, String entity, String id, int? version, Map<String, dynamic> data) =>
      LocalEntity(stream, entity, id, version, data);

  Json _required(Json? row, String what) => row ?? (throw LocalNotFound(what));

  // ---- expenses ----

  /// The expense as the server will store it: splits allocated by the same engine, the
  /// category embedded like the sync log does.
  Json _expenseData(Ledger l, {required String id, required String groupId, required ExpenseIn body, Json? before}) {
    final group = _required(l.rawGroup(groupId), 'Group');
    final currency = group['currency'] as String;
    final method = splitRegistry.get(body.split.method);
    final shares = method.allocate(body.amountMinor, [
      for (final i in body.split.inputs) SplitInput(i.userId, i.value == null ? null : Decimal.parse(i.value!)),
    ], currency: currency);
    final c = body.categoryId == null ? null : l.rawCategory(body.categoryId!);
    final now = _now();
    return {
      'id': id,
      'group_id': groupId,
      'description': body.description.trim(),
      'amount_minor': body.amountMinor,
      'currency': currency,
      'payer_id': body.payerId,
      'date': _day(body.date),
      'category_id': body.categoryId,
      'notes': body.notes,
      'split_method': body.split.method,
      'import_batch_id': before?['import_batch_id'],
      'created_by': before?['created_by'] ?? l.me,
      'acting_admin_id': _ref.read(sessionProvider).value?.adminId,
      'created_at': before?['created_at'] ?? now,
      'updated_at': now,
      'deleted_at': null,
      'version': (before?['version'] as int? ?? 0) + 1,
      'splits': [
        for (final s in shares) {'user_id': s.userId, 'share_minor': s.shareMinor, 'input_value': s.inputValue?.toString()},
      ],
      'category': c == null
          ? null
          : {'id': c['id'], 'key': c['key'], 'label': c['label'], 'icon': c['icon'], 'scope': c['scope'], 'owner_id': c['owner_id']},
    };
  }

  String _expenseLabel(Json e) => '${e['description']} · ${formatMinor(e['amount_minor'] as int, currency: e['currency'] as String)}';

  /// Returns the new expense's id (made here, so the screen can open it right away).
  Future<String> createExpense(String groupId, ExpenseIn body) async {
    final l = await _ledger();
    final id = _uuid.v4();
    final data = _expenseData(l, id: id, groupId: groupId, body: body);
    body.id = id;
    await _queue(OutboxOp(
      method: 'POST',
      path: '/api/v1/groups/$groupId/expenses',
      body: _json(body.toJson()),
      label: 'Added ${_expenseLabel(data)}',
      entities: [_entity('group:$groupId', 'expense', id, data['version'], data)],
      createdAt: _now(),
    ));
    return id;
  }

  Future<void> updateExpense(String id, ExpenseIn body) async {
    final l = await _ledger();
    final before = _required(l.rawExpense(id), 'Expense');
    final groupId = before['group_id'] as String;
    final data = _expenseData(l, id: id, groupId: groupId, body: body, before: before);
    body.version = before['version'] as int;
    await _queue(OutboxOp(
      method: 'PUT',
      path: '/api/v1/expenses/$id',
      body: _json(body.toJson()),
      label: 'Edited ${_expenseLabel(data)}',
      entities: [_entity('group:$groupId', 'expense', id, data['version'], data)],
      createdAt: _now(),
    ));
  }

  Future<void> deleteExpense(String id) => _setExpenseDeleted(id, true);
  Future<void> restoreExpense(String id) => _setExpenseDeleted(id, false);

  Future<void> _setExpenseDeleted(String id, bool deleted) async {
    final l = await _ledger();
    final before = _required(l.rawExpense(id), 'Expense');
    if ((before['deleted_at'] != null) == deleted) return;
    final version = before['version'] as int;
    final data = {
      ...before,
      'deleted_at': deleted ? _now() : null,
      'acting_admin_id': _ref.read(sessionProvider).value?.adminId,
      'version': version + 1,
    };
    await _queue(OutboxOp(
      method: deleted ? 'DELETE' : 'POST',
      path: deleted ? '/api/v1/expenses/$id' : '/api/v1/expenses/$id/restore',
      query: {'version': '$version'},
      label: '${deleted ? 'Deleted' : 'Restored'} ${_expenseLabel(before)}',
      entities: [_entity('group:${before['group_id']}', 'expense', id, version + 1, data)],
      createdAt: _now(),
    ));
  }

  // ---- settlements ----

  Json _settlementData(Ledger l, String id, String groupId, SettlementIn body) {
    final group = _required(l.rawGroup(groupId), 'Group');
    return {
      'id': id,
      'group_id': groupId,
      'from_user': body.fromUser,
      'to_user': body.toUser,
      'amount_minor': body.amountMinor,
      'currency': group['currency'],
      'date': _day(body.date),
      'method': body.method.value,
      'note': body.note,
      'created_by': l.me,
      'acting_admin_id': _ref.read(sessionProvider).value?.adminId,
      'created_at': _now(),
      'deleted_at': null,
      'version': 1,
    };
  }

  String _settlementLabel(Ledger l, Json s) =>
      '${l.brief(s['from_user'])['name']} paid ${l.brief(s['to_user'])['name']} '
      '${formatMinor(s['amount_minor'] as int, currency: s['currency'] as String)}';

  Future<String> createSettlement(String groupId, SettlementIn body) async {
    final l = await _ledger();
    final id = _uuid.v4();
    final data = _settlementData(l, id, groupId, body);
    body.id = id;
    await _queue(OutboxOp(
      method: 'POST',
      path: '/api/v1/groups/$groupId/settlements',
      body: _json(body.toJson()),
      label: 'Recorded: ${_settlementLabel(l, data)}',
      entities: [_entity('group:$groupId', 'settlement', id, 1, data)],
      createdAt: _now(),
    ));
    return id;
  }

  /// Settling with a friend across groups, planned on this device with the same rules as the
  /// server (settlements/planner.py) and queued as one payment per group, each with its own id,
  /// so a retry can never record a payment twice. Returns the new payments' ids.
  Future<List<String>> settleUp(
    String friendId, {
    int? amountMinor,
    required DateTime date,
    required String method,
    String? note,
    required String currency,
  }) async {
    final l = await _ledger();
    final balances = l.sharedBalances(friendId, currency);
    final plan = planSettleUp([for (final (g, net) in balances) GroupBalance(g['id'] as String, net)], amountMinor);
    final ids = <String>[];
    for (final p in plan) {
      final (from, to) = p.friendPays ? (friendId, l.me) : (l.me, friendId);
      ids.add(await createSettlement(
        p.groupId,
        SettlementIn(
          fromUser: from,
          toUser: to,
          amountMinor: p.amountMinor,
          date: apiDate(date),
          method: SettlementInMethodEnum.fromJson(method) ?? SettlementInMethodEnum.upi,
          note: note,
        ),
      ));
    }
    return ids;
  }

  Future<void> deleteSettlement(String id) => _setSettlementDeleted(id, true);
  Future<void> restoreSettlement(String id) => _setSettlementDeleted(id, false);

  Future<void> _setSettlementDeleted(String id, bool deleted) async {
    final l = await _ledger();
    final before = _required(l.rawSettlement(id), 'Payment');
    if ((before['deleted_at'] != null) == deleted) return;
    final version = before['version'] as int;
    final data = {
      ...before,
      'deleted_at': deleted ? _now() : null,
      'acting_admin_id': _ref.read(sessionProvider).value?.adminId,
      'version': version + 1,
    };
    await _queue(OutboxOp(
      method: deleted ? 'DELETE' : 'POST',
      path: deleted ? '/api/v1/settlements/$id' : '/api/v1/settlements/$id/restore',
      query: {'version': '$version'},
      label: '${deleted ? 'Deleted' : 'Restored'} payment: ${_settlementLabel(l, before)}',
      entities: [_entity('group:${before['group_id']}', 'settlement', id, version + 1, data)],
      createdAt: _now(),
    ));
  }

  // ---- personal finance ----

  Json _personalData(Ledger l, String id, PersonalTxnIn body, Json? before) => {
    'id': id,
    'user_id': l.me,
    'type': body.type.value,
    'amount_minor': body.amountMinor,
    'currency': before?['currency'] ?? l.userOut()['currency'],
    'category_id': body.categoryId,
    'date': _day(body.date),
    'description': body.description.trim(),
    'notes': body.notes,
    'acting_admin_id': _ref.read(sessionProvider).value?.adminId,
    'created_at': before?['created_at'] ?? _now(),
    'deleted_at': null,
    'version': (before?['version'] as int? ?? 0) + 1,
  };

  String _personalLabel(Json t) => '${t['description']} · ${formatMinor(t['amount_minor'] as int, currency: t['currency'] as String)}';

  Future<String> createPersonal(PersonalTxnIn body) async {
    final l = await _ledger();
    final id = _uuid.v4();
    final data = _personalData(l, id, body, null);
    body.id = id;
    await _queue(OutboxOp(
      method: 'POST',
      path: '/api/v1/personal/transactions',
      body: _json(body.toJson()),
      label: 'Added ${_personalLabel(data)}',
      entities: [_entity('user:${l.me}', 'personal_transaction', id, 1, data)],
      createdAt: _now(),
    ));
    return id;
  }

  Future<void> updatePersonal(String id, PersonalTxnIn body) async {
    final l = await _ledger();
    final before = _required(l.rawPersonal(id), 'Transaction');
    final data = _personalData(l, id, body, before);
    body.version = before['version'] as int;
    await _queue(OutboxOp(
      method: 'PUT',
      path: '/api/v1/personal/transactions/$id',
      body: _json(body.toJson()),
      label: 'Edited ${_personalLabel(data)}',
      entities: [_entity('user:${l.me}', 'personal_transaction', id, data['version'], data)],
      createdAt: _now(),
    ));
  }

  Future<void> deletePersonal(String id) => _setPersonalDeleted(id, true);
  Future<void> restorePersonal(String id) => _setPersonalDeleted(id, false);

  Future<void> _setPersonalDeleted(String id, bool deleted) async {
    final l = await _ledger();
    final before = _required(l.rawPersonal(id), 'Transaction');
    if ((before['deleted_at'] != null) == deleted) return;
    final version = before['version'] as int;
    final data = {...before, 'deleted_at': deleted ? _now() : null, 'version': version + 1};
    await _queue(OutboxOp(
      method: deleted ? 'DELETE' : 'POST',
      path: deleted ? '/api/v1/personal/transactions/$id' : '/api/v1/personal/transactions/$id/restore',
      query: {'version': '$version'},
      label: '${deleted ? 'Deleted' : 'Restored'} ${_personalLabel(before)}',
      entities: [_entity('user:${l.me}', 'personal_transaction', id, version + 1, data)],
      createdAt: _now(),
    ));
  }

  // ---- groups ----

  /// A new group with you as its owner. Returns its id.
  Future<String> createGroup(GroupIn body) async {
    final l = await _ledger();
    final id = _uuid.v4();
    final now = _now();
    final me = l.me;
    body.id = id;
    final stream = 'group:$id';
    await _queue(OutboxOp(
      method: 'POST',
      path: '/api/v1/groups',
      body: _json(body.toJson()),
      label: 'Created ${body.name}',
      entities: [
        _entity(stream, 'group', id, 1, {
          'id': id,
          'name': body.name.trim(),
          'icon': body.icon.value,
          'currency': body.currency.value,
          'created_by': me,
          'created_at': now,
          'archived_at': null,
          'version': 1,
          'last_activity_at': now,
        }),
        _entity(stream, 'member', me, null, {
          'group_id': id,
          'user_id': me,
          'role': 'owner',
          'joined_at': now,
          'left_at': null,
          'placeholder_name': null,
          'user': l.brief(me),
        }),
        _entity('user:$me', 'membership', id, null, {'group_id': id, 'active': true}),
      ],
      createdAt: now,
    ));
    return id;
  }

  Future<void> setGroupArchived(String id, bool archived) async {
    final l = await _ledger();
    final before = _required(l.rawGroup(id), 'Group');
    final version = before['version'] as int;
    await _queue(OutboxOp(
      method: 'PATCH',
      path: '/api/v1/groups/$id',
      body: {'version': version, 'archived': archived},
      label: '${archived ? 'Archived' : 'Unarchived'} ${before['name']}',
      entities: [
        _entity('group:$id', 'group', id, version + 1, {...before, 'archived_at': archived ? _now() : null, 'version': version + 1}),
      ],
      createdAt: _now(),
    ));
  }

  // ---- needs your attention ----

  /// Forgets a refused write; the server's version stays.
  Future<void> discard(OutboxOp op) async {
    final store = await _ref.read(localStoreProvider.future);
    await store.removeOps([op.id!]);
  }

  /// A conflicting edit, sent again on top of the other person's change ("keep mine").
  Future<void> keepMine(OutboxOp op) async {
    final store = await _ref.read(localStoreProvider.future);
    final entity = op.entities.single;
    final current = store.serverEntity(entity.key)?.version;
    if (current == null) {
      await discard(op);
      return;
    }
    final retry = op.copyWith(
      status: OutboxStatus.pending,
      code: '',
      error: '',
      query: op.query.containsKey('version') ? {...op.query, 'version': '$current'} : op.query,
      body: op.body != null && op.body!.containsKey('version') ? {...op.body!, 'version': current} : op.body,
    );
    await store.removeOps([op.id!]);
    await _queue(OutboxOp(
      method: retry.method,
      path: retry.path,
      query: retry.query,
      body: retry.body,
      label: retry.label,
      entities: [LocalEntity(entity.stream, entity.entity, entity.entityId, current + 1, {...entity.data, 'version': current + 1})],
      createdAt: _now(),
    ));
  }
}

/// A generated model's toJson, as plain JSON (dates as the API's calendar days).
Map<String, dynamic> _json(Map<String, dynamic> model) => {
  for (final e in model.entries) e.key: _plain(e.value),
};

Object? _plain(Object? v) => switch (v) {
  DateTime d => DateFormat('yyyy-MM-dd').format(d),
  Map m => {for (final e in m.entries) '${e.key}': _plain(e.value)},
  List l => [for (final x in l) _plain(x)],
  Object o when _hasToJson(o) => _plain((o as dynamic).toJson()),
  _ => v,
};

bool _hasToJson(Object o) {
  try {
    (o as dynamic).toJson;
    return o is! String && o is! num && o is! bool;
  } on NoSuchMethodError {
    return false;
  }
}
