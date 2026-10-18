part of 'writes.dart';

// The personal ledger's writes (finance revamp Phase 1, design §4.4): accounts, transfers,
// refunds and Reconcile, the POST /personal/batch plumbing they share, and the chunker the bank
// SMS importer queues what it read with.

/// One item of `POST /personal/batch` (personal/schemas.py PersonalBatchItem): an account made or
/// changed, or an entry made, changed or deleted.
///
/// Payloads are the full state the account or entry is left in. The server keeps a field only
/// when its key is left out, and the generated client sends every key (null too), so an edit
/// starts from the entry as it is ([personalBody]) and changes only what it means to. The version
/// an update or a delete sends is filled in from what the device has when it's queued.
final class BatchItem {
  BatchItem.createAccount(this.id, PersonalAccountIn this.account)
    : kind = PersonalBatchItemKindEnum.account,
      op = PersonalBatchItemOpEnum.create,
      transaction = null;

  BatchItem.updateAccount(this.id, PersonalAccountIn this.account)
    : kind = PersonalBatchItemKindEnum.account,
      op = PersonalBatchItemOpEnum.update,
      transaction = null;

  BatchItem.createEntry(this.id, PersonalTxnIn this.transaction)
    : kind = PersonalBatchItemKindEnum.transaction,
      op = PersonalBatchItemOpEnum.create,
      account = null;

  BatchItem.updateEntry(this.id, PersonalTxnIn this.transaction)
    : kind = PersonalBatchItemKindEnum.transaction,
      op = PersonalBatchItemOpEnum.update,
      account = null;

  /// As DELETE does: a transfer leg takes its partner with it.
  BatchItem.deleteEntry(this.id)
    : kind = PersonalBatchItemKindEnum.transaction,
      op = PersonalBatchItemOpEnum.delete,
      account = null,
      transaction = null;

  final PersonalBatchItemKindEnum kind;
  final PersonalBatchItemOpEnum op;

  /// create: the id to make it with; update and delete: what to change.
  final String id;
  final PersonalAccountIn? account;
  final PersonalTxnIn? transaction;

  bool get isAccountCreate => kind == PersonalBatchItemKindEnum.account && op == PersonalBatchItemOpEnum.create;

  @override
  String toString() => 'BatchItem(${kind.value} ${op.value} $id)';
}

/// The server's refusal, made on the device before anything is queued.
Never _refuse(String code, String message, {int status = 422}) =>
    throw WriteRefused(message, code: code, status: status);

/// What a write leaves on the device, worked out item by item as the server applies a batch
/// (personal/batch.py run): each item starts from the state earlier items left, in the same
/// request or in an earlier one queued with it, and is checked as the server checks it
/// (personal/service.py _validate, transfers.check_groups, accounts._check_label), so a write
/// made offline isn't refused only once it's sent.
///
/// Besides each item's own entity it mirrors what the server changes with it: a deleted or
/// restored transfer leg's partner (service.change_deleted), the entries an account made,
/// relabelled or reopened claims (accounts._claim), and the category rule a choice teaches. Every
/// one goes in the write's entities, so the sync engine waits for all of them.
class _Draft {
  _Draft(LocalWrites w, Ledger l)
    : _w = w,
      _l = l,
      _stream = 'user:${l.me}',
      _now = w._now(),
      _adminId = w._ref.read(sessionProvider).value?.adminId;

  final LocalWrites _w;
  final Ledger _l;
  final String _stream;

  /// One time for the whole write, as the server takes one: a transfer's legs are deleted at the
  /// same moment.
  final String _now;
  final String? _adminId;

  static const _entry = 'personal_transaction', _account = 'personal_account';

  /// Every entity changed so far, by key: what later items start from.
  final _states = <String, LocalEntity>{};

  /// This request's changes, by key, in the order first changed.
  var _changed = <String, LocalEntity>{};

  /// This request's items, as sent.
  var _items = <Json>[];

  /// The transfer groups this request touched, and whether a create touched each.
  var _groups = <String, bool>{};

  /// The entries accounts made or changed in this request claimed.
  var _claimed = <String>{};

  /// Every entry an account in this write claimed, and the account.
  final _claimedBy = <String, String>{};

  /// While [addUnit] adds a unit: how to take back each change it made (oldest first), and the
  /// transfer groups it touched.
  List<void Function()>? _undo;
  Set<String>? _unitGroups;

  /// Sets [map]'s [key] to [value], noting how to take it back while a unit is being added.
  void _put<K, V>(Map<K, V> map, K key, V value) {
    if (_undo case final undo?) {
      final had = map.containsKey(key), was = map[key];
      undo.add(() {
        if (had) {
          map[key] = was as V;
        } else {
          map.remove(key);
        }
      });
    }
    map[key] = value;
  }

  /// Notes that this request touched transfer [group] ([created]: an item made one of its legs).
  void _touch(String group, {bool created = false}) {
    _unitGroups?.add(group);
    if (created) {
      _put(_groups, group, true);
    } else if (!_groups.containsKey(group)) {
      _put(_groups, group, false);
    }
  }

  /// Entry [id] as the items so far leave it (deleted ones too), or null.
  Json? entry(String id) => _states[LocalEntity.keyOf(_stream, _entry, id)]?.data ?? _l.rawPersonal(id);

  /// Account [id] as the items so far leave it (deleted ones too), or null.
  Json? account(String id) => _states[LocalEntity.keyOf(_stream, _account, id)]?.data ?? _l.rawAccount(id);

  void _set(String entity, Json data) {
    final e = LocalEntity(_stream, entity, data['id'] as String, data['version'] as int, data);
    _put(_states, e.key, e);
    _put(_changed, e.key, e);
  }

  /// Applies [item] and keeps it to send.
  void add(BatchItem item) {
    final isAccount = item.kind == PersonalBatchItemKindEnum.account;
    int? version;
    if (item.op != PersonalBatchItemOpEnum.create) {
      // The server sees a claimed entry's old version until its next flush, so the device can't
      // tell which version an edit in the same request should send.
      if (_claimed.contains(item.id)) {
        throw StateError('$item changes an entry an account claimed earlier in this request: send it in a later one');
      }
      final before = isAccount ? account(item.id) : entry(item.id);
      version = (before ?? (throw LocalNotFound(isAccount ? 'Account' : 'Transaction')))['version'] as int;
    }
    switch ((item.kind.value, item.op.value)) {
      case ('account', 'create'):
        _createAccount(item.id, item.account!);
      case ('account', _):
        _updateAccount(item.id, item.account!);
      case (_, 'create'):
        _createEntry(item.id, item.transaction!);
      case (_, 'update'):
        _updateEntry(item.id, item.transaction!);
      case _:
        _setDeleted(item.id, true);
    }
    final json = _json(
      PersonalBatchItem(
        kind: item.kind,
        op: item.op,
        id: item.id,
        version: version,
        account: item.account,
        transaction: item.transaction,
      ).toJson(),
    );
    // The item carries the id and the version; the payload leaves them out.
    for (final payload in [json['account'], json['transaction']]) {
      if (payload is Map) {
        payload['id'] = null;
        payload['version'] = null;
      }
    }
    _items.add(json);
    if (_undo case final undo?) {
      final items = _items;
      undo.add(items.removeLast);
    }
  }

  /// Applies every item of [unit], or none: if one is refused, or the unit leaves a transfer it
  /// touched broken, the draft is put back as it was before the unit and the refusal rethrown.
  void addUnit(List<BatchItem> unit) {
    final undo = _undo = <void Function()>[];
    final groups = _unitGroups = <String>{};
    try {
      unit.forEach(add);
      _checkTransfers(groups);
    } catch (_) {
      for (final step in undo.reversed) {
        step();
      }
      rethrow;
    } finally {
      _undo = null;
      _unitGroups = null;
    }
  }

  /// Whether [unit] changes an entry an account claimed in this request ([add] refuses that).
  bool claims(Iterable<BatchItem> unit) =>
      unit.any((i) => i.op != PersonalBatchItemOpEnum.create && _claimed.contains(i.id));

  /// Checks the transfers this request touched are whole, and hands back the state everything it
  /// changed is left in, each entity once, in the order first changed. Starts the next request.
  List<LocalEntity> finish() {
    _checkTransfers();
    final out = _changed.values.toList();
    _changed = {};
    _items = [];
    _groups = {};
    _claimed = {};
    return out;
  }

  /// This request as one `POST /personal/batch` ([finish]).
  OutboxOp op(String label) {
    final items = _items;
    final entities = finish();
    return OutboxOp(
      method: 'POST',
      path: '/api/v1/personal/batch',
      body: {'items': items},
      label: label,
      entities: entities,
      createdAt: _w._now(),
    );
  }

  // ---- entries (personal/service.py create, update, change_deleted) ----

  void _createEntry(String id, PersonalTxnIn body) {
    // A repeated create gives back the entry that's there, unchanged (versioning.replayed_create).
    if (entry(id) != null) return;
    final data = _w._personalData(_l, id, body, null);
    _checkEntry(data, null);
    _set(_entry, data);
    if (data['transfer_group_id'] case final String group) _touch(group, created: true);
    // The app guessed an SMS entry's category; you chose a manual one's.
    if (body.source_ != PersonalTxnInSource_Enum.sms) _learn(data);
  }

  void _updateEntry(String id, PersonalTxnIn body) {
    final before = entry(id) ?? (throw const LocalNotFound('Transaction'));
    if (before['deleted_at'] != null) _refuse('deleted', 'Restore this entry before editing it', status: 409);
    // A body made before an account in this write claimed the entry doesn't know the account yet:
    // sent as it is, it would take the entry out again.
    if (body.accountId == null && _claimedBy[id] != null) body.accountId = _claimedBy[id];
    // A transfer or a correction left without a direction keeps its own, unless it was another type.
    if (body.direction == null &&
        impliedFlow(txnTypeFromWire(body.type.value)!) == null &&
        before['type'] != body.type.value) {
      _refuse('direction_required', 'Say whether money came in or went out');
    }
    final data = _w._personalData(_l, id, body, before);
    _checkEntry(data, before);
    _set(_entry, data);
    for (final group in {before['transfer_group_id'], data['transfer_group_id']}) {
      if (group is String) _touch(group);
    }
    if (before['category_id'] != data['category_id']) _learn(data);
  }

  /// Deletes or restores entry [id], and a transfer leg's partner in the same state with it.
  void _setDeleted(String id, bool deleted) {
    final t = entry(id) ?? (throw const LocalNotFound('Transaction'));
    if ((t['deleted_at'] != null) == deleted) return;
    final group = t['transfer_group_id'] as String?;
    final legs = [
      t,
      if (group != null)
        for (final other in _legsOf(group))
          if (other['id'] != id && (other['deleted_at'] != null) != deleted) other,
    ];
    for (final leg in legs) {
      if (!deleted && leg['account_id'] != null) {
        final a = account(leg['account_id'] as String);
        if (a == null || a['deleted_at'] != null) {
          _refuse('unknown_account', "This entry's account was deleted. Restore the account first");
        }
      }
      _set(_entry, {
        ...leg,
        'deleted_at': deleted ? _now : null,
        'acting_admin_id': _adminId,
        'version': (leg['version'] as int) + 1,
      });
    }
    if (group != null) _touch(group);
  }

  void _learn(Json data) {
    for (final e in _w._learnPersonal(_l, data)) {
      _put(_changed, e.key, e);
    }
  }

  /// What personal/service.py _validate refuses that the device can know: [t] as the write
  /// leaves it, [before] what it was (null for a new entry).
  void _checkEntry(Json t, Json? before) {
    final type = t['type'] as String;
    final amount = t['amount_minor'] as int;
    if (amount <= 0) _refuse('invalid_input', 'Enter an amount above zero');
    if (amount > maxAmountMinor) _refuse('invalid_input', 'That amount is too large');
    if ((t['description'] as String).isEmpty) _refuse('invalid_input', "Description can't be empty");
    if (t['direction'] == null) _refuse('direction_required', 'Say whether money came in or went out');
    final moves = type == 'transfer' || type == 'adjustment';
    if (moves && t['category_id'] != null) {
      _refuse('category_not_allowed', "Transfers and balance corrections don't have a category");
    }
    if ((t['expense_id'] != null || t['settlement_id'] != null) && type != 'income' && type != 'expense') {
      _refuse('link_invalid', 'Only spending and income can be linked to Split');
    }
    if (t['refund_of_id'] != null && type != 'refund') _refuse('refund_invalid', 'Only a refund can point at a spend');
    if (t['transfer_group_id'] != null && type != 'transfer') {
      _refuse('transfer_invalid', 'Only a transfer has a transfer_group_id');
    }
    if (type == 'transfer' && t['account_id'] == null) {
      _refuse('transfer_invalid', 'A transfer needs an account on each side');
    }
    if (type == 'transfer' && t['transfer_group_id'] == null) {
      _refuse('transfer_invalid', 'Give both halves of a transfer the same transfer_group_id');
    }
    if (type == 'adjustment' && t['account_id'] == null) _refuse('account_required', 'Pick the account to correct');
    // An account it moves into (a new entry, or one changing account): an entry that stays in a
    // closed account can still be edited.
    final accountId = t['account_id'] as String?;
    if (accountId != null && accountId != before?['account_id']) {
      final a = account(accountId);
      if (a == null || a['deleted_at'] != null) _refuse('unknown_account', "That account isn't available");
      if (a['status'] == 'closed') _refuse('account_closed', 'That account is closed');
      if (a['currency'] != t['currency']) {
        _refuse('currency_mismatch', 'That account is in ${a['currency']}; this entry is in ${t['currency']}');
      }
    }
    // The spend must be yours and live when the refund is pointed at it, and at least as much.
    final of = t['refund_of_id'] as String?;
    if (of != null) {
      final pointed = before == null || of != before['refund_of_id'];
      final original = entry(of);
      if (pointed && (original == null || original['deleted_at'] != null || original['type'] != 'expense')) {
        _refuse('unknown_refund_target', "That spend isn't available");
      }
      final resized = pointed || amount != before['amount_minor'];
      if (original != null && resized && amount > (original['amount_minor'] as int)) {
        _refuse('refund_too_large', "A refund can't be more than the spend");
      }
    }
  }

  /// The entries in transfer [group], live and deleted, as the items so far leave them.
  List<Json> _legsOf(String group) {
    final ids = <String>{
      for (final e in _l.finance.transferLegs(group)) e.id,
      for (final s in _states.values)
        if (s.entity == _entry && s.data['transfer_group_id'] == group) s.entityId,
    };
    return [
      for (final id in ids)
        if (entry(id) case final t? when t['transfer_group_id'] == group) t,
    ];
  }

  /// transfers.check_groups: each group this request touched (or of [groups]) has no live legs, or
  /// a whole pair.
  void _checkTransfers([Iterable<String>? groups]) {
    for (final group in groups ?? _groups.keys) {
      final created = _groups[group] ?? false;
      final legs = [
        for (final t in _legsOf(group))
          if (t['deleted_at'] == null) t,
      ];
      if (legs.isEmpty) continue;
      if (legs.length == 1) {
        _refuse(
          'transfer_unpaired',
          created
              ? 'A transfer needs both halves in one request (POST /personal/batch)'
              : 'Change both halves of a transfer together',
        );
      }
      if (legs.length > 2) _refuse('transfer_invalid', 'A transfer has two halves, not more');
      final (a, b) = (legs[0], legs[1]);
      if (a['amount_minor'] != b['amount_minor']) {
        _refuse('transfer_invalid', 'Both halves of a transfer must be the same amount');
      }
      if (a['currency'] != b['currency']) {
        _refuse('transfer_invalid', 'Both halves of a transfer must be in the same currency');
      }
      final directions = {a['direction'], b['direction']};
      if (!directions.contains('in') || !directions.contains('out')) {
        _refuse('transfer_invalid', 'One half goes out and the other comes in');
      }
      if (a['account_id'] == b['account_id']) {
        _refuse('transfer_invalid', 'A transfer moves money between two different accounts');
      }
    }
  }

  // ---- accounts (personal/accounts.py create, update) ----

  void _createAccount(String id, PersonalAccountIn body) {
    // A repeated create gives back the account that's there, unchanged, and claims nothing.
    if (account(id) != null) return;
    final data = _accountData(id, body, null);
    _checkLabel(data['sms_label'] as String?, id);
    _set(_account, data);
    _claim(data);
  }

  void _updateAccount(String id, PersonalAccountIn body) {
    final before = account(id) ?? (throw const LocalNotFound('Account'));
    if (before['deleted_at'] != null) _refuse('deleted', 'Restore this account before editing it', status: 409);
    final data = _accountData(id, body, before);
    if (data['sms_label'] != before['sms_label']) _checkLabel(data['sms_label'] as String?, id);
    final changed = {
      for (final k in const ['name', 'type', 'opening_balance_minor', 'sms_label', 'status'])
        if (data[k] != before[k]) k,
    };
    // The server leaves an account nothing changes as it is, version too.
    if (changed.isEmpty) return;
    _set(_account, data);
    if (changed.contains('sms_label') || changed.contains('status')) _claim(data);
  }

  /// The account as the server stores it (personal_accounts, as the sync log sends it).
  Json _accountData(String id, PersonalAccountIn body, Json? before) => {
    'id': id,
    'user_id': _l.me,
    'name': body.name.trim(),
    'type': body.type.value,
    'currency': before?['currency'] ?? _l.userOut()['currency'],
    'opening_balance_minor': body.openingBalanceMinor,
    'sms_label': LocalWrites._text(body.smsLabel),
    'status': body.status?.value ?? before?['status'] ?? 'active',
    'acting_admin_id': _adminId,
    'created_at': before?['created_at'] ?? _now,
    'updated_at': _now,
    'deleted_at': null,
    'version': (before?['version'] as int? ?? 0) + 1,
  };

  /// One account per label, ever: deleted accounts keep theirs (accounts._check_label).
  void _checkLabel(String? label, String self) {
    if (label == null) return;
    for (final a in _allAccounts()) {
      if (a['id'] != self && a['sms_label'] == label) {
        _refuse(
          'label_taken',
          a['deleted_at'] != null
              ? 'A deleted account has that label. Restore it instead'
              : '${a['name']} already has that label',
          status: 409,
        );
      }
    }
  }

  /// Every account, deleted ones too, as the items so far leave it.
  List<Json> _allAccounts() {
    final ids = <String>{
      for (final deleted in const [false, true])
        for (final a in _l.personalAccountList(deleted: deleted)) a['id'] as String,
      for (final s in _states.values)
        if (s.entity == _account) s.entityId,
    };
    return [for (final id in ids) account(id)!];
  }

  /// accounts._claim: an active account with a label takes in your entries with that label, in
  /// its currency and with no account yet, deleted ones too.
  void _claim(Json a) {
    final label = a['sms_label'] as String?;
    if (label == null || a['status'] != 'active') return;
    final ids = <String>{
      for (final deleted in const [false, true])
        for (final t in _l.personalList(account: label, deleted: deleted, limit: 1 << 30)['items'] as List)
          (t as Map)['id'] as String,
      for (final s in _states.values)
        if (s.entity == _entry && s.data['account'] == label) s.entityId,
    };
    for (final id in ids) {
      final t = entry(id)!;
      if (t['account_id'] != null || t['account'] != label || t['currency'] != a['currency']) continue;
      _set(_entry, {...t, 'account_id': a['id'], 'acting_admin_id': _adminId, 'version': (t['version'] as int) + 1});
      if (_claimed.add(id) && _undo != null) {
        final claimed = _claimed;
        _undo!.add(() => claimed.remove(id));
      }
      _put(_claimedBy, id, a['id'] as String);
    }
  }
}

/// The full body for an entry as [t] (a raw entity) has it: [personalBody] without the round trip
/// through PersonalTxnOut, for an entry an earlier item of the same write changed.
PersonalTxnIn _bodyFromRaw(Json t) => PersonalTxnIn(
  type: PersonalTxnInTypeEnum.fromJson(t['type'])!,
  amountMinor: t['amount_minor'] as int,
  description: t['description'] as String,
  date: apiDate(DateTime.parse(t['date'] as String)),
  categoryId: t['category_id'] as String?,
  notes: t['notes'] as String?,
  channel: PersonalTxnInChannelEnum.fromJson(t['channel']),
  merchant: t['merchant'] as String?,
  account: t['account'] as String?,
  expenseId: t['expense_id'] as String?,
  settlementId: t['settlement_id'] as String?,
  reviewed: t['reviewed'] as bool? ?? true,
  accountId: t['account_id'] as String?,
  direction: PersonalTxnInDirectionEnum.fromJson(PersonalRow(t).flow.wire),
  transferGroupId: t['transfer_group_id'] as String?,
  refundOfId: t['refund_of_id'] as String?,
  holdingId: t['holding_id'] as String?,
  source_: PersonalTxnInSource_Enum.fromJson(t['source'] ?? 'manual')!,
  reference: t['reference'] as String?,
  balanceMinor: t['balance_minor'] as int?,
  smsAt: t['sms_at'] == null ? null : DateTime.parse(t['sms_at'] as String),
);

/// The full body for an account as [a] (a raw entity) has it.
PersonalAccountIn _accountIn(Json a) => PersonalAccountIn(
  name: a['name'] as String,
  type: PersonalAccountInTypeEnum.fromJson(a['type'])!,
  openingBalanceMinor: a['opening_balance_minor'] as int? ?? 0,
  smsLabel: a['sms_label'] as String?,
  status: PersonalAccountInStatusEnum.fromJson(a['status']),
);

PersonalAccountInTypeEnum _accountType(AccountType t) => PersonalAccountInTypeEnum.fromJson(t.wire)!;

/// Trimmed notes, blank as none.
String? _notes(String? notes) => LocalWrites._text(notes);

/// A balance correction on [accountId] by [delta], dated [day].
PersonalTxnIn _adjustment(String accountId, ({MoneyFlow flow, int amountMinor}) delta, DateTime day) => PersonalTxnIn(
  type: PersonalTxnInTypeEnum.adjustment,
  amountMinor: delta.amountMinor,
  description: 'Balance correction',
  date: apiDate(day),
  accountId: accountId,
  direction: PersonalTxnInDirectionEnum.fromJson(delta.flow.wire),
  source_: PersonalTxnInSource_Enum.manual,
);

/// [t] as one leg of transfer [group], going [direction]: no category, refund or holding.
PersonalTxnIn _asLeg(Json t, MoneyFlow direction, String group) => _bodyFromRaw(t)
  ..type = PersonalTxnInTypeEnum.transfer
  ..direction = PersonalTxnInDirectionEnum.fromJson(direction.wire)
  ..categoryId = null
  ..transferGroupId = group
  ..refundOfId = null
  ..holdingId = null;

/// What the importer's requests say they did, in the outbox and "Needs your attention".
String _importLabel(List<BatchItem> items) {
  final made = [
    for (final i in items)
      if (i.op == PersonalBatchItemOpEnum.create && i.transaction != null) i.transaction!,
  ];
  final accounts = items.where((i) => i.isAccountCreate).length;
  if (items.length == 1 && made.length == 1) return 'Added ${made.single.description} from an SMS';
  String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  final parts = [
    if (made.isNotEmpty) count(made.length, 'entry', 'entries'),
    if (accounts > 0) count(accounts, 'account', 'accounts'),
  ];
  if (parts.isEmpty) return 'Updated ${count(items.length, 'entry', 'entries')} from bank SMS';
  return 'Added ${parts.join(' and ')} from bank SMS';
}

/// Accounts, transfers, refunds and Reconcile, queued like every other write (design §4.4), and
/// the batch the bank SMS importer queues what it read with ([importUnits]).
///
/// Each write is checked first as the server will check it ([_Draft]); what the server would
/// refuse is refused here with its code and words ([WriteRefused]), so a write made offline isn't
/// refused only once it's sent.
extension FinanceWrites on LocalWrites {
  // ---- accounts ----

  /// A new account in your currency, with [id] or a new one (`POST /personal/accounts`); returns
  /// its id. With [smsLabel], your entries with that label and no account yet move into it, as the
  /// server moves them (deleted ones too). Refused if another account, deleted ones too, has the
  /// label.
  Future<String> createAccount({
    required String name,
    required AccountType type,
    int openingMinor = 0,
    String? smsLabel,
    String? id,
  }) async {
    final l = await _ledger();
    id ??= LocalWrites._uuid.v4();
    final body = PersonalAccountIn(
      name: name,
      type: _accountType(type),
      openingBalanceMinor: openingMinor,
      smsLabel: smsLabel,
    );
    final entities = (_Draft(this, l)..add(BatchItem.createAccount(id, body))).finish();
    await _queue(
      OutboxOp(
        method: 'POST',
        path: '/api/v1/personal/accounts',
        body: _json((body..id = id).toJson()),
        label: 'Added ${name.trim()}',
        entities: entities,
        createdAt: _now(),
      ),
    );
    return id;
  }

  /// Changes account [id] (`PUT /personal/accounts/{id}`): what's given, the rest as it is.
  /// [smsLabel] '' clears the label; a new one moves in your entries that have it and no account
  /// yet. Nothing is queued when nothing changes.
  Future<void> updateAccount(String id, {String? name, AccountType? type, int? openingMinor, String? smsLabel}) async {
    final l = await _ledger();
    final body = _accountIn(_required(l.rawAccount(id), 'Account'))..status = null;
    if (name != null) body.name = name;
    if (type != null) body.type = _accountType(type);
    if (openingMinor != null) body.openingBalanceMinor = openingMinor;
    if (smsLabel != null) body.smsLabel = smsLabel;
    await _queueAccountEdit(l, id, body, 'Edited');
  }

  /// Closes account [id]: it takes no new entries and still counts in net worth. With [zeroFirst]
  /// and a balance, a balance correction dated today brings it to zero first, in the same
  /// `POST /personal/batch`.
  Future<void> closeAccount(String id, {bool zeroFirst = false}) async {
    final l = await _ledger();
    final before = _required(l.rawAccount(id), 'Account');
    if (before['status'] == 'closed') return;
    final body = _accountIn(before)..status = PersonalAccountInStatusEnum.closed;
    final balance = zeroFirst ? l.finance.balanceOf(id) : null;
    final delta = balance == null ? null : reconcileDelta(balance, 0, atCheckpoint: false);
    if (delta == null) return _queueAccountEdit(l, id, body, 'Closed');
    final draft = _Draft(this, l)
      ..add(BatchItem.createEntry(LocalWrites._uuid.v4(), _adjustment(id, delta, appClock.now())))
      ..add(BatchItem.updateAccount(id, body));
    await _queue(draft.op('Closed ${before['name']} at a zero balance'));
  }

  /// Opens closed account [id] again. With a label, your entries with it and no account yet move
  /// in, as the server moves them.
  Future<void> reopenAccount(String id) async {
    final l = await _ledger();
    final before = _required(l.rawAccount(id), 'Account');
    if (before['status'] == 'active') return;
    await _queueAccountEdit(l, id, _accountIn(before)..status = PersonalAccountInStatusEnum.active, 'Reopened');
  }

  Future<void> _queueAccountEdit(Ledger l, String id, PersonalAccountIn body, String verb) async {
    final version = _required(l.rawAccount(id), 'Account')['version'] as int;
    final entities = (_Draft(this, l)..add(BatchItem.updateAccount(id, body))).finish();
    if (entities.isEmpty) return;
    await _queue(
      OutboxOp(
        method: 'PUT',
        path: '/api/v1/personal/accounts/$id',
        body: _json(
          (body
                ..id = null
                ..version = version)
              .toJson(),
        ),
        label: '$verb ${entities.first.data['name']}',
        entities: entities,
        createdAt: _now(),
      ),
    );
  }

  /// Deletes account [id] (`DELETE /personal/accounts/{id}`). Refused while a live entry is in it:
  /// close it instead.
  Future<void> deleteAccount(String id) => _setAccountDeleted(id, true);

  /// Brings deleted account [id] back (its label stayed its own).
  Future<void> restoreAccount(String id) => _setAccountDeleted(id, false);

  Future<void> _setAccountDeleted(String id, bool deleted) async {
    final l = await _ledger();
    final before = _required(l.rawAccount(id), 'Account');
    if ((before['deleted_at'] != null) == deleted) return;
    if (deleted && (l.personalList(accountId: id, limit: 0)['count'] as int) > 0) {
      _refuse('account_in_use', "This account has entries, so it can't be deleted. Close it instead", status: 409);
    }
    final version = before['version'] as int;
    final now = _now();
    final data = {
      ...before,
      'acting_admin_id': _ref.read(sessionProvider).value?.adminId,
      'updated_at': now,
      'deleted_at': deleted ? now : null,
      'version': version + 1,
    };
    await _queue(
      OutboxOp(
        method: deleted ? 'DELETE' : 'POST',
        path: deleted ? '/api/v1/personal/accounts/$id' : '/api/v1/personal/accounts/$id/restore',
        query: {'version': '$version'},
        label: '${deleted ? 'Deleted' : 'Restored'} ${before['name']}',
        entities: [_entity('user:${l.me}', 'personal_account', id, version + 1, data)],
        createdAt: now,
      ),
    );
  }

  // ---- transfers ----

  /// Money moved from one of your accounts to another: a leg out of [fromAccountId] and a leg into
  /// [toAccountId], made together in one `POST /personal/batch`. [channel] as the API writes it
  /// ('bank', 'upi'…). Returns the transfer's group id.
  Future<String> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    required DateTime date,
    required String description,
    String? notes,
    String? channel,
  }) async {
    final l = await _ledger();
    final outId = LocalWrites._uuid.v4(), inId = LocalWrites._uuid.v4();
    final group = transferGroupIdFor(outId, inId);
    PersonalTxnIn leg(String accountId, PersonalTxnInDirectionEnum direction) => PersonalTxnIn(
      type: PersonalTxnInTypeEnum.transfer,
      amountMinor: amountMinor,
      description: description,
      date: apiDate(date),
      notes: _notes(notes),
      channel: PersonalTxnInChannelEnum.fromJson(channel),
      accountId: accountId,
      direction: direction,
      transferGroupId: group,
      source_: PersonalTxnInSource_Enum.manual,
    );
    final draft = _Draft(this, l)
      ..add(BatchItem.createEntry(outId, leg(fromAccountId, PersonalTxnInDirectionEnum.out_)))
      ..add(BatchItem.createEntry(inId, leg(toAccountId, PersonalTxnInDirectionEnum.in_)));
    await _queue(draft.op('Added ${_transferLabel(draft, draft.entry(outId)!, draft.entry(inId)!)}'));
    return group;
  }

  /// Changes transfer [groupId] on both legs together (one `POST /personal/batch`): what's given,
  /// the rest as each leg has it. [notes] or [channel] '' clears it. [date] dates both legs; left
  /// out, each keeps its own (legs read from two bank SMS may be a day apart).
  Future<void> updateTransfer(
    String groupId, {
    String? fromAccountId,
    String? toAccountId,
    int? amountMinor,
    DateTime? date,
    String? description,
    String? notes,
    String? channel,
  }) async {
    final l = await _ledger();
    final draft = _Draft(this, l);
    final (out, into) = _transferLegs(draft, groupId);
    PersonalTxnIn edit(Json leg, String? accountId) {
      final body = _bodyFromRaw(leg);
      if (accountId != null) body.accountId = accountId;
      if (amountMinor != null) body.amountMinor = amountMinor;
      if (date != null) body.date = apiDate(date);
      if (description != null) body.description = description;
      if (notes != null) body.notes = _notes(notes);
      if (channel != null) body.channel = PersonalTxnInChannelEnum.fromJson(channel);
      return body;
    }

    draft
      ..add(BatchItem.updateEntry(out['id'] as String, edit(out, fromAccountId)))
      ..add(BatchItem.updateEntry(into['id'] as String, edit(into, toAccountId)));
    final label =
        'Edited ${_transferLabel(draft, draft.entry(out['id'] as String)!, draft.entry(into['id'] as String)!)}';
    await _queue(draft.op(label));
  }

  /// Deletes transfer [groupId]: one DELETE of its out leg, which takes the other with it on the
  /// server, and both legs at once on the device. [LocalWrites.restorePersonal] of either leg
  /// brings both back.
  Future<void> deleteTransfer(String groupId) async {
    final l = await _ledger();
    final (out, _) = _transferLegs(_Draft(this, l), groupId);
    await _setPersonalDeleted(out['id'] as String, true);
  }

  /// Makes entry [entryId] (a spend or an income, in one of your accounts) one leg of a transfer
  /// whose other leg, made here, is in [otherAccountId]: money out of the entry's account into the
  /// other one, or the reverse. One `POST /personal/batch`: the entry changed (no category any
  /// more), then the new leg made. The new leg is pairedLegId(entryId) and the group
  /// transferGroupIdFor(entryId), so two devices converting the same entry make the same rows;
  /// if they were used before (a transfer since unpaired), fresh ones. Returns the group id.
  Future<String> convertToTransfer(String entryId, {required String otherAccountId}) async {
    final l = await _ledger();
    final draft = _Draft(this, l);
    final group = _convert(draft, entryId, otherAccountId);
    final legs = draft._legsOf(group);
    final (out, into) = legs[0]['direction'] == 'out' ? (legs[0], legs[1]) : (legs[1], legs[0]);
    await _queue(draft.op('Made a transfer: ${_transferLabel(draft, out, into)}'));
    return group;
  }

  String _convert(_Draft d, String entryId, String otherAccountId) {
    final t = d.entry(entryId) ?? (throw const LocalNotFound('Transaction'));
    _checkPairable(t);
    var legId = pairedLegId(entryId), group = transferGroupIdFor(entryId);
    // Made before: a create would give back the old (deleted) leg, and its group still has it.
    if (d.entry(legId) != null || d._legsOf(group).isNotEmpty) {
      legId = LocalWrites._uuid.v4();
      group = transferGroupIdFor(entryId, legId);
    }
    final flow = PersonalRow(t).flow;
    d
      ..add(BatchItem.updateEntry(entryId, _asLeg(t, flow, group)))
      ..add(
        BatchItem.createEntry(
          legId,
          PersonalTxnIn(
            type: PersonalTxnInTypeEnum.transfer,
            amountMinor: t['amount_minor'] as int,
            description: t['description'] as String,
            date: apiDate(DateTime.parse(t['date'] as String)),
            channel: PersonalTxnInChannelEnum.fromJson(t['channel']),
            accountId: otherAccountId,
            direction: PersonalTxnInDirectionEnum.fromJson(flow.opposite.wire),
            transferGroupId: group,
            source_: PersonalTxnInSource_Enum.manual,
          ),
        ),
      );
    return group;
  }

  /// Entry [t] can become a transfer leg: live, not one already, and not linked to Split.
  void _checkPairable(Json t) {
    if (t['deleted_at'] != null) _refuse('deleted', 'Restore this entry before editing it', status: 409);
    if (t['transfer_group_id'] != null) _refuse('transfer_unpaired', 'Change both halves of a transfer together');
    if (t['expense_id'] != null || t['settlement_id'] != null) {
      _refuse('link_invalid', 'Only spending and income can be linked to Split');
    }
  }

  /// Turns transfer [groupId] back into separate entries (design §9 risk 18), in one
  /// `POST /personal/batch`: [keepId] becomes a spend or an income again (no category), and so
  /// does the other leg if it was read from bank SMS; a leg the app made (by hand, or the other
  /// half it made for an SMS: pairedLegId of [keepId]) is deleted. The kept leg changes first, so
  /// deleting the other doesn't take it along.
  Future<void> unpairTransfer(String groupId, {required String keepId}) async {
    final l = await _ledger();
    final draft = _Draft(this, l);
    final (out, into) = _transferLegs(draft, groupId);
    final (keep, other) = out['id'] == keepId
        ? (out, into)
        : into['id'] == keepId
        ? (into, out)
        : throw const LocalNotFound('Transaction');
    PersonalTxnIn back(Json leg) => _bodyFromRaw(leg)
      ..type = leg['direction'] == 'in' ? PersonalTxnInTypeEnum.income : PersonalTxnInTypeEnum.expense
      ..categoryId = null
      ..transferGroupId = null;
    final otherId = other['id'] as String;
    final appMade = other['source'] != 'sms' || otherId == pairedLegId(keepId);
    draft
      ..add(BatchItem.updateEntry(keepId, back(keep)))
      ..add(appMade ? BatchItem.deleteEntry(otherId) : BatchItem.updateEntry(otherId, back(other)));
    await _queue(draft.op('Unpaired ${_transferLabel(draft, out, into)}'));
  }

  /// "This was a transfer" (ISS-046): spend [outId] and income [inId], in two of your accounts,
  /// become the legs of one transfer (no category), changed together in one
  /// `POST /personal/batch`, and both have been looked at (as linking marks them). Returns the
  /// group id, transferGroupIdFor(outId, inId).
  Future<String> pairAsTransfer(String outId, String inId) async {
    final l = await _ledger();
    final draft = _Draft(this, l);
    final group = transferGroupIdFor(outId, inId);
    final legs = <Json>[];
    for (final (id, flow) in [(outId, MoneyFlow.outflow), (inId, MoneyFlow.inflow)]) {
      final t = draft.entry(id) ?? (throw const LocalNotFound('Transaction'));
      _checkPairable(t);
      if (PersonalRow(t).flow != flow) _refuse('transfer_invalid', 'One half goes out and the other comes in');
      legs.add(t);
    }
    for (final (t, flow) in [(legs[0], MoneyFlow.outflow), (legs[1], MoneyFlow.inflow)]) {
      draft.add(BatchItem.updateEntry(t['id'] as String, _asLeg(t, flow, group)..reviewed = true));
    }
    await _queue(draft.op('Marked as a transfer: ${_transferLabel(draft, legs[0], legs[1])}'));
    return group;
  }

  /// The live legs of transfer [groupId], out first.
  (Json, Json) _transferLegs(_Draft d, String groupId) {
    final legs = [
      for (final t in d._legsOf(groupId))
        if (t['deleted_at'] == null && t['type'] == 'transfer') t,
    ];
    if (legs.length != 2) throw const LocalNotFound('Transfer');
    return legs[0]['direction'] == 'out' ? (legs[0], legs[1]) : (legs[1], legs[0]);
  }

  /// "Credit card bill: HDFC ··4821 → ICICI Credit card ··9012 · ₹4,999".
  String _transferLabel(_Draft d, Json out, Json into) {
    String name(Json leg) => d.account(leg['account_id'] as String? ?? '')?['name'] as String? ?? 'an account';
    final amount = formatMinor(out['amount_minor'] as int, currency: out['currency'] as String);
    return '${out['description']}: ${name(out)} → ${name(into)} · $amount';
  }

  // ---- refunds and corrections ----

  /// Money back for a spend: a refund (`POST /personal/transactions`). With [refundOfId] (a live
  /// spend of yours), [accountId] defaults to the spend's account while that's open and
  /// [categoryId] to its category, so the refund comes off spending where the spend went; refused
  /// when [amountMinor] is more than what's left to refund of it. [channel] as the API writes it.
  /// Returns the refund's id.
  Future<String> recordRefund({
    required int amountMinor,
    required DateTime date,
    required String description,
    String? refundOfId,
    String? accountId,
    String? categoryId,
    String? notes,
    String? channel,
  }) async {
    final l = await _ledger();
    var account = accountId, category = categoryId;
    if (refundOfId != null) {
      final original = l.rawPersonal(refundOfId);
      if (original == null || original['deleted_at'] != null || original['type'] != 'expense') {
        _refuse('unknown_refund_target', "That spend isn't available");
      }
      if (amountMinor > (original['amount_minor'] as int)) {
        _refuse('refund_too_large', "A refund can't be more than the spend");
      }
      // The server checks each refund on its own (ISS-067); the device counts the earlier ones.
      final left = l.finance.refundableMinor(PersonalRow(original));
      if (amountMinor > left) {
        _refuse(
          'refund_too_large',
          'Only ${formatMinor(left, currency: original['currency'] as String)} of this spend is left to refund',
        );
      }
      final from = original['account_id'] as String?;
      final open = from == null ? null : l.rawAccount(from);
      if (accountId == null && open != null && open['deleted_at'] == null && open['status'] == 'active') account = from;
      category ??= original['category_id'] as String?;
    }
    return createPersonal(
      PersonalTxnIn(
        type: PersonalTxnInTypeEnum.refund,
        amountMinor: amountMinor,
        description: description,
        date: apiDate(date),
        categoryId: category,
        notes: _notes(notes),
        channel: PersonalTxnInChannelEnum.fromJson(channel),
        accountId: account,
        refundOfId: refundOfId,
        source_: PersonalTxnInSource_Enum.manual,
      ),
    );
  }

  /// Sets account [accountId]'s balance to what the bank says ([bankSaysMinor]: what it holds,
  /// or for a card or loan, what you owe) with a balance correction (an adjustment, the engine's
  /// reconcileDelta). With [checkpointDay] (a day key such as 20260921: the day of the balance the
  /// bank last reported, AccountBalance.lastReported), the gap is measured at that report and the
  /// correction dated that day, so it closes the gap there; without, against the balance now,
  /// dated today. Returns the correction's id, or null when there's no gap (nothing is queued).
  Future<String?> reconcile(String accountId, {required int bankSaysMinor, int? checkpointDay}) async {
    final l = await _ledger();
    final a = l.rawAccount(accountId);
    if (a == null || a['deleted_at'] != null) _refuse('unknown_account', "That account isn't available");
    if (a['status'] == 'closed') _refuse('account_closed', 'That account is closed');
    final balance = l.finance.balanceOf(accountId) ?? (throw const LocalNotFound('Account'));
    final delta = reconcileDelta(balance, bankSaysMinor, atCheckpoint: checkpointDay != null);
    if (delta == null) return null;
    final day = checkpointDay == null
        ? appClock.now()
        : DateTime.utc(checkpointDay ~/ 10000, checkpointDay ~/ 100 % 100, checkpointDay % 100);
    return createPersonal(_adjustment(accountId, delta, day));
  }

  /// A cash withdrawal, spend [atmEntryId], becomes a transfer into your Cash account
  /// ([convertToTransfer]); with no open one, a Cash account is made first, in the same
  /// `POST /personal/batch`. Returns the transfer's group id.
  Future<String> trackCash(String atmEntryId) async {
    final l = await _ledger();
    final draft = _Draft(this, l);
    var cash = l.finance.firstActiveCash()?.id;
    if (cash == null) {
      cash = LocalWrites._uuid.v4();
      draft.add(BatchItem.createAccount(cash, PersonalAccountIn(name: 'Cash', type: PersonalAccountInTypeEnum.cash)));
    }
    final group = _convert(draft, atmEntryId, cash);
    final t = draft.entry(atmEntryId)!;
    await _queue(draft.op('Moved ${formatMinor(t['amount_minor'] as int, currency: t['currency'] as String)} to Cash'));
    return group;
  }

  // ---- what a read of the bank SMS found ----

  /// Queues what a read of the bank SMS found as `POST /personal/batch` requests, all at once (one
  /// rebuild of the screens however many).
  ///
  /// Each of [units] is items that must travel in one request: an account made, an entry, a
  /// transfer's two legs, an entry changed into a leg and the other leg made. A request holds at
  /// most [chunk] items ([Features.importChunk] by default; at most the server's 100), and a unit
  /// is never split (one bigger than [chunk] goes alone). Units that make an account go first, in
  /// the order given, so the entries after them can use it: in the first request when there are
  /// no more than [chunk] such items. A unit that changes an entry an account claimed in the
  /// current request starts the next one. [label] says what a request did (by default "Added 12
  /// entries from bank SMS").
  ///
  /// Every item is checked as the server checks it: if one would be refused, nothing is queued and
  /// [WriteRefused] says why. With [onRefused], a refused unit is left out instead (with any unit
  /// that needs it, such as an entry in an account a refused unit makes), told to [onRefused] with
  /// why ([WriteRefused], or [LocalNotFound] for an entry that's gone), and the rest is queued, still
  /// all at once.
  Future<void> importUnits(
    List<List<BatchItem>> units, {
    int? chunk,
    String Function(List<BatchItem> items)? label,
    void Function(List<BatchItem> unit, Object why)? onRefused,
  }) async {
    final send = [
      for (final u in units)
        if (u.isNotEmpty) u,
    ];
    if (send.isEmpty) return;
    final l = await _ledger();
    final size = (chunk ?? _ref.read(featuresProvider).importChunk).clamp(1, 100);
    bool makesAccount(List<BatchItem> unit) => unit.any((i) => i.isAccountCreate);
    final draft = _Draft(this, l);
    final ops = <OutboxOp>[];
    var request = <BatchItem>[];
    void close() {
      if (request.isEmpty) return;
      ops.add(draft.op((label ?? _importLabel)(request)));
      request = [];
    }

    for (final unit in [...send.where(makesAccount), ...send.where((u) => !makesAccount(u))]) {
      if (request.length + unit.length > size || draft.claims(unit)) close();
      if (onRefused == null) {
        unit.forEach(draft.add);
      } else {
        try {
          draft.addUnit(unit);
        } on WriteRefused catch (e) {
          onRefused(unit, e);
          continue;
        } on LocalNotFound catch (e) {
          onRefused(unit, e);
          continue;
        }
      }
      request.addAll(unit);
    }
    close();
    if (ops.isNotEmpty) await _queueAll(ops);
  }
}
