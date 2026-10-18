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

/// One of your accounts (personal_accounts): what you hold, or for a card or loan, what you owe.
final class FinAccount {
  const FinAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    this.openingMinor = 0,
    this.smsLabel,
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
