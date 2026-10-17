import 'dart:convert';
import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../api/api.dart';
import '../categorise/category_rules.dart';
import '../clock.dart';
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

/// The write was refused before it was queued (a read-only view-as session). An ApiException
/// with the API's error body, so screens show its message like any other refusal.
class WriteRefused extends ApiException {
  WriteRefused(String message)
    : super(403, jsonEncode({'error': {'code': 'read_only', 'message': message}}));
}

class LocalWrites {
  LocalWrites(this._ref);
  final Ref _ref;

  static const _uuid = Uuid();

  /// Every write starts here, so a read-only view-as is refused before anything is queued.
  Future<Ledger> _ledger() async {
    if (_ref.read(sessionProvider).value?.readOnly ?? false) {
      throw WriteRefused('You are viewing as this user in read-only mode');
    }
    return (await _ref.read(localStoreProvider.future)).ledger;
  }

  String _now() => appClock.now().toUtc().toIso8601String();
  static String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _queue(OutboxOp op) => _queueAll([op]);

  Future<void> _queueAll(List<OutboxOp> ops) async {
    final store = await _ref.read(localStoreProvider.future);
    await store.enqueueAll(ops);
    final engine = await _ref.read(syncEngineProvider.future);
    engine.pull().ignore();
  }

  LocalEntity _entity(String stream, String entity, String id, int? version, Map<String, dynamic> data) =>
      LocalEntity(stream, entity, id, version, data);

  Json _required(Json? row, String what) => row ?? (throw LocalNotFound(what));

  /// The rule a category you chose teaches (api categories/rules.py learn), laid over the
  /// synced data until the server's copy, with the same id, replaces it. None without a
  /// category, or for an admin acting as you (the server learns nothing from those).
  List<LocalEntity> _learn(Ledger l, String? text, String? categoryId, {bool income = false}) {
    final pattern = rulePattern(text);
    if (categoryId == null || pattern.isEmpty || _ref.read(sessionProvider).value?.adminId != null) return const [];
    final id = ruleId(l.me, income: income, pattern: pattern);
    return [
      _entity('user:${l.me}', 'category_rule', id, null, {
        'id': id,
        'user_id': l.me,
        'pattern': pattern,
        'income': income,
        'category_id': categoryId,
        'updated_at': _now(),
      }),
    ];
  }

  List<LocalEntity> _learnPersonal(Ledger l, Json data) =>
      _learn(l, data['merchant'] as String? ?? data['description'] as String?, data['category_id'] as String?, income: data['type'] == 'income');

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
    await _queue(_createExpenseOp(l, groupId, body));
    return body.id!;
  }

  /// Gives [body] its id.
  OutboxOp _createExpenseOp(Ledger l, String groupId, ExpenseIn body) {
    final id = body.id = _uuid.v4();
    final data = _expenseData(l, id: id, groupId: groupId, body: body);
    return OutboxOp(
      method: 'POST',
      path: '/api/v1/groups/$groupId/expenses',
      body: _json(body.toJson()),
      label: 'Added ${_expenseLabel(data)}',
      entities: [
        _entity('group:$groupId', 'expense', id, data['version'], data),
        ..._learn(l, body.description, body.categoryId),
      ],
      createdAt: _now(),
    );
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
      entities: [
        _entity('group:$groupId', 'expense', id, data['version'], data),
        if (before['category_id'] != body.categoryId) ..._learn(l, body.description, body.categoryId),
      ],
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

  /// The entry as the server will store it. Where it came from (source, reference, balance,
  /// SMS time) is set when it's made: on an edit the server ignores those, so they're kept
  /// from [before].
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
    'channel': body.channel?.value,
    'merchant': _text(body.merchant),
    'account': _text(body.account),
    'source': before == null ? body.source_.value : before['source'] ?? 'manual',
    'reference': before == null ? _text(body.reference) : before['reference'],
    'balance_minor': before == null ? body.balanceMinor : before['balance_minor'],
    'sms_at': before == null ? body.smsAt?.toUtc().toIso8601String() : before['sms_at'],
    'reviewed': body.reviewed,
    'expense_id': body.expenseId,
    'settlement_id': body.settlementId,
    'acting_admin_id': _ref.read(sessionProvider).value?.adminId,
    'created_at': before?['created_at'] ?? _now(),
    'deleted_at': null,
    'version': (before?['version'] as int? ?? 0) + 1,
  };

  String _personalLabel(Json t) => '${t['description']} · ${formatMinor(t['amount_minor'] as int, currency: t['currency'] as String)}';

  /// Trimmed, and blank as none (personal/service.py _text).
  static String? _text(String? value) {
    final t = value?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  /// [id]: one made from the entry itself (a bank SMS), so making it twice gives the same row.
  Future<String> createPersonal(PersonalTxnIn body, {String? id}) async {
    final l = await _ledger();
    id ??= _uuid.v4();
    final data = _personalData(l, id, body, null);
    body.id = id;
    await _queue(OutboxOp(
      method: 'POST',
      path: '/api/v1/personal/transactions',
      body: _json(body.toJson()),
      label: 'Added ${_personalLabel(data)}',
      entities: [
        _entity('user:${l.me}', 'personal_transaction', id, 1, data),
        // The app guessed an SMS entry's category; you chose a manual one's.
        if (body.source_ != PersonalTxnInSource_Enum.sms) ..._learnPersonal(l, data),
      ],
      createdAt: _now(),
    ));
    return id;
  }

  Future<void> updatePersonal(String id, PersonalTxnIn body) async {
    final l = await _ledger();
    await _queue(_updatePersonalOp(l, id, body));
  }

  OutboxOp _updatePersonalOp(Ledger l, String id, PersonalTxnIn body) {
    final before = _required(l.rawPersonal(id), 'Transaction');
    final data = _personalData(l, id, body, before);
    body.version = before['version'] as int;
    return OutboxOp(
      method: 'PUT',
      path: '/api/v1/personal/transactions/$id',
      body: _json(body.toJson()),
      label: 'Edited ${_personalLabel(data)}',
      entities: [
        _entity('user:${l.me}', 'personal_transaction', id, data['version'], data),
        if (before['category_id'] != data['category_id']) ..._learnPersonal(l, data),
      ],
      createdAt: _now(),
    );
  }

  /// Entries read from bank SMS, each with the id the message gives it: POST
  /// /personal/transactions/batch in chunks of [chunk], queued together (one rebuild however
  /// many).
  Future<void> importPersonal(List<(String, PersonalTxnIn)> entries, {int chunk = 50}) =>
      importSms(entries, const [], chunk: chunk);

  /// What a read of the bank SMS found, queued together (one rebuild): new [entries], as
  /// [importPersonal] queues them, then entries you'd made by hand that a message was about,
  /// edited to [attached] (id and new body), as [updatePersonal] would.
  Future<void> importSms(
    List<(String, PersonalTxnIn)> entries,
    List<(String, PersonalTxnIn)> attached, {
    int chunk = 50,
  }) async {
    if (entries.isEmpty && attached.isEmpty) return;
    final l = await _ledger();
    await _queueAll([
      for (var i = 0; i < entries.length; i += chunk) _batchOp(l, entries.sublist(i, min(i + chunk, entries.length))),
      for (final (id, body) in attached) _updatePersonalOp(l, id, body),
    ]);
  }

  OutboxOp _batchOp(Ledger l, List<(String, PersonalTxnIn)> part) => OutboxOp(
    method: 'POST',
    path: '/api/v1/personal/transactions/batch',
    body: {
      'items': [for (final (id, body) in part) _json((body..id = id).toJson())],
    },
    label: part.length == 1 ? 'Added ${part.single.$2.description} from an SMS' : 'Added ${part.length} entries from bank SMS',
    entities: [
      for (final (id, body) in part) _entity('user:${l.me}', 'personal_transaction', id, 1, _personalData(l, id, body, null)),
    ],
    createdAt: _now(),
  );

  // ---- personal entries in Split (core/integrations.dart) ----

  PersonalTxnIn _bodyOf(Ledger l, String id) => personalBody(PersonalTxnOut.fromJson(l.personalTransaction(id))!);

  /// Splits personal entry [txnId] into a group expense: the expense, then the entry linked to
  /// it (and so looked at). Queued together, so neither shows without the other. Returns the
  /// expense's id.
  Future<String> splitPersonal(String txnId, String groupId, ExpenseIn body) async {
    final l = await _ledger();
    final expense = _createExpenseOp(l, groupId, body);
    final link = _updatePersonalOp(
      l,
      txnId,
      _bodyOf(l, txnId)
        ..expenseId = body.id
        ..settlementId = null
        ..reviewed = true,
    );
    await _queueAll([expense, link]);
    return body.id!;
  }

  /// Links entry [txnId] to a split you paid ([expenseId]) or a payment ([settlementId]), or
  /// unlinks it when both are null. Either way it has been looked at.
  Future<void> linkPersonal(String txnId, {String? expenseId, String? settlementId}) async {
    final l = await _ledger();
    await _queue(
      _updatePersonalOp(
        l,
        txnId,
        _bodyOf(l, txnId)
          ..expenseId = expenseId
          ..settlementId = settlementId
          ..reviewed = true,
      ),
    );
  }

  /// "Looks right": an entry the app added from a bank SMS has been looked at.
  Future<void> reviewPersonal(String txnId) async {
    final l = await _ledger();
    await _queue(_updatePersonalOp(l, txnId, _bodyOf(l, txnId)..reviewed = true));
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
          'invite_email': null,
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

final _calendarDay = DateFormat('yyyy-MM-dd');

/// A generated model's toJson, as plain JSON (dates as the API's calendar days).
Map<String, dynamic> _json(Map<String, dynamic> model) => {
  for (final e in model.entries) e.key: _plain(e.value),
};

Object? _plain(Object? v) => switch (v) {
  // Plain values first: asking one for toJson throws (and catching it is slow).
  null || String() || num() || bool() => v,
  DateTime d => _calendarDay.format(d),
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

/// The full PUT body for an entry as it is now. The API applies every field it's sent, so an
/// edit starts from this and changes only what it means to.
PersonalTxnIn personalBody(PersonalTxnOut t) => PersonalTxnIn(
  type: PersonalTxnInTypeEnum.fromJson(t.type.value)!,
  amountMinor: t.amountMinor,
  description: t.description,
  date: apiDate(t.date),
  categoryId: t.category?.id,
  notes: t.notes,
  channel: PersonalTxnInChannelEnum.fromJson(t.channel?.value),
  merchant: t.merchant,
  account: t.account,
  expenseId: t.expenseId,
  settlementId: t.settlementId,
  reviewed: t.reviewed,
  source_: PersonalTxnInSource_Enum.fromJson(t.source_.value)!,
  reference: t.reference,
  balanceMinor: t.balanceMinor,
  smsAt: t.smsAt,
);
