import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../api/api.dart';
import '../categorise/category_rules.dart';
import '../clock.dart';
import '../finance/finance.dart'
    show
        AccountType,
        AllocationKind,
        FinGoal,
        FinPlan,
        FinRule,
        FinanceEngine,
        GoalMode,
        GoalStatus,
        HoldingType,
        MoneyFlow,
        PlanAmount,
        PlanDraft,
        impliedFlow,
        pairedLegId,
        reconcileDelta,
        transferGroupIdFor,
        txnTypeFromWire;
import '../integrations.dart';
import '../money/money.dart';
import '../session/session.dart';
import '../splits/split_engine.dart';
import 'balance_engine.dart';
import 'ledger.dart';
import 'outbox.dart';
import 'personal_index.dart';
import 'providers.dart';

part 'writes_finance.dart';
part 'writes_goals.dart';
part 'writes_holdings.dart';
part 'writes_plans.dart';

/// Writes that work offline: each one is queued in the outbox with the full state it leaves
/// behind, shows on every screen straight away, and is sent by the next sync (which starts
/// right away when there is a connection).
///
/// The entity shapes mirror the server's sync entries (api/app/modules/sync/log.py), so the
/// ledger reads a queued write exactly as it will read the server's copy of it. Adding members,
/// profile, categories and analytics layouts still go straight to the API.
final writesProvider = Provider<LocalWrites>((ref) => LocalWrites(ref));

/// The write was refused before it was queued: a read-only view-as session, or one the server
/// would refuse anyway ([code] and [message] are then the server's, so a write made offline isn't
/// refused only later). An ApiException with the API's error body, so screens show its message
/// like any other refusal.
class WriteRefused extends ApiException {
  WriteRefused(String message, {String code = 'read_only', int status = 403})
    : super(status, jsonEncode({'error': {'code': code, 'message': message}}));
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

  /// Only spending and income teach (personal/service.py _learn): transfers, refunds and the rest
  /// don't.
  List<LocalEntity> _learnPersonal(Ledger l, Json data) => data['type'] == 'income' || data['type'] == 'expense'
      ? _learn(l, data['merchant'] as String? ?? data['description'] as String?, data['category_id'] as String?, income: data['type'] == 'income')
      : const [];

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

  /// The entry as the server will store it ([_personalJson]).
  Json _personalData(Ledger l, String id, PersonalTxnIn body, Json? before) =>
      _personalJson(l, id, body, before, now: _now(), adminId: _ref.read(sessionProvider).value?.adminId);

  String _personalLabel(Json t) => '${t['description']} · ${formatMinor(t['amount_minor'] as int, currency: t['currency'] as String)}';

  /// Trimmed, and blank as none (personal/service.py _text).
  static String? _text(String? value) {
    final t = value?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  /// [id]: one made from the entry itself (a bank SMS), so making it twice gives the same row.
  /// Checked as the server checks it ([_Draft]); a transfer leg can't be made alone
  /// ([createTransfer]). An income the allocation rules apply to goes with its plans in one
  /// `POST /personal/batch` [entry, plan creates]; anything else is a plain POST.
  Future<String> createPersonal(PersonalTxnIn body, {String? id}) async {
    final l = await _ledger();
    id ??= _uuid.v4();
    // The entry, its plans, and the category rule a manual one teaches (the app guessed an SMS
    // entry's).
    final draft = _Draft(this, l)..addEntryCreate(id, body);
    final label = 'Added ${_personalLabel(_personalData(l, id, body, null))}';
    if (draft._items.length > 1) {
      await _queue(draft.op(label));
      return id;
    }
    final entities = draft.finish();
    body.id = id;
    await _queue(OutboxOp(
      method: 'POST',
      path: '/api/v1/personal/transactions',
      body: _json(body.toJson()),
      label: label,
      entities: entities,
      createdAt: _now(),
    ));
    return id;
  }

  Future<void> updatePersonal(String id, PersonalTxnIn body) async {
    final l = await _ledger();
    await _queueAll(_updatePersonalOps(l, id, body));
  }

  /// Every edit of an entry goes through here. Checked as the server checks it ([_Draft]): one
  /// leg of a transfer can't change its amount, account or direction alone ([updateTransfer]).
  ///
  /// When the edit changes an income's plans (reconcilePlans in core/finance/allocation.dart), it's
  /// one `POST /personal/batch` [plan deletes, the entry, plan updates, plan creates, plan
  /// deletes], so a type change sends the plan deletes first; otherwise a plain PUT. A deleted
  /// plan that applies again comes back with ops of its own after it ([_Draft.ops]).
  List<OutboxOp> _updatePersonalOps(Ledger l, String id, PersonalTxnIn body) {
    final before = _required(l.rawPersonal(id), 'Transaction');
    final draft = _Draft(this, l)..addEntryUpdate(id, body);
    if (draft._items.length > 1) {
      return draft.ops('Edited ${_personalLabel(draft.entry(id)!)}');
    }
    final restores = draft._takeRestores();
    // The entry first, then the category rule a changed category teaches.
    final entities = draft.finish();
    body.version = before['version'] as int;
    return [
      OutboxOp(
        method: 'PUT',
        path: '/api/v1/personal/transactions/$id',
        body: _json(body.toJson()),
        label: 'Edited ${_personalLabel(entities.first.data)}',
        entities: entities,
        createdAt: _now(),
      ),
      ..._planRestoreOps(l, restores),
    ];
  }

  // ---- personal entries in Split (core/integrations.dart) ----

  PersonalTxnIn _bodyOf(Ledger l, String id) => personalBody(PersonalTxnOut.fromJson(l.personalTransaction(id))!);

  /// Splits personal entry [txnId] into a group expense: the expense, then the entry linked to
  /// it (and so looked at). Queued together, so neither shows without the other. Returns the
  /// expense's id.
  Future<String> splitPersonal(String txnId, String groupId, ExpenseIn body) async {
    final l = await _ledger();
    final expense = _createExpenseOp(l, groupId, body);
    final link = _updatePersonalOps(
      l,
      txnId,
      _bodyOf(l, txnId)
        ..expenseId = body.id
        ..settlementId = null
        ..reviewed = true,
    );
    await _queueAll([expense, ...link]);
    return body.id!;
  }

  /// Links entry [txnId] to a split you paid ([expenseId]) or a payment ([settlementId]), or
  /// unlinks it when both are null. Either way it has been looked at.
  Future<void> linkPersonal(String txnId, {String? expenseId, String? settlementId}) async {
    final l = await _ledger();
    await _queueAll(
      _updatePersonalOps(
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
    await _queueAll(_updatePersonalOps(l, txnId, _bodyOf(l, txnId)..reviewed = true));
  }

  /// Deleting or restoring a transfer leg takes the other leg with it, as the server does
  /// (personal/service.py change_deleted), so both show at once.
  Future<void> deletePersonal(String id) => _setPersonalDeleted(id, true);
  Future<void> restorePersonal(String id) => _setPersonalDeleted(id, false);

  Future<void> _setPersonalDeleted(String id, bool deleted) async {
    final l = await _ledger();
    final before = _required(l.rawPersonal(id), 'Transaction');
    if ((before['deleted_at'] != null) == deleted) return;
    final version = before['version'] as int;
    // The entry addressed first (keepMine re-versions by it), then a transfer leg's partner.
    final entities = (_Draft(this, l).._setDeleted(id, deleted)).finish();
    await _queue(OutboxOp(
      method: deleted ? 'DELETE' : 'POST',
      path: deleted ? '/api/v1/personal/transactions/$id' : '/api/v1/personal/transactions/$id/restore',
      query: {'version': '$version'},
      label: '${deleted ? 'Deleted' : 'Restored'} ${_personalLabel(before)}',
      entities: entities,
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

  /// A conflicting edit, sent again on top of the other person's change ("keep mine"): at the
  /// server's versions now. A single request's version is its first entity's (the one it
  /// addresses); a batch's are each item's. Every entity it changes that the server has (a
  /// transfer's other leg, entries an account claims) is laid over at the version after.
  Future<void> keepMine(OutboxOp op) async {
    final store = await _ref.read(localStoreProvider.future);
    if (op.entities.isEmpty) return discard(op);
    int? server(String entity, String id) =>
        store.serverEntity(LocalEntity.keyOf(op.entities.first.stream, entity, id))?.version;
    var (query, body) = (op.query, op.body);
    if (body?['items'] case final List items) {
      final sent = <Map<String, dynamic>>[];
      for (final item in items.cast<Map>().map((i) => i.cast<String, dynamic>())) {
        if (item['version'] == null) {
          sent.add(item);
          continue;
        }
        final entity = switch (item['kind']) {
          'account' => 'personal_account',
          'goal' => 'personal_goal',
          'goal_contribution' => 'personal_goal_contribution',
          'holding' => 'personal_holding',
          'allocation_rule' => 'personal_allocation_rule',
          'allocation_plan' => 'personal_allocation_plan',
          _ => 'personal_transaction',
        };
        final now = server(entity, item['id'] as String);
        if (now == null) return discard(op);
        sent.add({...item, 'version': now});
      }
      body = {...body!, 'items': sent};
    } else {
      final current = store.serverEntity(op.entities.first.key)?.version;
      if (current == null) return discard(op);
      if (query.containsKey('version')) query = {...query, 'version': '$current'};
      if (body != null && body.containsKey('version')) body = {...body, 'version': current};
    }
    await store.removeOps([op.id!]);
    await _queue(OutboxOp(
      method: op.method,
      path: op.path,
      query: query,
      body: body,
      label: op.label,
      entities: [
        for (final e in op.entities)
          if (store.serverEntity(e.key)?.version case final v? when e.version != null)
            LocalEntity(e.stream, e.entity, e.entityId, v + 1, {...e.data, 'version': v + 1})
          else
            e,
      ],
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

/// The full PUT body for an entry as it is now. The API applies every field it's sent (the
/// generated client sends every key, null too), so an edit starts from this and changes only what
/// it means to: its account, direction, transfer, refund and holding links included.
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
  accountId: t.accountId,
  direction: PersonalTxnInDirectionEnum.fromJson(t.direction.value),
  transferGroupId: t.transferGroupId,
  refundOfId: t.refundOfId,
  holdingId: t.holdingId,
  source_: PersonalTxnInSource_Enum.fromJson(t.source_.value)!,
  reference: t.reference,
  balanceMinor: t.balanceMinor,
  smsAt: t.smsAt,
);

/// Entry [id] as the server will store it, made from [body] ([before]: as it is now, or null for a
/// new one) [now], by admin [adminId] if acting as you. Where it came from (source, reference,
/// balance, SMS time) is set when it's made: on an edit the server ignores those, so they're kept
/// from [before].
Json _personalJson(Ledger l, String id, PersonalTxnIn body, Json? before, {required String now, String? adminId}) => {
  'id': id,
  'user_id': l.me,
  'type': body.type.value,
  // The way the type implies; a transfer or a correction says its own (or keeps it).
  'direction': impliedFlow(txnTypeFromWire(body.type.value)!)?.wire ?? body.direction?.value ?? before?['direction'],
  'amount_minor': body.amountMinor,
  'currency': before?['currency'] ?? l.userOut()['currency'],
  'category_id': body.categoryId,
  'date': LocalWrites._day(body.date),
  'description': body.description.trim(),
  'notes': body.notes,
  'channel': body.channel?.value,
  'merchant': LocalWrites._text(body.merchant),
  'account': LocalWrites._text(body.account),
  'source': before == null ? body.source_.value : before['source'] ?? 'manual',
  'reference': before == null ? LocalWrites._text(body.reference) : before['reference'],
  'balance_minor': before == null ? body.balanceMinor : before['balance_minor'],
  'sms_at': before == null ? body.smsAt?.toUtc().toIso8601String() : before['sms_at'],
  'reviewed': body.reviewed,
  'expense_id': body.expenseId,
  'settlement_id': body.settlementId,
  'account_id': body.accountId,
  'transfer_group_id': body.transferGroupId,
  'refund_of_id': body.refundOfId,
  'holding_id': body.holdingId,
  'acting_admin_id': adminId,
  'created_at': before?['created_at'] ?? now,
  'deleted_at': null,
  'version': (before?['version'] as int? ?? 0) + 1,
};
