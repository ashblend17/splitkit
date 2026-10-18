part of 'writes.dart';

// Holdings (finance revamp design §5.2): what's in an investment account, with the value you last
// typed. Each write is checked as personal/holdings.py checks it and laid over the synced data
// ([_Draft]), so a write made offline isn't refused only once it's sent.

const _holdingEntity = 'personal_holding';

/// The most a holding's value or cost can be (personal/schemas.py MAX_BALANCE_MINOR).
const _maxBalanceMinor = 1000000000000000;

/// holdings.py create, update and change_deleted, on a [_Draft].
extension _HoldingDraft on _Draft {
  /// Holding [id] as the items so far leave it (deleted ones too), or null.
  Json? holding(String id) => _states[LocalEntity.keyOf(_stream, _holdingEntity, id)]?.data ?? _l.rawHolding(id);

  /// Whether account [accountId] has a live holding, as the items so far leave them
  /// (accounts.py _holds).
  bool _holds(String accountId) {
    final ids = {
      for (final h in _l.finance.holdings) h.id,
      for (final s in _states.values)
        if (s.entity == _holdingEntity) s.entityId,
    };
    return ids.any((id) {
      final h = holding(id);
      return h != null && h['deleted_at'] == null && h['account_id'] == accountId;
    });
  }

  void _createHolding(String id, PersonalHoldingIn body) {
    _checkHoldingIn(body);
    // A repeated create gives back the holding that's there, unchanged (versioning.replayed_create).
    if (holding(id) != null) return;
    final accountId = body.accountId ?? _refuse('account_required', "Pick the investment account it's in");
    _checkHoldingAccount(accountId);
    _set(_holdingEntity, _holdingData(id, body, null));
  }

  void _updateHolding(String id, PersonalHoldingIn body) {
    _checkHoldingIn(body);
    final before = holding(id) ?? (throw const LocalNotFound('Holding'));
    if (before['deleted_at'] != null) _refuse('deleted', 'Restore this holding before editing it', status: 409);
    if (body.accountId != before['account_id']) {
      _checkHoldingAccount(body.accountId ?? _refuse('account_required', "Pick the investment account it's in"));
    }
    final data = _holdingData(id, body, before);
    // The server leaves a holding nothing changes as it is, version too (holdings.py _state).
    const fields = [
      'account_id',
      'name',
      'asset_type',
      'quantity',
      'cost_basis_minor',
      'market_value_minor',
      'valuation_at',
      'valuation_source',
    ];
    if (fields.every((k) => data[k] == before[k])) return;
    _set(_holdingEntity, data);
  }

  /// Deleting is refused while a live entry names it; restoring needs its account.
  void _setHoldingDeleted(String id, bool deleted) {
    final h = holding(id) ?? (throw const LocalNotFound('Holding'));
    if ((h['deleted_at'] != null) == deleted) return;
    if (deleted) {
      final n = _naming(id);
      if (n > 0) {
        final entries = n == 1 ? 'An entry names' : '$n entries name';
        _refuse('holding_in_use', '$entries this holding. Change or delete them first', status: 409);
      }
    } else {
      final a = account(h['account_id'] as String);
      if (a == null || a['deleted_at'] != null) {
        _refuse('unknown_account', "This holding's account was deleted. Restore the account first");
      }
    }
    _set(_holdingEntity, {
      ...h,
      'acting_admin_id': _adminId,
      'updated_at': _now,
      'deleted_at': deleted ? _now : null,
      'version': (h['version'] as int) + 1,
    });
  }

  /// How many live entries name holding [id], as the items so far leave them.
  int _naming(String id) {
    final ids = {
      for (final e in _l.finance.namingHolding(id)) e.id,
      for (final s in _states.values)
        if (s.entity == _Draft._entry && s.data['holding_id'] == id) s.entityId,
    };
    return ids.where((e) {
      final t = entry(e);
      return t != null && t['deleted_at'] == null && t['holding_id'] == id;
    }).length;
  }

  /// holdings._check_account: an open investment account of yours, in your currency.
  void _checkHoldingAccount(String accountId) {
    final a = account(accountId);
    if (a == null || a['deleted_at'] != null) _refuse('unknown_account', "That account isn't available");
    if (a['type'] != 'investment') _refuse('not_investment_account', 'Holdings go in an investment account');
    if (a['status'] == 'closed') _refuse('account_closed', 'That account is closed');
    final mine = _l.userOut()['currency'];
    if (a['currency'] != mine) {
      _refuse('currency_mismatch', 'That account is in ${a['currency']}; your money is in $mine');
    }
  }

  /// [body] as the server's schema checks it (personal/schemas.py PersonalHoldingIn), with its
  /// words (core/errors.py _human).
  void _checkHoldingIn(PersonalHoldingIn body) {
    final name = body.name.trim();
    if (name.isEmpty) _refuse('invalid_input', "Name can't be empty");
    if (name.runes.length > 80) _refuse('invalid_input', 'Name can be at most 80 characters');
    for (final minor in [body.marketValueMinor, body.costBasisMinor]) {
      if (minor == null) continue;
      if (minor < 0) _refuse('invalid_input', 'Input should be greater than or equal to 0');
      if (minor > _maxBalanceMinor) _refuse('invalid_input', 'Input should be less than or equal to $_maxBalanceMinor');
    }
    if (body.quantity case final q?) _quantity(q);
    final day = body.valuationAt;
    if (day.isBefore(DateTime.utc(2000))) _refuse('invalid_input', 'Pick a date from 2000 onwards');
    final now = appClock.now();
    // A day of slack for time zones, as the server allows.
    if (day.isAfter(DateTime.utc(now.year, now.month, now.day + 1))) {
      _refuse('invalid_input', "A value can't be from the future");
    }
  }

  /// The holding as the server stores it (personal_holdings, as the sync log sends it).
  Json _holdingData(String id, PersonalHoldingIn body, Json? before) => {
    'id': id,
    'user_id': _l.me,
    'account_id': body.accountId,
    'name': body.name.trim(),
    'asset_type': body.assetType.value,
    'quantity': body.quantity == null ? null : _quantity(body.quantity!),
    'cost_basis_minor': body.costBasisMinor,
    'market_value_minor': body.marketValueMinor,
    'valuation_at': LocalWrites._day(body.valuationAt),
    'valuation_source': body.valuationSource.value,
    'currency': before?['currency'] ?? account(body.accountId!)!['currency'],
    'acting_admin_id': _adminId,
    'created_at': before?['created_at'] ?? _now,
    'updated_at': _now,
    'deleted_at': null,
    'version': (before?['version'] as int? ?? 0) + 1,
  };
}

/// Quantity [q] as the server keeps it ("18.000" is "18"; numeric(18, 6)), or refused as it
/// refuses it.
String _quantity(String q) {
  final d = Decimal.tryParse(q.trim()) ?? _refuse('invalid_input', 'Quantity must be a number');
  if (d < Decimal.zero) _refuse('invalid_input', 'Input should be greater than or equal to 0');
  final text = d.toString();
  final dot = text.indexOf('.');
  final whole = dot < 0 ? text : text.substring(0, dot);
  if (whole.length > 12 || (dot >= 0 && text.length - dot - 1 > 6)) {
    _refuse('invalid_input', 'Quantity has too many digits');
  }
  return text;
}

/// The full body for a holding as [h] (a raw entity) has it. The API applies every field it's
/// sent (the generated client sends every key, null too), so an edit starts from this and changes
/// only what it means to: its account, quantity and cost basis included.
PersonalHoldingIn _holdingIn(Json h) => PersonalHoldingIn(
  name: h['name'] as String,
  assetType: PersonalHoldingInAssetTypeEnum.fromJson(h['asset_type'])!,
  marketValueMinor: h['market_value_minor'] as int,
  valuationAt: apiDate(DateTime.parse(h['valuation_at'] as String)),
  valuationSource: PersonalHoldingInValuationSourceEnum.fromJson(h['valuation_source'] ?? 'manual')!,
  accountId: h['account_id'] as String?,
  quantity: h['quantity'] as String?,
  costBasisMinor: h['cost_basis_minor'] as int?,
);

/// Trimmed quantity text, blank as none.
String? _quantityText(String? q) => LocalWrites._text(q);

/// Holdings in your investment accounts, queued like every other write, each checked first as the
/// server will check it ([_Draft]): what it would refuse is refused here with its code and words
/// ([WriteRefused]).
extension HoldingWrites on LocalWrites {
  /// A holding in investment account [accountId], with [id] or a new one
  /// (`POST /personal/holdings`): what it was worth ([marketMinor]) on [valuationDay], and when
  /// you know them, its [quantity] ("412.358") and what you paid in all ([costBasisMinor]).
  /// Returns its id. Refused unless the account is an open investment account in your currency.
  Future<String> createHolding({
    required String accountId,
    required String name,
    required HoldingType type,
    required int marketMinor,
    required DateTime valuationDay,
    String? quantity,
    int? costBasisMinor,
    String? id,
  }) async {
    final l = await _ledger();
    id ??= LocalWrites._uuid.v4();
    final body = PersonalHoldingIn(
      name: name,
      assetType: _holdingType(type),
      marketValueMinor: marketMinor,
      valuationAt: apiDate(valuationDay),
      valuationSource: PersonalHoldingInValuationSourceEnum.manual,
      accountId: accountId,
      quantity: _quantityText(quantity),
      costBasisMinor: costBasisMinor,
    );
    final entities = (_Draft(this, l)..add(BatchItem.createHolding(id, body))).finish();
    await _queue(
      OutboxOp(
        method: 'POST',
        path: '/api/v1/personal/holdings',
        body: _json((body..id = id).toJson()),
        label: 'Added ${name.trim()}',
        entities: entities,
        createdAt: _now(),
      ),
    );
    return id;
  }

  /// Changes holding [id] (`PUT /personal/holdings/{id}`): what's given, the rest as it is.
  /// [quantity] '' clears the quantity, and [clearCostBasis] the cost basis. Nothing is queued
  /// when nothing changes.
  Future<void> updateHolding(
    String id, {
    String? name,
    HoldingType? type,
    String? accountId,
    String? quantity,
    int? costBasisMinor,
    bool clearCostBasis = false,
    int? marketMinor,
    DateTime? valuationDay,
  }) async {
    final l = await _ledger();
    final body = _holdingIn(_required(l.rawHolding(id), 'Holding'));
    if (name != null) body.name = name;
    if (type != null) body.assetType = _holdingType(type);
    if (accountId != null) body.accountId = accountId;
    if (quantity != null) body.quantity = _quantityText(quantity);
    if (costBasisMinor != null || clearCostBasis) body.costBasisMinor = costBasisMinor;
    if (marketMinor != null) body.marketValueMinor = marketMinor;
    if (valuationDay != null) body.valuationAt = apiDate(valuationDay);
    await _queueHoldingEdit(l, id, body, 'Edited');
  }

  /// "Update value": holding [id] was worth [marketMinor] on [valuationDay] (today or before), and
  /// with [costBasisMinor], that's what you've paid for it in all. The rest stays as it is.
  Future<void> updateValue(String id, int marketMinor, DateTime valuationDay, {int? costBasisMinor}) async {
    final l = await _ledger();
    final body = _holdingIn(_required(l.rawHolding(id), 'Holding'))
      ..marketValueMinor = marketMinor
      ..valuationAt = apiDate(valuationDay);
    if (costBasisMinor != null) body.costBasisMinor = costBasisMinor;
    await _queueHoldingEdit(l, id, body, 'Updated the value of');
  }

  /// Deletes holding [id] (`DELETE /personal/holdings/{id}`). Refused while a live entry names it:
  /// change or delete those first.
  Future<void> deleteHolding(String id) => _setHoldingDeletedOp(id, true);

  /// Brings deleted holding [id] back. Refused while its account is deleted.
  Future<void> restoreHolding(String id) => _setHoldingDeletedOp(id, false);

  Future<void> _queueHoldingEdit(Ledger l, String id, PersonalHoldingIn body, String verb) async {
    final version = _required(l.rawHolding(id), 'Holding')['version'] as int;
    final entities = (_Draft(this, l)..add(BatchItem.updateHolding(id, body))).finish();
    if (entities.isEmpty) return;
    await _queue(
      OutboxOp(
        method: 'PUT',
        path: '/api/v1/personal/holdings/$id',
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

  Future<void> _setHoldingDeletedOp(String id, bool deleted) async {
    final l = await _ledger();
    final before = _required(l.rawHolding(id), 'Holding');
    if ((before['deleted_at'] != null) == deleted) return;
    final version = before['version'] as int;
    final entities = (_Draft(this, l).._setHoldingDeleted(id, deleted)).finish();
    await _queue(
      OutboxOp(
        method: deleted ? 'DELETE' : 'POST',
        path: deleted ? '/api/v1/personal/holdings/$id' : '/api/v1/personal/holdings/$id/restore',
        query: {'version': '$version'},
        label: '${deleted ? 'Deleted' : 'Restored'} ${before['name']}',
        entities: entities,
        createdAt: _now(),
      ),
    );
  }
}

PersonalHoldingInAssetTypeEnum _holdingType(HoldingType t) => PersonalHoldingInAssetTypeEnum.fromJson(t.wire)!;
