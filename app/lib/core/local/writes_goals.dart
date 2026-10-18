part of 'writes.dart';

// Goals and goal contributions (finance revamp Phase 2, design §2.3): the writes the Goals
// screens make, and what the device checks and mirrors for them while drafting a write
// ([_Draft]), as the server does (api/app/modules/personal/goals.py, contributions.py).

/// A goal as the editor fills it in: the full state to save. Only the field the [mode] uses is
/// sent ([linkedAccountId] in linked-balance mode, [manualProgressMinor] in manual mode); the
/// other is sent empty, as the server wants it.
final class GoalDraft {
  const GoalDraft({
    required this.name,
    required this.targetMinor,
    this.targetDate,
    this.mode = GoalMode.contribution,
    this.linkedAccountId,
    this.manualProgressMinor,
    this.expectedReturnBp,
    this.priority = 0,
    this.status = GoalStatus.active,
  });

  /// [goal] as it is, to edit.
  GoalDraft.of(FinGoal goal)
    : name = goal.name,
      targetMinor = goal.targetMinor,
      targetDate = goal.targetDay == null ? null : localDay(goal.targetDay!),
      mode = goal.mode,
      linkedAccountId = goal.linkedAccountId,
      manualProgressMinor = goal.manualProgressMinor,
      expectedReturnBp = goal.expectedReturnBp,
      priority = goal.priority,
      status = goal.status;

  final String name;
  final int targetMinor;

  /// The day to reach it by (2000 to 2100), or null for none.
  final DateTime? targetDate;

  final GoalMode mode;

  /// The account whose balance is the progress (linked-balance mode).
  final String? linkedAccountId;

  /// What's saved so far (manual mode).
  final int? manualProgressMinor;

  /// Expected monthly return in basis points (80 = 0.8%), for the estimate; null for none.
  final int? expectedReturnBp;

  /// 0 first. The editor has no control for it yet (design §10 risk 24).
  final int priority;

  final GoalStatus status;

  PersonalGoalIn _body() => PersonalGoalIn(
    name: name,
    targetMinor: targetMinor,
    targetDate: targetDate == null ? null : apiDate(targetDate!),
    trackingMode: PersonalGoalInTrackingModeEnum.fromJson(mode.wire)!,
    linkedAccountId: mode == GoalMode.linkedBalance ? linkedAccountId : null,
    manualProgressMinor: mode == GoalMode.manual ? manualProgressMinor : null,
    expectedReturnBp: expectedReturnBp,
    priority: priority,
    status: PersonalGoalInStatusEnum.fromJson(status.wire),
  );
}

/// The full body for a goal as [g] (a raw entity) has it.
PersonalGoalIn _goalIn(Json g) => PersonalGoalIn(
  name: g['name'] as String,
  targetMinor: g['target_minor'] as int,
  targetDate: g['target_date'] == null ? null : apiDate(DateTime.parse(g['target_date'] as String)),
  trackingMode: PersonalGoalInTrackingModeEnum.fromJson(g['tracking_mode'])!,
  linkedAccountId: g['linked_account_id'] as String?,
  manualProgressMinor: g['manual_progress_minor'] as int?,
  expectedReturnBp: g['expected_return_bp'] as int?,
  priority: g['priority'] as int? ?? 0,
  status: PersonalGoalInStatusEnum.fromJson(g['status']),
);

/// The full body for a contribution as [c] (a raw entity) has it.
PersonalGoalContributionIn _contributionIn(Json c) => PersonalGoalContributionIn(
  goalId: c['goal_id'] as String,
  amountMinor: c['amount_minor'] as int,
  date: apiDate(DateTime.parse(c['date'] as String)),
  transactionId: c['transaction_id'] as String?,
  note: c['note'] as String?,
);

/// What a goal write checks and mirrors while it's drafted ([_Draft.add] calls these).
extension _GoalDraft on _Draft {
  // ---- goals (goals.py create, update, change_deleted) ----

  void _createGoal(String id, PersonalGoalIn body) {
    // A repeated create gives back the goal that's there, unchanged (versioning.replayed_create).
    if (goal(id) != null) return;
    _checkGoalBody(body);
    final (mode, account, progress) = _goalMode(body);
    final currency = _l.userOut()['currency'] as String;
    if (account != null) _checkGoalAccount(account, currency);
    _set(_Draft._goal, _goalData(id, body, null, mode, account, progress, body.status?.value ?? 'active'));
  }

  void _updateGoal(String id, PersonalGoalIn body) {
    final before = goal(id) ?? (throw const LocalNotFound('Goal'));
    if (before['deleted_at'] != null) _refuse('deleted', 'Restore this goal before editing it', status: 409);
    _checkGoalBody(body);
    final (mode, account, progress) = _goalMode(body);
    if (account != null && account != before['linked_account_id']) {
      _checkGoalAccount(account, before['currency'] as String);
    }
    final status = body.status?.value ?? before['status'] as String;
    final takesMoney = before['tracking_mode'] == 'contribution' && before['status'] != 'archived';
    if (takesMoney && (mode != 'contribution' || status == 'archived')) _refuseIfRulePoints(id);
    final data = _goalData(id, body, before, mode, account, progress, status);
    // The server leaves a goal nothing changes as it is, version too.
    const fields = [
      'name',
      'target_minor',
      'target_date',
      'tracking_mode',
      'linked_account_id',
      'manual_progress_minor',
      'expected_return_bp',
      'priority',
      'status',
    ];
    if (fields.every((k) => data[k] == before[k])) return;
    _set(_Draft._goal, data);
  }

  /// Deletes or restores goal [id], with the contributions that go with it
  /// (contributions.follow_goal). A restore is then checked for money counted twice.
  void _setGoalDeleted(String id, bool deleted) {
    final g = goal(id) ?? (throw const LocalNotFound('Goal'));
    if ((g['deleted_at'] != null) == deleted) return;
    final version = g['version'] as int;
    if (deleted) {
      _refuseIfRulePoints(id);
      _set(_Draft._goal, {
        ...g,
        'deleted_at': _now,
        'updated_at': _now,
        'acting_admin_id': _adminId,
        'version': version + 1,
      });
      for (final c in _contributionsWhere(goalId: id)) {
        if (c['deleted_at'] == null) _setContribution(c, deletedAt: _now);
      }
      return;
    }
    if (g['linked_account_id'] case final String accountId) {
      if (account(accountId)?['deleted_at'] != null) {
        _refuse('unknown_account', "This goal's account was deleted. Restore the account first");
      }
    }
    final at = isoMicros(g['deleted_at']);
    _set(_Draft._goal, {
      ...g,
      'deleted_at': null,
      'updated_at': _now,
      'acting_admin_id': _adminId,
      'version': version + 1,
    });
    for (final c in _contributionsWhere(goalId: id)) {
      if (c['deleted_at'] == null || isoMicros(c['deleted_at']) != at) continue;
      if (c['transaction_id'] case final String entryId) {
        if (entry(entryId)?['deleted_at'] != null) continue;
        if (_otherContribution(entryId, c['id'] as String) case final other?) {
          final name = goal(other['goal_id'] as String)?['name'];
          _refuse('already_contributed', 'An entry this goal counted now counts toward $name');
        }
      }
      _setContribution(c, deletedAt: null);
    }
    _checkCountedOnce(goalChanged: true);
  }

  /// goals._mode: the mode with its account and typed progress, as the goal will be. The body
  /// gives every field (the client sends every key), so a field the mode doesn't use must be
  /// empty.
  (String, String?, int?) _goalMode(PersonalGoalIn body) {
    final mode = body.trackingMode.value;
    final account = body.linkedAccountId, progress = body.manualProgressMinor;
    if (mode == 'linked_balance' && account == null) _refuse('account_required', 'Pick the account this goal follows');
    if (mode != 'linked_balance' && account != null) {
      _refuse('account_not_used', "Only a goal that follows an account's balance has an account");
    }
    if (mode == 'manual' && progress == null) _refuse('progress_required', 'Say how much is saved so far');
    if (mode != 'manual' && progress != null) {
      _refuse('progress_not_used', 'Only a goal you track by hand has progress you type');
    }
    return (mode, account, progress);
  }

  /// What PersonalGoalIn's validation refuses that the editor could send.
  void _checkGoalBody(PersonalGoalIn body) {
    final name = body.name.trim();
    if (name.isEmpty) _refuse('invalid_input', "Name can't be empty");
    if (name.length > 60) _refuse('invalid_input', 'Name can be at most 60 characters');
    if (body.targetMinor <= 0) _refuse('invalid_input', 'Enter an amount above zero');
    if (body.targetMinor > maxAmountMinor) _refuse('invalid_input', 'That amount is too large');
    if (body.targetDate case final d? when d.year < 2000 || d.year > 2100) {
      _refuse('invalid_input', 'Pick a date between 2000 and 2100');
    }
    if ((body.manualProgressMinor ?? 0) < 0) _refuse('invalid_input', "Progress can't be below zero");
    if (body.expectedReturnBp case final bp? when bp < 0 || bp > 10000) {
      _refuse('invalid_input', 'A monthly return is between 0% and 100%');
    }
  }

  /// goals._check_account: a goal follows a live account of yours, in its currency.
  void _checkGoalAccount(String accountId, String currency) {
    final a = account(accountId);
    if (a == null || a['deleted_at'] != null) _refuse('unknown_account', "That account isn't available");
    if (a['currency'] != currency) {
      _refuse('currency_mismatch', 'That account is in ${a['currency']}; this goal is in $currency');
    }
  }

  /// allocation_rules.refuse_if_pointed_at for goal [goalId]: refused while a live rule sends
  /// money there. The device doesn't read rules yet, so this finds none until it does.
  void _refuseIfRulePoints(String goalId) {
    if (_l.finance.rulesPointingAt(goalId: goalId).isNotEmpty) {
      _refuse(
        'rule_points_here',
        'An allocation rule sends money to this goal. Change or delete it first',
        status: 409,
      );
    }
  }

  /// The goal as the server stores it (personal_goals, as the sync log sends it).
  Json _goalData(
    String id,
    PersonalGoalIn body,
    Json? before,
    String mode,
    String? account,
    int? progress,
    String status,
  ) => {
    'id': id,
    'user_id': _l.me,
    'name': body.name.trim(),
    'target_minor': body.targetMinor,
    'currency': before?['currency'] ?? _l.userOut()['currency'],
    'target_date': body.targetDate == null ? null : LocalWrites._day(body.targetDate!),
    'tracking_mode': mode,
    'linked_account_id': account,
    'manual_progress_minor': progress,
    'expected_return_bp': body.expectedReturnBp,
    'priority': body.priority,
    'status': status,
    'acting_admin_id': _adminId,
    'created_at': before?['created_at'] ?? _now,
    'updated_at': _now,
    'deleted_at': null,
    'version': (before?['version'] as int? ?? 0) + 1,
  };

  // ---- contributions (contributions.py create, update, change_deleted) ----

  void _createContribution(String id, PersonalGoalContributionIn body) {
    if (contribution(id) != null) return;
    _checkContributionBody(body);
    final g = _checkGoalTakes(body.goalId);
    final currency = _l.userOut()['currency'] as String;
    if (g['currency'] != currency) {
      _refuse('currency_mismatch', 'That goal is in ${g['currency']}; this contribution is in $currency');
    }
    if (body.transactionId case final entryId?) _checkContributionEntry(entryId, body.amountMinor, currency, null);
    _set(_Draft._contribution, {
      'id': id,
      'user_id': _l.me,
      'goal_id': body.goalId,
      'transaction_id': body.transactionId,
      'amount_minor': body.amountMinor,
      'currency': currency,
      'date': LocalWrites._day(body.date),
      'note': LocalWrites._text(body.note),
      'acting_admin_id': _adminId,
      'created_at': _now,
      'deleted_at': null,
      'version': 1,
    });
  }

  void _updateContribution(String id, PersonalGoalContributionIn body) {
    final c = contribution(id) ?? (throw const LocalNotFound('Contribution'));
    if (c['deleted_at'] != null) _refuse('deleted', 'Restore this contribution before editing it', status: 409);
    _checkContributionBody(body);
    final currency = c['currency'] as String;
    if (body.goalId != c['goal_id']) {
      final g = _checkGoalTakes(body.goalId);
      if (g['currency'] != currency) {
        _refuse('currency_mismatch', 'That goal is in ${g['currency']}; this contribution is in $currency');
      }
    }
    final entryId = body.transactionId;
    if (entryId != null && entryId != c['transaction_id']) {
      _checkContributionEntry(entryId, body.amountMinor, currency, id);
    } else if (entryId != null && body.amountMinor != c['amount_minor']) {
      final t = entry(entryId);
      if (t != null && body.amountMinor > (t['amount_minor'] as int)) {
        _refuse('contribution_too_large', "A contribution can't be more than its entry");
      }
    }
    final data = {
      ...c,
      'goal_id': body.goalId,
      'transaction_id': entryId,
      'amount_minor': body.amountMinor,
      'date': LocalWrites._day(body.date),
      'note': LocalWrites._text(body.note),
      'acting_admin_id': _adminId,
      'version': (c['version'] as int) + 1,
    };
    const fields = ['goal_id', 'transaction_id', 'amount_minor', 'date', 'note'];
    if (fields.every((k) => data[k] == c[k])) return;
    _set(_Draft._contribution, data);
  }

  /// Deletes or restores contribution [id]. A restore is checked as if it were made now, then for
  /// money counted twice.
  void _setContributionDeleted(String id, bool deleted) {
    final c = contribution(id) ?? (throw const LocalNotFound('Contribution'));
    if ((c['deleted_at'] != null) == deleted) return;
    if (deleted) return _setContribution(c, deletedAt: _now);
    if (goal(c['goal_id'] as String)?['deleted_at'] != null) {
      _refuse('unknown_goal', "This contribution's goal was deleted. Restore the goal first");
    }
    _checkGoalTakes(c['goal_id'] as String);
    if (c['transaction_id'] case final String entryId) {
      if (entry(entryId)?['deleted_at'] != null) {
        _refuse('unknown_transaction', "This contribution's entry was deleted. Restore the entry first");
      }
      _checkContributionEntry(entryId, c['amount_minor'] as int, c['currency'] as String, id);
    }
    _setContribution(c, deletedAt: null);
    _checkCountedOnce(goalChanged: false);
  }

  void _setContribution(Json c, {required String? deletedAt}) => _set(_Draft._contribution, {
    ...c,
    'deleted_at': deletedAt,
    'acting_admin_id': _adminId,
    'version': (c['version'] as int) + 1,
  });

  /// What PersonalGoalContributionIn's validation refuses that a sheet could send.
  void _checkContributionBody(PersonalGoalContributionIn body) {
    if (body.amountMinor <= 0) _refuse('invalid_input', 'Enter an amount above zero');
    if (body.amountMinor > maxAmountMinor) _refuse('invalid_input', 'That amount is too large');
    if (body.date.year < 2000) _refuse('invalid_input', 'Pick a date from 2000 onwards');
    if (body.date.isAfter(appClock.now().add(const Duration(days: 366)))) {
      _refuse('invalid_input', 'Pick a date less than a year ahead');
    }
    if ((body.note?.length ?? 0) > 500) _refuse('invalid_input', 'Note can be at most 500 characters');
  }

  /// contributions._check_goal: goal [goalId] takes contributions now (yours, live, not
  /// archived, counting contributions). Returns it.
  Json _checkGoalTakes(String goalId) {
    final g = goal(goalId);
    if (g == null || g['deleted_at'] != null) _refuse('unknown_goal', "That goal isn't available");
    final name = g['name'];
    if (g['status'] == 'archived') _refuse('goal_archived', '$name is archived');
    if (g['tracking_mode'] == 'linked_balance') {
      _refuse('goal_tracks_balance', "$name follows an account's balance, so it takes no contributions");
    }
    if (g['tracking_mode'] == 'manual') {
      _refuse('goal_is_manual', '$name is tracked by hand, so it takes no contributions');
    }
    return g;
  }

  /// contributions._check_entry: entry [entryId] is yours, live, in [currency], at least
  /// [amountMinor], and counts toward no other goal ([exceptId] is the contribution itself).
  void _checkContributionEntry(String entryId, int amountMinor, String currency, String? exceptId) {
    final t = entry(entryId);
    if (t == null || t['deleted_at'] != null) _refuse('unknown_transaction', "That entry isn't available");
    if (t['currency'] != currency) {
      _refuse('currency_mismatch', 'That entry is in ${t['currency']}; this contribution is in $currency');
    }
    if (amountMinor > (t['amount_minor'] as int)) {
      _refuse('contribution_too_large', "A contribution can't be more than its entry");
    }
    if (_otherContribution(entryId, exceptId) case final other?) {
      _refuse('already_contributed', 'That entry already counts toward ${goal(other['goal_id'] as String)?['name']}');
    }
  }

  /// The live contribution made with entry [entryId], other than [exceptId], or null.
  Json? _otherContribution(String entryId, String? exceptId) {
    for (final c in _contributionsWhere(entryId: entryId)) {
      if (c['deleted_at'] == null && c['id'] != exceptId) return c;
    }
    return null;
  }

  /// contributions.check_entry_amount: entry [entryId] can't shrink to [amountMinor] below what
  /// it contributes to a goal.
  void _checkEntryAmount(String entryId, int amountMinor) {
    final c = _otherContribution(entryId, null);
    if (c == null || (c['amount_minor'] as int) <= amountMinor) return;
    final amount = formatMinor(c['amount_minor'] as int, currency: c['currency'] as String);
    final name = goal(c['goal_id'] as String)?['name'];
    _refuse('contribution_too_large', '$amount of this entry counts toward $name. Lower that contribution first');
  }

  /// contributions.follow_entry: entry [entryId] was just deleted at [at] (its contributions go
  /// with it), or is being restored from a delete at [at] (the ones that went with it come back,
  /// if their goal is live).
  void _followEntry(String entryId, bool deleted, String at) {
    final when = isoMicros(at);
    for (final c in _contributionsWhere(entryId: entryId)) {
      if (deleted) {
        if (c['deleted_at'] == null) _setContribution(c, deletedAt: at);
      } else if (c['deleted_at'] != null &&
          isoMicros(c['deleted_at']) == when &&
          goal(c['goal_id'] as String)?['deleted_at'] == null) {
        _setContribution(c, deletedAt: null);
      }
    }
  }

  /// The contributions (deleted ones too) made with entry [entryId] or to goal [goalId], as the
  /// items so far leave them.
  List<Json> _contributionsWhere({String? entryId, String? goalId}) {
    final ids = <String>{
      for (final c in _l.rawContributionsOf(entryId: entryId, goalId: goalId)) c['id'] as String,
      for (final s in _states.values)
        if (s.entity == _Draft._contribution &&
            (entryId == null || s.data['transaction_id'] == entryId) &&
            (goalId == null || s.data['goal_id'] == goalId))
          s.entityId,
    };
    return [
      for (final id in ids)
        if (contribution(id) case final c?
            when (entryId == null || c['transaction_id'] == entryId) && (goalId == null || c['goal_id'] == goalId))
          c,
    ];
  }

  /// Every row of [entity] (deleted ones too) as the items so far leave it, from [synced].
  List<Json> _all(String entity, Iterable<Json> synced, Json? Function(String id) current) => [
    for (final id in {for (final r in synced) r['id'] as String, ...?_draftedIds[entity]})
      if (current(id) case final row?) row,
  ];

  /// contributions.check_counted_once, after an entry, goal or contribution changed
  /// ([goalChanged]: a goal): no two goals that count (live, not archived) follow one account
  /// (account_followed, checked after a goal changed), and no contribution's entry, or the other
  /// leg of its transfer, moves an account a goal follows by balance (counted_by_contribution
  /// after a goal changed, else counted_by_balance).
  ///
  /// What was there before was checked when it was written, so after an entry or a contribution
  /// only the contributions that changed since the last check, and those of the entries that did
  /// (and their transfer partners), are looked at; after a goal, every one.
  void _checkCountedOnce({required bool goalChanged}) {
    final since = [..._sinceCheck];
    _sinceCheck.clear();
    final counting = [
      for (final g in _all(_Draft._goal, _l.rawGoals, goal))
        if (g['deleted_at'] == null && g['status'] != 'archived') g,
    ];
    final followers = <String, List<Json>>{};
    for (final g in counting) {
      if (g['linked_account_id'] case final String a) (followers[a] ??= []).add(g);
    }
    if (followers.isEmpty) return;
    String accountName(String id) => account(id)?['name'] as String? ?? 'an account';
    if (goalChanged) {
      final oldestFirst = [...counting]
        ..sort((a, b) {
          final t = isoMicros(a['created_at']).compareTo(isoMicros(b['created_at']));
          return t != 0 ? t : (a['id'] as String).compareTo(b['id'] as String);
        });
      for (final g in oldestFirst) {
        final a = g['linked_account_id'] as String?;
        if (a != null && followers[a]!.length > 1) {
          _refuse('account_followed', '${g['name']} already follows ${accountName(a)}');
        }
      }
    }
    final Iterable<Json> contributions;
    if (goalChanged) {
      contributions = _all(_Draft._contribution, _l.rawContributions, contribution);
    } else {
      final ids = <String>{};
      for (final e in since) {
        if (e.entity == _Draft._contribution) ids.add(e.entityId);
        if (e.entity != _Draft._entry) continue;
        final group = e.data['transfer_group_id'] as String?;
        final legs = {
          e.entityId,
          if (group != null) ...[for (final t in _legsOf(group)) t['id'] as String],
        };
        for (final leg in legs) {
          for (final c in _contributionsWhere(entryId: leg)) {
            ids.add(c['id'] as String);
          }
        }
      }
      contributions = [
        for (final id in ids)
          if (contribution(id) case final c?) c,
      ];
    }
    for (final c in contributions) {
      final entryId = c['transaction_id'] as String?;
      if (entryId == null || c['deleted_at'] != null) continue;
      final g = goal(c['goal_id'] as String);
      if (g == null || g['deleted_at'] != null || g['status'] == 'archived' || g['tracking_mode'] != 'contribution') {
        continue;
      }
      final t = entry(entryId);
      if (t == null) continue;
      final group = t['transfer_group_id'] as String?;
      final legs = [
        t,
        if (group != null)
          for (final m in _legsOf(group))
            if (m['id'] != entryId) m,
      ];
      for (final m in legs) {
        if (m['deleted_at'] != null) continue;
        final followed = followers[m['account_id']];
        if (followed == null) continue;
        final where = accountName(m['account_id'] as String);
        if (goalChanged) _refuse('counted_by_contribution', 'An entry in $where already counts toward ${g['name']}');
        _refuse(
          'counted_by_balance',
          '${followed.first['name']} already counts that entry, through the balance of $where',
        );
      }
    }
  }
}

/// Goals and their contributions, queued like every other write (design §2.3). Each write is
/// checked first as the server will check it ([_Draft]); what the server would refuse is refused
/// here with its code and words ([WriteRefused]), so a write made offline isn't refused only once
/// it's sent. The views to read them with are in core/finance/goal_providers.dart.
extension GoalWrites on LocalWrites {
  // ---- goals ----

  /// A new goal in your currency, with [id] or a new one (`POST /personal/goals`); returns its id.
  /// Refused when it follows an account another goal follows, or one whose entries count toward
  /// a goal already (account_followed, counted_by_contribution).
  Future<String> createGoal(GoalDraft goal, {String? id}) async {
    final l = await _ledger();
    id ??= LocalWrites._uuid.v4();
    final body = goal._body();
    final entities = (_Draft(this, l)..add(BatchItem.createGoal(id, body))).finish();
    await _queue(
      OutboxOp(
        method: 'POST',
        path: '/api/v1/personal/goals',
        body: _json((body..id = id).toJson()),
        label: 'Added goal ${goal.name.trim()}',
        entities: entities,
        createdAt: _now(),
      ),
    );
    return id;
  }

  /// Saves goal [id] as [goal] (`PUT /personal/goals/{id}`, the full state). Switching its mode
  /// drops what the old mode used (its account, or its typed progress); contributions are kept,
  /// uncounted, until it counts contributions again. Switching to contributions with
  /// [startingContributionMinor] also records that much as a first contribution, dated today, in
  /// the same `POST /personal/batch` (the "reconcile" step). Nothing is queued when nothing
  /// changes.
  Future<void> updateGoal(String id, GoalDraft goal, {int? startingContributionMinor}) async {
    final l = await _ledger();
    await _queueGoalEdit(l, id, goal._body(), 'Edited goal ${goal.name.trim()}', starting: startingContributionMinor);
  }

  /// "Reconcile": goal [id] tracked another way from now on, with what the new [mode] needs
  /// ([linkedAccountId] for an account's balance, [manualProgressMinor] by hand, and optionally
  /// [startingContributionMinor] for contributions; see [updateGoal]). Refused while an
  /// allocation rule sends money to a goal leaving contributions (rule_points_here).
  Future<void> switchGoalMode(
    String id,
    GoalMode mode, {
    String? linkedAccountId,
    int? manualProgressMinor,
    int? startingContributionMinor,
  }) async {
    final l = await _ledger();
    final before = _required(l.rawGoal(id), 'Goal');
    final body = _goalIn(before)
      ..trackingMode = PersonalGoalInTrackingModeEnum.fromJson(mode.wire)!
      ..linkedAccountId = mode == GoalMode.linkedBalance ? linkedAccountId : null
      ..manualProgressMinor = mode == GoalMode.manual ? manualProgressMinor : null;
    await _queueGoalEdit(l, id, body, 'Changed how ${before['name']} is tracked', starting: startingContributionMinor);
  }

  /// Sets goal [id]'s status: [GoalStatus.paused] to pause it, [GoalStatus.active] to resume (or
  /// unarchive, or reopen) it, [GoalStatus.completed] once you say it's done (the app never
  /// completes a goal itself), [GoalStatus.archived] to put it away (it then counts nothing and
  /// takes no contributions). Nothing is queued when it's already so.
  Future<void> setGoalStatus(String id, GoalStatus status) async {
    final l = await _ledger();
    final before = _required(l.rawGoal(id), 'Goal');
    final was = before['status'];
    if (was == status.wire) return;
    final verb = switch (status) {
      GoalStatus.paused => 'Paused',
      GoalStatus.completed => 'Completed',
      GoalStatus.archived => 'Archived',
      GoalStatus.active when was == 'paused' => 'Resumed',
      GoalStatus.active when was == 'archived' => 'Unarchived',
      GoalStatus.active => 'Reopened',
    };
    final body = _goalIn(before)..status = PersonalGoalInStatusEnum.fromJson(status.wire);
    await _queueGoalEdit(l, id, body, '$verb ${before['name']}');
  }

  /// "Update progress" on a goal you track by hand: what's saved now. Refused for a goal tracked
  /// another way (progress_not_used).
  Future<void> setGoalProgress(String id, int progressMinor) async {
    final l = await _ledger();
    final before = _required(l.rawGoal(id), 'Goal');
    if (before['tracking_mode'] != 'manual') {
      _refuse('progress_not_used', 'Only a goal you track by hand has progress you type');
    }
    final body = _goalIn(before)..manualProgressMinor = progressMinor;
    await _queueGoalEdit(l, id, body, 'Updated progress on ${before['name']}');
  }

  Future<void> _queueGoalEdit(Ledger l, String id, PersonalGoalIn body, String label, {int? starting}) async {
    final before = _required(l.rawGoal(id), 'Goal');
    final startsCounting = before['tracking_mode'] != 'contribution' && body.trackingMode.value == 'contribution';
    if (starting != null && starting > 0 && startsCounting) {
      final draft = _Draft(this, l)
        ..add(BatchItem.updateGoal(id, body))
        ..add(
          BatchItem.createContribution(
            LocalWrites._uuid.v4(),
            PersonalGoalContributionIn(
              goalId: id,
              amountMinor: starting,
              date: apiDate(appClock.now()),
              note: 'Starting amount',
            ),
          ),
        );
      return _queue(draft.op(label));
    }
    final version = before['version'] as int;
    final entities = (_Draft(this, l)..add(BatchItem.updateGoal(id, body))).finish();
    if (entities.isEmpty) return;
    await _queue(
      OutboxOp(
        method: 'PUT',
        path: '/api/v1/personal/goals/$id',
        body: _json(
          (body
                ..id = null
                ..version = version)
              .toJson(),
        ),
        label: label,
        entities: entities,
        createdAt: _now(),
      ),
    );
  }

  /// Deletes goal [id] (`DELETE /personal/goals/{id}`), and its contributions with it. Refused
  /// while an allocation rule sends money to it (rule_points_here).
  Future<void> deleteGoal(String id) => _setGoalDeletedOp(id, true);

  /// Brings deleted goal [id] back, with the contributions deleted with it (not those whose entry
  /// is still deleted). Refused when the account it follows was deleted.
  Future<void> restoreGoal(String id) => _setGoalDeletedOp(id, false);

  Future<void> _setGoalDeletedOp(String id, bool deleted) async {
    final l = await _ledger();
    final before = _required(l.rawGoal(id), 'Goal');
    if ((before['deleted_at'] != null) == deleted) return;
    final version = before['version'] as int;
    // The goal first (keepMine re-versions by it), then its contributions.
    final entities = (_Draft(this, l).._setGoalDeleted(id, deleted)).finish();
    await _queue(
      OutboxOp(
        method: deleted ? 'DELETE' : 'POST',
        path: deleted ? '/api/v1/personal/goals/$id' : '/api/v1/personal/goals/$id/restore',
        query: {'version': '$version'},
        label: '${deleted ? 'Deleted' : 'Restored'} goal ${before['name']}',
        entities: entities,
        createdAt: _now(),
      ),
    );
  }

  // ---- contributions ----

  /// [amountMinor] put towards goal [goalId] on [date] (`POST /personal/goal-contributions`);
  /// returns its id. With [entryId], the entry that moved it (a transfer's in-leg, an
  /// investment): at least this much, counting toward no other goal, and not moving an account a
  /// goal follows. Refused for a goal that doesn't take contributions (goal_tracks_balance,
  /// goal_is_manual, goal_archived).
  Future<String> addContribution({
    required String goalId,
    required int amountMinor,
    required DateTime date,
    String? entryId,
    String? note,
    String? id,
  }) async {
    final l = await _ledger();
    id ??= LocalWrites._uuid.v4();
    final body = PersonalGoalContributionIn(
      goalId: goalId,
      amountMinor: amountMinor,
      date: apiDate(date),
      transactionId: entryId,
      note: _notes(note),
    );
    final entities = (_Draft(this, l)..add(BatchItem.createContribution(id, body))).finish();
    final goalName = l.rawGoal(goalId)?['name'];
    await _queue(
      OutboxOp(
        method: 'POST',
        path: '/api/v1/personal/goal-contributions',
        body: _json((body..id = id).toJson()),
        label: 'Added ${formatMinor(amountMinor, currency: entities.first.data['currency'] as String)} to $goalName',
        entities: entities,
        createdAt: _now(),
      ),
    );
    return id;
  }

  /// Money moved from account [fromAccountId] to [toAccountId] for goal [goalId]: the transfer's two
  /// legs and a contribution made with its in-leg, in one `POST /personal/batch` (design §10 risk
  /// 25). [description] defaults to "Saved for" and the goal's name. Returns the contribution's
  /// id. Refused when [toAccountId] (or [fromAccountId]) is an account a goal follows: its balance
  /// counts the money already.
  Future<String> contributeByTransfer({
    required String goalId,
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    required DateTime date,
    String? description,
    String? note,
  }) async {
    final l = await _ledger();
    final goalName = _required(l.rawGoal(goalId), 'Goal')['name'];
    final outId = LocalWrites._uuid.v4(), inId = LocalWrites._uuid.v4(), id = LocalWrites._uuid.v4();
    final group = transferGroupIdFor(outId, inId);
    PersonalTxnIn leg(String accountId, PersonalTxnInDirectionEnum direction) => PersonalTxnIn(
      type: PersonalTxnInTypeEnum.transfer,
      amountMinor: amountMinor,
      description: description ?? 'Saved for $goalName',
      date: apiDate(date),
      accountId: accountId,
      direction: direction,
      transferGroupId: group,
      source_: PersonalTxnInSource_Enum.manual,
    );
    final draft = _Draft(this, l)
      ..add(BatchItem.createEntry(outId, leg(fromAccountId, PersonalTxnInDirectionEnum.out_)))
      ..add(BatchItem.createEntry(inId, leg(toAccountId, PersonalTxnInDirectionEnum.in_)))
      ..add(BatchItem.createContribution(id, _newContribution(goalId, amountMinor, date, inId, note)));
    await _queue(
      draft.op('Added ${formatMinor(amountMinor, currency: l.userOut()['currency'] as String)} to $goalName'),
    );
    return id;
  }

  /// Money invested from account [fromAccountId] for goal [goalId] (into [holdingId], if given): an
  /// investment entry and a contribution made with it, in one `POST /personal/batch`.
  /// [description] defaults to "Invested for" and the goal's name. Returns the contribution's id.
  Future<String> contributeByInvestment({
    required String goalId,
    required String fromAccountId,
    required int amountMinor,
    required DateTime date,
    String? holdingId,
    String? description,
    String? note,
  }) async {
    final l = await _ledger();
    final goalName = _required(l.rawGoal(goalId), 'Goal')['name'];
    final entryId = LocalWrites._uuid.v4(), id = LocalWrites._uuid.v4();
    final draft = _Draft(this, l)
      ..add(
        BatchItem.createEntry(
          entryId,
          PersonalTxnIn(
            type: PersonalTxnInTypeEnum.investmentContribution,
            amountMinor: amountMinor,
            description: description ?? 'Invested for $goalName',
            date: apiDate(date),
            accountId: fromAccountId,
            holdingId: holdingId,
            source_: PersonalTxnInSource_Enum.manual,
          ),
        ),
      )
      ..add(BatchItem.createContribution(id, _newContribution(goalId, amountMinor, date, entryId, note)));
    await _queue(
      draft.op('Added ${formatMinor(amountMinor, currency: l.userOut()['currency'] as String)} to $goalName'),
    );
    return id;
  }

  PersonalGoalContributionIn _newContribution(
    String goalId,
    int amountMinor,
    DateTime date,
    String entryId,
    String? note,
  ) => PersonalGoalContributionIn(
    goalId: goalId,
    amountMinor: amountMinor,
    date: apiDate(date),
    transactionId: entryId,
    note: _notes(note),
  );

  /// Changes contribution [id] (`PUT /personal/goal-contributions/{id}`): what's given, the rest as
  /// it is. [entryId] links another entry; [unlinkEntry] drops the entry; [note] '' clears it.
  /// Nothing is queued when nothing changes.
  Future<void> updateContribution(
    String id, {
    String? goalId,
    int? amountMinor,
    DateTime? date,
    String? entryId,
    bool unlinkEntry = false,
    String? note,
  }) async {
    final l = await _ledger();
    final before = _required(l.rawContribution(id), 'Contribution');
    final body = _contributionIn(before);
    if (goalId != null) body.goalId = goalId;
    if (amountMinor != null) body.amountMinor = amountMinor;
    if (date != null) body.date = apiDate(date);
    if (entryId != null) body.transactionId = entryId;
    if (unlinkEntry) body.transactionId = null;
    if (note != null) body.note = _notes(note);
    final version = before['version'] as int;
    final entities = (_Draft(this, l)..add(BatchItem.updateContribution(id, body))).finish();
    if (entities.isEmpty) return;
    final c = entities.first.data;
    await _queue(
      OutboxOp(
        method: 'PUT',
        path: '/api/v1/personal/goal-contributions/$id',
        body: _json(
          (body
                ..id = null
                ..version = version)
              .toJson(),
        ),
        label: 'Edited ${_contributionLabel(l, c)}',
        entities: entities,
        createdAt: _now(),
      ),
    );
  }

  /// Deletes contribution [id] (`DELETE /personal/goal-contributions/{id}`); its entry stays.
  Future<void> deleteContribution(String id) => _setContributionDeletedOp(id, true);

  /// Brings deleted contribution [id] back, checked as if it were made now.
  Future<void> restoreContribution(String id) => _setContributionDeletedOp(id, false);

  Future<void> _setContributionDeletedOp(String id, bool deleted) async {
    final l = await _ledger();
    final before = _required(l.rawContribution(id), 'Contribution');
    if ((before['deleted_at'] != null) == deleted) return;
    final version = before['version'] as int;
    final entities = (_Draft(this, l).._setContributionDeleted(id, deleted)).finish();
    await _queue(
      OutboxOp(
        method: deleted ? 'DELETE' : 'POST',
        path: deleted ? '/api/v1/personal/goal-contributions/$id' : '/api/v1/personal/goal-contributions/$id/restore',
        query: {'version': '$version'},
        label: '${deleted ? 'Deleted' : 'Restored'} ${_contributionLabel(l, before)}',
        entities: entities,
        createdAt: _now(),
      ),
    );
  }

  /// "₹2,000 to Ladakh trip".
  String _contributionLabel(Ledger l, Json c) {
    final amount = formatMinor(c['amount_minor'] as int, currency: c['currency'] as String);
    return '$amount to ${l.rawGoal(c['goal_id'] as String)?['name']}';
  }
}
