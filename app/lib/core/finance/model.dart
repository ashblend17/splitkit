/// The personal ledger's types, as the server defines them (api/app/modules/personal/ledger_rules.py):
/// account types and which of them are owed, entry types and which way each moves money, and the
/// two rows the finance maths reads, accounts ([FinAccount]) and entries ([FinEntry]).
///
/// Everything in core/finance is pure Dart (no Flutter, no I/O) and gives typed results. Derived
/// finance numbers (balances, cash flow, net worth) are worked out only here, on the device; the
/// server stores and checks the records they come from.
library;

import '../local/personal_index.dart';

/// What an account is. Cards and loans are owed ([isLiability]): their balance is what you owe.
enum AccountType {
  cash('cash'),
  bank('bank'),
  creditCard('credit_card'),
  loan('loan'),
  investment('investment'),
  otherAsset('other_asset');

  const AccountType(this.wire);

  /// As the API writes it.
  final String wire;

  /// Whether the balance is what you owe: money going out raises it.
  bool get isLiability => this == creditCard || this == loan;
}

final _accountTypes = {for (final t in AccountType.values) t.wire: t};

/// The [AccountType] the API wrote as [s], or null for one this build doesn't know.
AccountType? accountTypeFromWire(String? s) => _accountTypes[s];

/// What a personal entry is.
enum TxnType {
  income('income'),
  expense('expense'),

  /// One leg of a move between two of your accounts; its partner shares its transfer group.
  transfer('transfer'),

  /// Money back for a spend (refund_of_id, when known).
  refund('refund'),
  investmentContribution('investment_contribution'),
  investmentWithdrawal('investment_withdrawal'),

  /// A balance correction (Reconcile): moves one account, counts nowhere else.
  adjustment('adjustment');

  const TxnType(this.wire);

  /// As the API writes it.
  final String wire;
}

final _txnTypes = {for (final t in TxnType.values) t.wire: t};

/// The [TxnType] the API wrote as [s], or null for one this build doesn't know: such an entry is
/// left out of every figure, so a type added later doesn't break this build (ISS-073).
TxnType? txnTypeFromWire(String? s) => _txnTypes[s];

/// Which way money moved through an account: the API's `direction`, 'in' or 'out'. (Not "Flow",
/// which Flutter's widgets library already has.)
enum MoneyFlow {
  inflow('in'),
  outflow('out');

  const MoneyFlow(this.wire);

  /// As the API writes it.
  final String wire;

  MoneyFlow get opposite => this == inflow ? outflow : inflow;
}

/// The [MoneyFlow] the API wrote as [s] ('in' or 'out'), else null.
MoneyFlow? flowFromWire(String? s) => switch (s) {
  'in' => MoneyFlow.inflow,
  'out' => MoneyFlow.outflow,
  _ => null,
};

/// The way [t] moves money (ledger_rules.IMPLIED_DIRECTION), or null for a transfer leg or a
/// balance correction, which say their own.
MoneyFlow? impliedFlow(TxnType t) => switch (t) {
  TxnType.income || TxnType.refund || TxnType.investmentWithdrawal => MoneyFlow.inflow,
  TxnType.expense || TxnType.investmentContribution => MoneyFlow.outflow,
  TxnType.transfer || TxnType.adjustment => null,
};

/// Days from [start] to [end], both included, as day keys (20260901: see dayKey in
/// core/local/personal_index.dart).
typedef DayRange = ({int start, int end});

extension DayRangeContains on DayRange {
  bool contains(int day) => day >= start && day <= end;
}

/// The days of [month] in [year] (a month past December rolls into the next year).
DayRange monthRange(int year, int month) {
  final first = DateTime.utc(year, month);
  final last = DateTime.utc(first.year, first.month + 1, 0);
  return (start: _key(first), end: _key(last));
}

/// The day key [days] days after [day] (before, if negative), counted in calendar days.
int addDays(int day, int days) => _key(DateTime.utc(day ~/ 10000, day ~/ 100 % 100, day % 100 + days));

int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// [d]'s calendar day as a day key (20260925), as [d] reads it (local time for a local DateTime).
int dayKeyOf(DateTime d) => _key(d);

/// Calendar days from day key [fromDay] to [toDay] (negative when [toDay] is before), counted in
/// UTC so a daylight-saving change never makes a day 23 or 25 hours long.
int daysBetween(int fromDay, int toDay) => _utc(toDay).difference(_utc(fromDay)).inDays;

DateTime _utc(int day) => DateTime.utc(day ~/ 10000, day ~/ 100 % 100, day % 100);

/// One of your accounts (personal_accounts): what you hold, or for a card or loan, what you owe.
final class FinAccount {
  const FinAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    this.openingMinor = 0,
    this.smsLabel,
    this.linkedAccountId,
    this.accountNumber,
    this.closed = false,
    this.deleted = false,
    this.createdMicros = 0,
  });

  /// The account as synced, or null if its type is one this build doesn't know.
  static FinAccount? read(Map<String, dynamic> raw) {
    final type = accountTypeFromWire(raw['type'] as String?);
    if (type == null) return null;
    return FinAccount(
      id: raw['id'] as String,
      name: raw['name'] as String,
      type: type,
      currency: raw['currency'] as String,
      openingMinor: raw['opening_balance_minor'] as int? ?? 0,
      smsLabel: raw['sms_label'] as String?,
      linkedAccountId: raw['linked_account_id'] as String?,
      accountNumber: raw['account_number'] as String?,
      closed: raw['status'] == 'closed',
      deleted: raw['deleted_at'] != null,
      createdMicros: isoMicros(raw['created_at']),
    );
  }

  final String id;
  final String name;
  final AccountType type;
  final String currency;

  /// What it held (or, owed) before its first entry.
  final int openingMinor;

  /// The bank SMS label its entries carry ("HDFC ··4821"), if any.
  final String? smsLabel;

  /// The account this one is part of (the same account under another label, or a debit card on
  /// a bank account): its entries count in that account's balance, as that account's type, and
  /// its own opening doesn't count. Null for most accounts.
  final String? linkedAccountId;

  /// Its full number (digits), if you gave it: a bank SMS label whose digits end it is this
  /// account (account_links.dart).
  final String? accountNumber;

  /// Closed accounts take no new entries but still count in net worth.
  final bool closed;

  /// Deleted accounts count nowhere.
  final bool deleted;

  /// created_at, in microseconds since the epoch: accounts are listed by it, then by id.
  final int createdMicros;

  @override
  String toString() => 'FinAccount($name, ${type.wire}${closed ? ', closed' : ''}${deleted ? ', deleted' : ''})';
}

/// One personal entry, as the finance maths reads it: the Ledger's own typed row, read once per
/// synced map. Under the design's names: `amountMinor` is [PersonalRow.amount], `label` is
/// [PersonalRow.account] (the bank's label; [PersonalRow.accountId] is the account),
/// `reportedBalanceMinor` is [PersonalRow.balance], and the typed `type` is
/// [PersonalRow.txnType] (null for a type this build doesn't know). [PersonalRow.atMicros] is
/// when it happened (the SMS's time, else created_at).
///
/// Engine functions take every entry and skip deleted ones and unknown types themselves.
typedef FinEntry = PersonalRow;

/// Where a goal's progress comes from (ledger_rules.GOAL_MODES): its contributions, the balance
/// of the account it follows, or a figure you type. An entry counts towards a goal one way only.
enum GoalMode {
  contribution('contribution'),
  linkedBalance('linked_balance'),
  manual('manual');

  const GoalMode(this.wire);

  /// As the API writes it.
  final String wire;
}

final _goalModes = {for (final m in GoalMode.values) m.wire: m};

/// The [GoalMode] the API wrote as [s], or null for one this build doesn't know (the goal is
/// then left out everywhere, as an entry of an unknown type is).
GoalMode? goalModeFromWire(String? s) => _goalModes[s];

/// Where a goal stands (ledger_rules.GOAL_STATUSES). An archived goal takes no contributions and
/// counts nothing; you mark a goal completed yourself.
enum GoalStatus {
  active('active'),
  paused('paused'),
  completed('completed'),
  archived('archived');

  const GoalStatus(this.wire);

  /// As the API writes it.
  final String wire;
}

final _goalStatuses = {for (final s in GoalStatus.values) s.wire: s};

/// The [GoalStatus] the API wrote as [s], or null for one this build doesn't know.
GoalStatus? goalStatusFromWire(String? s) => _goalStatuses[s];

/// A synced map's reader, or [_unknown] for a row this build can't read: kept per map, so a
/// rebuilt Ledger reuses the rows of goals and contributions that didn't change.
final _goalsRead = Expando<Object>('FinGoal');
final _contributionsRead = Expando<Object>('FinContribution');
const _unknown = Object();

/// One of your goals (personal_goals), as synced. The server keeps and checks goals; progress,
/// what's left and what's needed per month are worked out on the device (core/finance/goals.dart).
final class FinGoal {
  const FinGoal({
    required this.id,
    required this.name,
    required this.currency,
    required this.targetMinor,
    required this.mode,
    required this.status,
    required this.startDay,
    this.targetDay,
    this.linkedAccountId,
    this.manualProgressMinor,
    this.expectedReturnBp,
    this.priority = 0,
    this.createdMicros = 0,
    this.deletedAt,
    this.version = 1,
  });

  /// The goal as synced (read once per map), or null if its mode or status is one this build
  /// doesn't know.
  static FinGoal? read(Map<String, dynamic> raw) {
    final known = _goalsRead[raw] ??= _readGoal(raw) ?? _unknown;
    return known is FinGoal ? known : null;
  }

  static FinGoal? _readGoal(Map<String, dynamic> raw) {
    final mode = goalModeFromWire(raw['tracking_mode'] as String?);
    final status = goalStatusFromWire(raw['status'] as String?);
    if (mode == null || status == null) return null;
    final created = isoMicros(raw['created_at']);
    final date = raw['target_date'] as String?;
    return FinGoal(
      id: raw['id'] as String,
      name: raw['name'] as String,
      currency: raw['currency'] as String,
      targetMinor: raw['target_minor'] as int,
      targetDay: date == null ? null : dayKey(date),
      mode: mode,
      linkedAccountId: raw['linked_account_id'] as String?,
      manualProgressMinor: raw['manual_progress_minor'] as int?,
      expectedReturnBp: raw['expected_return_bp'] as int?,
      priority: raw['priority'] as int? ?? 0,
      status: status,
      startDay: dayKeyOf(DateTime.fromMicrosecondsSinceEpoch(created)),
      createdMicros: created,
      deletedAt: raw['deleted_at'] as String?,
      version: raw['version'] as int? ?? 1,
    );
  }

  final String id;
  final String name;
  final String currency;
  final int targetMinor;

  /// The target date as a day key, or null for a goal without one (progress only).
  final int? targetDay;

  final GoalMode mode;

  /// The account whose balance is the progress: set in [GoalMode.linkedBalance] only.
  final String? linkedAccountId;

  /// The progress you typed: set in [GoalMode.manual] only.
  final int? manualProgressMinor;

  /// Expected monthly return in basis points (80 = 0.8% a month), for the optional estimate.
  final int? expectedReturnBp;

  /// Goals are listed by priority (0 first), then oldest first.
  final int priority;

  final GoalStatus status;

  /// The day it was made, on this device's calendar (its created_at): where "behind" measures
  /// from.
  final int startDay;

  /// created_at, in microseconds since the epoch.
  final int createdMicros;

  /// When it was deleted, as synced, or null for a live goal.
  final String? deletedAt;

  final int version;

  bool get deleted => deletedAt != null;

  /// Counts towards the no-double-counting rules: live and not archived.
  bool get counts => !deleted && status != GoalStatus.archived;

  /// Takes contributions now: counts and is tracked by its contributions.
  bool get takesContributions => counts && mode == GoalMode.contribution;

  /// The API's order: priority, then created_at, then id.
  static int order(FinGoal a, FinGoal b) {
    final p = a.priority.compareTo(b.priority);
    if (p != 0) return p;
    final c = a.createdMicros.compareTo(b.createdMicros);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  @override
  String toString() => 'FinGoal($name, ${mode.wire}, ${status.wire}${deleted ? ', deleted' : ''})';
}

/// Money put towards a goal (personal_goal_contributions), as synced: optionally with the entry
/// that moved it ([transactionId]: a transfer's in-leg, an investment).
final class FinContribution {
  const FinContribution({
    required this.id,
    required this.goalId,
    required this.amountMinor,
    required this.currency,
    required this.day,
    this.transactionId,
    this.note,
    this.createdMicros = 0,
    this.deletedAt,
    this.version = 1,
  });

  /// The contribution as synced, read once per map.
  static FinContribution read(Map<String, dynamic> raw) => (_contributionsRead[raw] ??= FinContribution(
    id: raw['id'] as String,
    goalId: raw['goal_id'] as String,
    transactionId: raw['transaction_id'] as String?,
    amountMinor: raw['amount_minor'] as int,
    currency: raw['currency'] as String,
    day: dayKey(raw['date'] as String),
    note: raw['note'] as String?,
    createdMicros: isoMicros(raw['created_at']),
    deletedAt: raw['deleted_at'] as String?,
    version: raw['version'] as int? ?? 1,
  )) as FinContribution;

  final String id;
  final String goalId;

  /// The entry that moved the money, if any. It counts towards one goal at most.
  final String? transactionId;

  final int amountMinor;
  final String currency;

  /// Its date as a day key.
  final int day;

  final String? note;

  /// created_at, in microseconds since the epoch.
  final int createdMicros;

  /// When it was deleted (by you, or with its goal or entry), as synced, or null.
  final String? deletedAt;

  final int version;

  bool get deleted => deletedAt != null;

  /// The API's order: newest date first, then newest made, then id (descending).
  static int newestFirst(FinContribution a, FinContribution b) {
    final d = b.day.compareTo(a.day);
    if (d != 0) return d;
    final c = b.createdMicros.compareTo(a.createdMicros);
    return c != 0 ? c : b.id.compareTo(a.id);
  }

  @override
  String toString() => 'FinContribution($amountMinor to $goalId${deleted ? ', deleted' : ''})';
}

// ---- holdings (finance revamp Phase 5) ----

/// What a holding is (personal/schemas.py HoldingType).
enum HoldingType {
  mutualFund('mutual_fund'),
  stock('stock'),
  fd('fd'),
  gold('gold'),
  other('other');

  const HoldingType(this.wire);

  /// As the API writes it.
  final String wire;
}

final _holdingTypes = {for (final t in HoldingType.values) t.wire: t};

/// The [HoldingType] the API wrote as [s], or null for one this build doesn't know: such a
/// holding is left out of every figure.
HoldingType? holdingTypeFromWire(String? s) => _holdingTypes[s];

/// What you keep in an investment account (personal_holdings): a fund, shares, a deposit, gold,
/// with what it was worth when you last typed its value. Gains and whether a value is stale are
/// worked out on the device (holdings.dart).
final class FinHolding {
  const FinHolding({
    required this.id,
    required this.accountId,
    required this.name,
    required this.type,
    required this.marketValueMinor,
    required this.valuationDay,
    required this.currency,
    this.quantity,
    this.costBasisMinor,
    this.createdMicros = 0,
    this.deleted = false,
    this.version = 1,
  });

  /// The holding as synced, or null if its type is one this build doesn't know. Read once per
  /// synced map, as [PersonalRow] is, so a rebuilt Ledger reuses the holdings that didn't change.
  static FinHolding? read(Map<String, dynamic> raw) {
    if (_read[raw] case final hit?) return hit;
    final type = holdingTypeFromWire(raw['asset_type'] as String?);
    if (type == null) return null;
    return _read[raw] = FinHolding(
      id: raw['id'] as String,
      accountId: raw['account_id'] as String,
      name: raw['name'] as String,
      type: type,
      marketValueMinor: raw['market_value_minor'] as int,
      valuationDay: dayKey(raw['valuation_at'] as String),
      currency: raw['currency'] as String,
      quantity: raw['quantity'] as String?,
      costBasisMinor: raw['cost_basis_minor'] as int?,
      createdMicros: isoMicros(raw['created_at']),
      deleted: raw['deleted_at'] != null,
      version: raw['version'] as int? ?? 1,
    );
  }

  static final _read = Expando<FinHolding>('FinHolding');

  final String id;

  /// The investment account it's in.
  final String accountId;
  final String name;
  final HoldingType type;

  /// Units, shares or grams as the API writes them ("412.358"), so nothing is lost to floats.
  final String? quantity;

  /// What you paid for it in all, if you said: a gain is shown only with it.
  final int? costBasisMinor;

  /// What it was worth on [valuationDay].
  final int marketValueMinor;

  /// The day of its value, as a day key (20260815).
  final int valuationDay;

  /// Its account's currency.
  final String currency;

  /// created_at, in microseconds since the epoch: holdings are listed by it, then by id.
  final int createdMicros;
  final bool deleted;
  final int version;

  @override
  String toString() => 'FinHolding($name, ${type.wire}, $marketValueMinor on $valuationDay${deleted ? ', deleted' : ''})';
}

// ---- allocation rules and plans (finance revamp Phase 3) ----

/// How a rule sets money aside (ledger_rules.ALLOCATION_KINDS): a share of each income, in basis
/// points (over 100% allowed: the app warns and never rescales), or a fixed amount.
enum AllocationKind {
  percentage('percentage'),
  fixed('fixed');

  const AllocationKind(this.wire);

  /// As the API writes it.
  final String wire;
}

/// The [AllocationKind] the API wrote as [s], or null for one this build doesn't know (the rule
/// or plan is then left out everywhere).
AllocationKind? allocationKindFromWire(String? s) => switch (s) {
  'percentage' => AllocationKind.percentage,
  'fixed' => AllocationKind.fixed,
  _ => null,
};

final _rulesRead = Expando<Object>('FinRule');
final _plansRead = Expando<Object>('FinPlan');

/// An allocation rule (personal_allocation_rules), as synced: what to set aside from each income
/// it applies to, for a goal or an account. The plans it makes are worked out on the device
/// (allocation.dart); the server keeps and checks rules and plans.
final class FinRule {
  const FinRule({
    required this.id,
    required this.kind,
    required this.currency,
    this.name,
    this.sourceCategoryId,
    this.sourceAccountId,
    this.percentBp,
    this.amountMinor,
    this.goalId,
    this.accountId,
    this.active = true,
    this.priority = 0,
    this.trigger = 'income_recorded',
    this.createdMicros = 0,
    this.deletedAt,
    this.version = 1,
  });

  /// The rule as synced (read once per map), or null if its kind is one this build doesn't know.
  static FinRule? read(Map<String, dynamic> raw) {
    final known = _rulesRead[raw] ??= _readRule(raw) ?? _unknown;
    return known is FinRule ? known : null;
  }

  static FinRule? _readRule(Map<String, dynamic> raw) {
    final kind = allocationKindFromWire(raw['kind'] as String?);
    if (kind == null) return null;
    return FinRule(
      id: raw['id'] as String,
      name: raw['name'] as String?,
      trigger: raw['trigger'] as String? ?? 'income_recorded',
      sourceCategoryId: raw['source_category_id'] as String?,
      sourceAccountId: raw['source_account_id'] as String?,
      kind: kind,
      percentBp: raw['percent_bp'] as int?,
      amountMinor: raw['amount_minor'] as int?,
      currency: raw['currency'] as String,
      goalId: raw['goal_id'] as String?,
      accountId: raw['account_id'] as String?,
      active: raw['active'] as bool? ?? true,
      priority: raw['priority'] as int? ?? 0,
      createdMicros: isoMicros(raw['created_at']),
      deletedAt: raw['deleted_at'] as String?,
      version: raw['version'] as int? ?? 1,
    );
  }

  final String id;

  /// What you called it, if anything ("Emergency top-up").
  final String? name;

  /// When it makes plans: 'income_recorded' (the only trigger there is).
  final String trigger;

  /// Only incomes in this category, if set.
  final String? sourceCategoryId;

  /// Only incomes into this account, if set. One naming a deleted account matches nothing.
  final String? sourceAccountId;

  final AllocationKind kind;

  /// For [AllocationKind.percentage]: basis points of each income (1000 is 10%).
  final int? percentBp;

  /// For [AllocationKind.fixed]: the amount from each income.
  final int? amountMinor;

  /// Your currency when it was made.
  final String currency;

  /// Where the money goes: a goal ([goalId]) or an account ([accountId]), exactly one.
  final String? goalId;
  final String? accountId;

  /// Inactive rules make no new plans; they still point at their destination (ISS-079).
  final bool active;

  /// Rules are listed by priority (0 first), then oldest first.
  final int priority;

  /// created_at, in microseconds since the epoch: a rule applies only to incomes recorded after it.
  final int createdMicros;

  /// When it was deleted, as synced, or null for a live rule.
  final String? deletedAt;

  final int version;

  bool get deleted => deletedAt != null;

  /// What a plan made from it now records.
  PlanSnapshot get snapshot => PlanSnapshot(kind: kind, percentBp: percentBp, amountMinor: amountMinor);

  /// The API's order: priority, then created_at, then id.
  static int order(FinRule a, FinRule b) {
    final p = a.priority.compareTo(b.priority);
    if (p != 0) return p;
    final c = a.createdMicros.compareTo(b.createdMicros);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  @override
  String toString() =>
      'FinRule(${name ?? id}, ${kind.wire} ${percentBp ?? amountMinor} → ${goalId ?? accountId}'
      '${active ? '' : ', inactive'}${deleted ? ', deleted' : ''})';
}

/// The rule as a plan recorded it when it was made: an edited income is worked out again with
/// this, never with the rule as it is now.
final class PlanSnapshot {
  const PlanSnapshot({required this.kind, this.percentBp, this.amountMinor});

  final AllocationKind kind;
  final int? percentBp;
  final int? amountMinor;

  @override
  bool operator ==(Object other) =>
      other is PlanSnapshot && other.kind == kind && other.percentBp == percentBp && other.amountMinor == amountMinor;

  @override
  int get hashCode => Object.hash(kind, percentBp, amountMinor);

  @override
  String toString() => 'PlanSnapshot(${kind.wire} ${percentBp ?? amountMinor})';
}

/// What a rule set aside from one income (personal_allocation_plans), as synced: an intention,
/// never money. Its status (planned, partial, fulfilled, cancelled) is the device's to work out
/// (allocation.dart PlanView).
final class FinPlan {
  const FinPlan({
    required this.id,
    required this.sourceTransactionId,
    required this.ruleId,
    required this.snapshot,
    required this.plannedMinor,
    required this.currency,
    this.goalId,
    this.accountId,
    this.createdMicros = 0,
    this.deletedAt,
    this.version = 1,
  });

  /// The plan as synced (read once per map), or null if its kind is one this build doesn't know.
  static FinPlan? read(Map<String, dynamic> raw) {
    final known = _plansRead[raw] ??= _readPlan(raw) ?? _unknown;
    return known is FinPlan ? known : null;
  }

  static FinPlan? _readPlan(Map<String, dynamic> raw) {
    final kind = allocationKindFromWire(raw['snapshot_kind'] as String?);
    if (kind == null) return null;
    return FinPlan(
      id: raw['id'] as String,
      sourceTransactionId: raw['source_transaction_id'] as String,
      ruleId: raw['rule_id'] as String,
      snapshot: PlanSnapshot(
        kind: kind,
        percentBp: raw['snapshot_percent_bp'] as int?,
        amountMinor: raw['snapshot_amount_minor'] as int?,
      ),
      plannedMinor: raw['planned_minor'] as int,
      currency: raw['currency'] as String,
      goalId: raw['goal_id'] as String?,
      accountId: raw['account_id'] as String?,
      createdMicros: isoMicros(raw['created_at']),
      deletedAt: raw['deleted_at'] as String?,
      version: raw['version'] as int? ?? 1,
    );
  }

  final String id;

  /// The income it was made from.
  final String sourceTransactionId;
  final String ruleId;
  final PlanSnapshot snapshot;

  /// What it sets aside.
  final int plannedMinor;
  final String currency;

  /// Where the money goes, as the rule said when the plan was made: exactly one.
  final String? goalId;
  final String? accountId;

  /// created_at, in microseconds since the epoch.
  final int createdMicros;

  /// When it was deleted (with its income, or because its rule no longer applies), or null.
  final String? deletedAt;

  final int version;

  bool get deleted => deletedAt != null;

  @override
  String toString() =>
      'FinPlan($plannedMinor → ${goalId ?? accountId} from $sourceTransactionId${deleted ? ', deleted' : ''})';
}
