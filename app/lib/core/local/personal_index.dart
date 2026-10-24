/// Personal entries indexed once per Ledger (ledger.dart): typed rows with their dates and times
/// read once, sorted once in the API's order, and the lookups the hot views and the category
/// suggestions need. The Ledger never changes (the store builds a new one on every change), so
/// each part is built lazily, the first time a view asks for it. Pure Dart: no Flutter, no I/O.
library;

import '../categorise/category_rules.dart';
import '../finance/model.dart';

/// One personal entry (personal_transactions) as synced ([raw], which the views turn into JSON),
/// with the fields views filter, sort and add up by already read from it. It's also the entry
/// the finance maths reads (core/finance, as FinEntry).
///
/// A row is read once per synced map: the store keeps the same maps from one Ledger to the next
/// (a change brings a new map, nothing edits one in place), so a rebuilt Ledger reuses the rows
/// of entries that didn't change.
class PersonalRow {
  factory PersonalRow(Map<String, dynamic> raw) => _read[raw] ??= PersonalRow._from(raw);

  factory PersonalRow._from(Map<String, dynamic> raw) {
    final created = isoMicros(raw['created_at']);
    final sms = raw['sms_at'];
    final type = txnTypeFromWire(raw['type'] as String);
    // Rows synced before migration 0013 have no direction; they're income or expense.
    final flow = flowFromWire(raw['direction'] as String?) ?? (type == null ? null : impliedFlow(type));
    return PersonalRow._(
      raw,
      created,
      sms == null ? created : isoMicros(sms),
      plainDayKey(raw['date'] as String),
      type,
      flow ?? MoneyFlow.outflow,
    );
  }

  static final _read = Expando<PersonalRow>('PersonalRow');

  PersonalRow._(this.raw, this.createdMicros, this.atMicros, this._plainDay, this.txnType, this.flow)
    : id = raw['id'] as String,
      date = raw['date'] as String,
      day = _plainDay >= 0 ? _plainDay : dayKey(raw['date'] as String),
      type = raw['type'] as String,
      amount = raw['amount_minor'] as int,
      currency = raw['currency'] as String,
      description = raw['description'] as String? ?? '',
      categoryId = raw['category_id'] as String?,
      account = raw['account'] as String?,
      merchant = raw['merchant'] as String?,
      channel = raw['channel'] as String?,
      // Rows synced before these columns existed (migration 0010) have no such keys.
      source = raw['source'] as String? ?? 'manual',
      reviewed = raw['reviewed'] as bool? ?? true,
      reference = raw['reference'] as String?,
      balance = raw['balance_minor'] as int?,
      expenseId = raw['expense_id'] as String?,
      settlementId = raw['settlement_id'] as String?,
      // Rows synced before these columns existed (migrations 0013 and 0016) have no such keys.
      accountId = raw['account_id'] as String?,
      transferGroupId = raw['transfer_group_id'] as String?,
      refundOfId = raw['refund_of_id'] as String?,
      holdingId = raw['holding_id'] as String?,
      deleted = raw['deleted_at'] != null;

  final Map<String, dynamic> raw;
  final String id;

  /// "2026-09-24", as stored.
  final String date;

  /// [date] as 20260924.
  final int day;

  /// [day] if [date] is written the usual way, else -1 (see [compareDates]).
  final int _plainDay;

  /// created_at, in microseconds since the epoch.
  final int createdMicros;

  /// When it happened: the SMS's time for an entry read from one, else created_at.
  final int atMicros;

  final String type;
  final int amount;
  final String currency;

  /// What it was for, as you wrote it (or the bank SMS gave it).
  final String description;
  final String? categoryId;
  final String? account;
  final String? merchant;
  final String? channel;
  final String source;
  final bool reviewed;
  final String? reference;
  final int? balance;
  final String? expenseId;
  final String? settlementId;

  /// [type] typed, or null for a type this build doesn't know (one added after it). Such an
  /// entry is skipped everywhere (PersonalIndex leaves it out): the generated PersonalTxnOut
  /// can't read it, so it can't be listed, and it's in no figure (ISS-073).
  final TxnType? txnType;

  /// Which way the money moved: `direction`, or for an entry synced before it existed (income or
  /// expense), the way its type implies.
  final MoneyFlow flow;

  /// The account it went through (personal_accounts); [account] is the bank's label.
  final String? accountId;

  /// The same for both legs of a transfer between two of your accounts.
  final String? transferGroupId;

  /// The spend a refund gives money back for, if known.
  final String? refundOfId;

  /// The holding an investment entry bought into or sold from.
  final String? holdingId;

  final bool deleted;

  bool get income => type == 'income';

  /// Linked to a split or a payment in Split ([expenseId] or [settlementId]).
  bool get linkedToSplit => expenseId != null || settlementId != null;

  /// Read from a bank SMS.
  bool get fromSms => source == 'sms';

  /// The API's order (personal/repository.py): newest date first, then newest made, then id.
  static int newestFirst(PersonalRow a, PersonalRow b) {
    final d = compareDates(b.date, b._plainDay, a.date, a._plainDay);
    if (d != 0) return d;
    final t = b.createdMicros.compareTo(a.createdMicros);
    return t != 0 ? t : b.id.compareTo(a.id);
  }
}

/// Every personal entry on the device, indexed, except those of a type this build doesn't know
/// (PersonalRow.txnType), which every view skips.
class PersonalIndex {
  PersonalIndex(Iterable<Map<String, dynamic>> raw)
    : rows = List.unmodifiable([
        for (final t in raw)
          if (PersonalRow(t) case final row when row.txnType != null) row,
      ]);

  /// In the order they were synced.
  final List<PersonalRow> rows;

  /// Live entries, in the API's order.
  late final List<PersonalRow> live = [
    for (final t in _sorted)
      if (!t.deleted) t,
  ];

  /// Deleted entries, in the API's order.
  late final List<PersonalRow> deleted = [
    for (final t in _sorted)
      if (t.deleted) t,
  ];

  late final List<PersonalRow> _sorted = [...rows]..sort(PersonalRow.newestFirst);

  /// By id (the first synced, should there be two).
  late final Map<String, PersonalRow> byId = {for (final t in rows.reversed) t.id: t};

  /// "reference|type" for every entry with a bank reference, deleted ones too.
  late final Set<String> references = {
    for (final t in rows)
      if (t.reference != null) '${t.reference}|${t.type}',
  };

  /// Live entries made by hand with no account yet, of [type] and [amount], in the API's order.
  List<PersonalRow> manualWithoutAccount(String type, int amount) => _manual[(type, amount)] ?? const [];

  /// All of [manualWithoutAccount], by type and amount.
  Map<(String, int), List<PersonalRow>> get manualByTypeAndAmount => _manual;

  late final Map<(String, int), List<PersonalRow>> _manual = () {
    final out = <(String, int), List<PersonalRow>>{};
    for (final t in live) {
      if (t.source == 'manual' && t.account == null) (out[(t.type, t.amount)] ??= []).add(t);
    }
    return out;
  }();

  /// The first live entry (in the API's order) with bank reference [reference] and [type].
  PersonalRow? liveWithReference(String reference, String type) => _byReference[(reference, type)];

  late final Map<(String, String), PersonalRow> _byReference = () {
    final out = <(String, String), PersonalRow>{};
    for (final t in live) {
      if (t.reference != null) out.putIfAbsent((t.reference!, t.type), () => t);
    }
    return out;
  }();

  /// Live entries of [type] and [amount], in the API's order.
  List<PersonalRow> liveOf(String type, int amount) => _byAmount[(type, amount)] ?? const [];

  late final Map<(String, int), List<PersonalRow>> _byAmount = () {
    final out = <(String, int), List<PersonalRow>>{};
    for (final t in live) {
      (out[(t.type, t.amount)] ??= []).add(t);
    }
    return out;
  }();

  /// Live entries linked to expense [expenseId], in the order they were synced.
  List<PersonalRow> linkedTo(String expenseId) => _byExpense[expenseId] ?? const [];

  late final Map<String, List<PersonalRow>> _byExpense = () {
    final out = <String, List<PersonalRow>>{};
    for (final t in rows) {
      if (!t.deleted && t.expenseId != null) (out[t.expenseId!] ??= []).add(t);
    }
    return out;
  }();

  /// Live entries from [merchant] linked to a payment, in the order they were synced.
  List<PersonalRow> paymentsFrom(String merchant) => _payments[merchant] ?? const [];

  late final Map<String, List<PersonalRow>> _payments = () {
    final out = <String, List<PersonalRow>>{};
    for (final t in rows) {
      if (!t.deleted && t.settlementId != null && t.merchant != null) (out[t.merchant!] ??= []).add(t);
    }
    return out;
  }();

  /// Your live manual entries of spending ([chosenSpend]) or income ([chosenIncome]), newest made
  /// first, filed by merchant and description: the categories you chose yourself
  /// (Ledger.learnedCategory).
  late final MerchantIndex<PersonalRow> chosenSpend = _chosen(false), chosenIncome = _chosen(true);

  MerchantIndex<PersonalRow> _chosen(bool income) => MerchantIndex(
    newestMadeFirst([
      for (final t in rows)
        if (!t.deleted && t.source == 'manual' && t.income == income) (t, t.createdMicros),
    ]),
    (t) => [t.merchant, t.raw['description'] as String?],
  );

  /// The part of [rows] (in the API's order) dated from [start] to [end], both included; either
  /// may be null. Compares dates as strings, as the filters always have.
  static List<PersonalRow> dated(List<PersonalRow> rows, String? start, String? end) {
    final from = end == null ? 0 : _firstIndex(rows, (t) => t.date.compareTo(end) <= 0);
    final to = start == null ? rows.length : _firstIndex(rows, (t) => t.date.compareTo(start) < 0);
    if (from == 0 && to == rows.length) return rows;
    return from >= to ? const [] : rows.sublist(from, to);
  }

  /// The first index where [test] holds, in [rows] where it fails up to some point and holds
  /// after it.
  static int _firstIndex(List<PersonalRow> rows, bool Function(PersonalRow) test) {
    var lo = 0, hi = rows.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (test(rows[mid])) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }
}

/// [rows] (each with a time in microseconds), newest first; rows with the same time stay in the
/// order given.
List<T> newestMadeFirst<T>(List<(T, int)> rows) {
  final order = [for (final (i, (row, at)) in rows.indexed) (row, at, i)]
    ..sort((a, b) {
      final t = b.$2.compareTo(a.$2);
      return t != 0 ? t : a.$3.compareTo(b.$3);
    });
  return [for (final (row, _, _) in order) row];
}

/// Rows in order of precedence, filed under the [merchantKey] of each of their texts, for
/// finding the first row under any of a few keys that gives an answer.
class MerchantIndex<T> {
  MerchantIndex(this._rows, Iterable<String?> Function(T row) textsOf) {
    // Merchants and descriptions repeat a lot; work each one's key out once.
    final keyOf = <String?, String>{};
    for (final (i, row) in _rows.indexed) {
      final keys = {for (final text in textsOf(row)) keyOf[text] ??= merchantKey(text)};
      for (final key in keys) {
        if (key.isNotEmpty) (_at[key] ??= []).add(i);
      }
    }
  }

  final List<T> _rows;
  final _at = <String, List<int>>{};

  /// For each key, where the first row filed under it that [pick] gives anything for comes, and
  /// what it gives: [first] for any set of keys is the answer with the lowest place among them.
  Map<String, (int, R)> firstByKey<R extends Object>(R? Function(T row) pick) {
    final out = <String, (int, R)>{};
    for (final MapEntry(key: key, value: places) in _at.entries) {
      for (final i in places) {
        if (pick(_rows[i]) case final answer?) {
          out[key] = (i, answer);
          break;
        }
      }
    }
    return out;
  }

  /// What [pick] gives for the first row (in order) filed under one of [keys] that it gives
  /// anything for, or null.
  R? first<R extends Object>(Iterable<String> keys, R? Function(T row) pick) {
    int? best;
    R? found;
    for (final key in keys) {
      for (final i in _at[key] ?? const <int>[]) {
        if (best != null && i >= best) break;
        final answer = pick(_rows[i]);
        if (answer != null) {
          best = i;
          found = answer;
          break;
        }
      }
    }
    return found;
  }
}

/// [iso] (an ISO 8601 time) in microseconds since the epoch, exactly as
/// `DateTime.parse(iso).microsecondsSinceEpoch`; null is the epoch. The shapes the API and the
/// device write ("2026-09-24T10:00:00.123456+00:00", "…Z") are read by hand, about 20× faster;
/// anything else goes to DateTime.parse.
int isoMicros(Object? iso) {
  if (iso == null) return 0;
  final s = iso as String;
  return _fastMicros(s) ?? DateTime.parse(s).microsecondsSinceEpoch;
}

/// [date] ("2026-09-24") as 20260924, as written (localDay rolls a day that doesn't exist over).
int dayKey(String date) {
  final plain = plainDayKey(date);
  if (plain >= 0) return plain;
  final t = DateTime.parse(date);
  return t.year * 10000 + t.month * 100 + t.day;
}

/// [dayKey] for a date written the usual way (yyyy-MM-dd), else -1.
int plainDayKey(String date) {
  if (date.length != 10 || date.codeUnitAt(4) != _dash || date.codeUnitAt(7) != _dash) return -1;
  final y = _digits(date, 0, 4), m = _digits(date, 5, 2), d = _digits(date, 8, 2);
  return y < 0 || m < 0 || d < 0 ? -1 : y * 10000 + m * 100 + d;
}

/// Compares dates [a] and [b] the way strings compare, by their [plainDayKey]s ([aKey], [bKey])
/// when both have one: the same order (fixed-width digits), and faster.
int compareDates(String a, int aKey, String b, int bKey) =>
    aKey >= 0 && bKey >= 0 ? aKey.compareTo(bKey) : a.compareTo(b);

/// Local midnight of [day] (a [dayKey]): what DateTime.parse makes of the date.
DateTime localDay(int day) => DateTime(day ~/ 10000, day ~/ 100 % 100, day % 100);

/// How many calendar days apart [a] and [b] (dayKeys) are. Counted on UTC dates: across a
/// daylight-saving change two local midnights are 47 or 49 hours apart, which inDays reads as
/// one day or two (ISS-074).
int daysApart(int a, int b) => _utcDay(a).difference(_utcDay(b)).inDays.abs();

DateTime _utcDay(int day) => DateTime.utc(day ~/ 10000, day ~/ 100 % 100, day % 100);

/// [day]'s date as a [dayKey].
int dayKeyOf(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

const _dash = 0x2D, _colon = 0x3A, _dot = 0x2E, _plus = 0x2B, _space = 0x20, _t = 0x54, _z = 0x5A;

/// The number in [s]'s [length] characters from [start], or -1 if one isn't a digit.
int _digits(String s, int start, int length) {
  var n = 0;
  for (var i = start; i < start + length; i++) {
    final d = s.codeUnitAt(i) ^ 0x30;
    if (d > 9) return -1;
    n = n * 10 + d;
  }
  return n;
}

/// yyyy-MM-dd[T ]HH:mm:ss[.f+][Z|±HH:mm], the way DateTime.parse reads it, or null for any
/// other shape. Out-of-range parts roll over the same way, since both end in the same
/// constructor arithmetic.
int? _fastMicros(String s) {
  final n = s.length;
  if (n < 19 || s.codeUnitAt(4) != _dash || s.codeUnitAt(7) != _dash || s.codeUnitAt(13) != _colon) return null;
  if (s.codeUnitAt(16) != _colon || (s.codeUnitAt(10) != _t && s.codeUnitAt(10) != _space)) return null;
  final year = _digits(s, 0, 4), month = _digits(s, 5, 2), day = _digits(s, 8, 2);
  final hour = _digits(s, 11, 2), second = _digits(s, 17, 2);
  var minute = _digits(s, 14, 2);
  if (year < 0 || month < 0 || day < 0 || hour < 0 || minute < 0 || second < 0) return null;
  var i = 19, fraction = 0;
  if (i < n && s.codeUnitAt(i) == _dot) {
    // Like DateTime.parse: the first six digits count, the rest are dropped.
    var count = 0;
    for (i++; i < n; i++) {
      final d = s.codeUnitAt(i) ^ 0x30;
      if (d > 9) break;
      if (count < 6) fraction = fraction * 10 + d;
      count++;
    }
    if (count == 0) return null;
    for (; count < 6; count++) {
      fraction *= 10;
    }
  }
  final ms = fraction ~/ 1000, us = fraction % 1000;
  if (i == n) return DateTime(year, month, day, hour, minute, second, ms, us).microsecondsSinceEpoch;
  final c = s.codeUnitAt(i);
  if (c == _z) {
    if (i + 1 != n) return null;
  } else if ((c == _plus || c == _dash) && i + 6 == n && s.codeUnitAt(i + 3) == _colon) {
    final h = _digits(s, i + 1, 2), m = _digits(s, i + 4, 2);
    if (h < 0 || m < 0) return null;
    minute -= (c == _plus ? 1 : -1) * (60 * h + m);
  } else {
    return null;
  }
  return DateTime.utc(year, month, day, hour, minute, second, ms, us).microsecondsSinceEpoch;
}
