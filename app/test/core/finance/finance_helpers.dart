import 'package:app/core/finance/finance.dart';

/// Entries and accounts for the finance tests, with dates as day keys (20260915).

var _made = 0;

/// "2026-09-15" for 20260915.
String dateOf(int day) => '${day ~/ 10000}-${'${day ~/ 100 % 100}'.padLeft(2, '0')}-${'${day % 100}'.padLeft(2, '0')}';

/// A personal entry as synced. [time] is when it happened that day (India time); entries made
/// one after another are made a second apart, so their order is the order they're made in.
/// [direction] defaults to the one the type implies; pass `noDirection` for a row synced before
/// migration 0013.
FinEntry entry({
  String? id,
  String type = 'expense',
  int amount = 1000,
  int day = 20260915,
  String time = '10:00',
  String currency = 'INR',
  String? direction,
  bool noDirection = false,
  String? accountId,
  String? label,
  String? categoryId,
  String? transferGroupId,
  String? refundOfId,
  String? merchant,
  String? reference,
  int? balance,
  bool sms = false,
  String? deletedAt,
  String? expenseId,
  String? settlementId,
}) {
  final n = _made++;
  final at = '${dateOf(day)}T$time:00+05:30';
  final created = DateTime.utc(2026, 1, 1).add(Duration(seconds: n)).toIso8601String();
  final implied = switch (txnTypeFromWire(type)) {
    final t? => impliedFlow(t)?.wire,
    null => null,
  };
  return FinEntry({
    'id': id ?? 'e$n',
    'type': type,
    'amount_minor': amount,
    'currency': currency,
    'date': dateOf(day),
    'description': merchant ?? type,
    'category_id': categoryId,
    'merchant': merchant,
    'account': label,
    'source': sms ? 'sms' : 'manual',
    'reference': reference,
    'balance_minor': balance,
    'sms_at': sms ? at : null,
    'expense_id': expenseId,
    'settlement_id': settlementId,
    'created_at': sms ? at : created,
    'deleted_at': deletedAt,
    if (!noDirection) 'direction': direction ?? implied ?? 'out',
    'account_id': accountId,
    'transfer_group_id': transferGroupId,
    'refund_of_id': refundOfId,
  });
}

/// The two legs of a transfer of [amount] from account [from] to account [to].
(FinEntry, FinEntry) transfer({
  required String from,
  required String to,
  int amount = 1000,
  int day = 20260915,
  int? toDay,
  String group = 'g1',
  String? outId,
  String? inId,
}) => (
  entry(
    id: outId,
    type: 'transfer',
    direction: 'out',
    amount: amount,
    day: day,
    accountId: from,
    transferGroupId: group,
  ),
  entry(
    id: inId,
    type: 'transfer',
    direction: 'in',
    amount: amount,
    day: toDay ?? day,
    accountId: to,
    transferGroupId: group,
  ),
);

FinAccount account(
  String id, {
  AccountType type = AccountType.bank,
  int opening = 0,
  String currency = 'INR',
  String? label,
  String? name,
  String? linkedTo,
  String? number,
  bool closed = false,
  bool deleted = false,
  int created = 0,
}) => FinAccount(
  id: id,
  name: name ?? label ?? id,
  type: type,
  currency: currency,
  openingMinor: opening,
  smsLabel: label,
  linkedAccountId: linkedTo,
  accountNumber: number,
  closed: closed,
  deleted: deleted,
  createdMicros: created,
);

/// Category labels by id, "Uncategorised" for none.
String labelOf(String? categoryId) => categoryId ?? 'Uncategorised';
