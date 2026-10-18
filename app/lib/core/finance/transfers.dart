/// Transfers between your own accounts: finding a leg's partner, and spotting a spend and an
/// income that look like the two halves of one (ISS-046), which you can then mark as a transfer.
library;

import 'model.dart';

/// Each live transfer leg in [entries] mapped to its partner, the other live leg of its group.
/// A group without exactly two live legs (not yet fully synced) gives none.
Map<String, FinEntry> transferPartners(Iterable<FinEntry> entries) {
  final groups = <String, List<FinEntry>>{};
  for (final e in entries) {
    final group = e.transferGroupId;
    if (group != null && !e.deleted && e.txnType == TxnType.transfer) (groups[group] ??= []).add(e);
  }
  return {
    for (final legs in groups.values)
      if (legs.length == 2) ...{legs[0].id: legs[1], legs[1].id: legs[0]},
  };
}

/// A spend and an income that look like one transfer between two of your accounts.
final class TransferSuggestion {
  const TransferSuggestion({required this.outflow, required this.inflow, required this.minutesApart});

  /// The spend: the money leaving one account.
  final FinEntry outflow;

  /// The income: the same money arriving in another.
  final FinEntry inflow;

  /// How far apart the two bank messages came, in whole minutes.
  final int minutesApart;

  /// What "Not a transfer" remembers, so the pair isn't offered again.
  String get key => '${outflow.id}|${inflow.id}';
}

/// Pairs of a spend and an income in [entries] that look like one transfer: both live, read from
/// bank SMS, counted (not in [notCounted], not linked to Split) and not already a transfer leg;
/// the same amount and currency, on two different accounts you have ([accounts]), and at most
/// [window] apart. Pairs whose key is in [dismissed] are left out.
///
/// Each entry joins at most one pair, the closest in time first (ties by the spend's id, then the
/// income's). Newest pair first.
List<TransferSuggestion> transferSuggestions(
  Iterable<FinEntry> entries, {
  required Map<String, FinAccount> accounts,
  required Set<String> notCounted,
  required Set<String> dismissed,
  Duration window = const Duration(minutes: 30),
}) {
  bool candidate(FinEntry e) =>
      !e.deleted &&
      e.fromSms &&
      e.transferGroupId == null &&
      e.expenseId == null &&
      e.settlementId == null &&
      accounts.containsKey(e.accountId) &&
      !notCounted.contains(e.id);

  // Spends and incomes by amount and currency.
  final spends = <(int, String), List<FinEntry>>{}, incomes = <(int, String), List<FinEntry>>{};
  for (final e in entries) {
    final side = switch (e.txnType) {
      TxnType.expense => spends,
      TxnType.income => incomes,
      _ => null,
    };
    if (side != null && candidate(e)) (side[(e.amount, e.currency)] ??= []).add(e);
  }

  final span = window.inMicroseconds;
  final pairs = <(FinEntry, FinEntry, int)>[];
  for (final MapEntry(key: key, value: outs) in spends.entries) {
    final ins = incomes[key];
    if (ins == null) continue;
    ins.sort((a, b) => a.atMicros.compareTo(b.atMicros));
    for (final o in outs) {
      for (var i = _firstAtOrAfter(ins, o.atMicros - span); i < ins.length; i++) {
        final n = ins[i];
        if (n.atMicros > o.atMicros + span) break;
        if (n.accountId == o.accountId || dismissed.contains('${o.id}|${n.id}')) continue;
        pairs.add((o, n, (n.atMicros - o.atMicros).abs()));
      }
    }
  }
  pairs.sort((a, b) {
    var c = a.$3.compareTo(b.$3);
    if (c != 0) return c;
    c = a.$1.id.compareTo(b.$1.id);
    return c != 0 ? c : a.$2.id.compareTo(b.$2.id);
  });

  final paired = <String>{};
  final out = <TransferSuggestion>[];
  for (final (o, n, apart) in pairs) {
    if (paired.contains(o.id) || paired.contains(n.id)) continue;
    paired
      ..add(o.id)
      ..add(n.id);
    out.add(TransferSuggestion(outflow: o, inflow: n, minutesApart: apart ~/ Duration.microsecondsPerMinute));
  }
  int latest(TransferSuggestion s) => s.outflow.atMicros > s.inflow.atMicros ? s.outflow.atMicros : s.inflow.atMicros;
  return out..sort((a, b) {
    final c = latest(b).compareTo(latest(a));
    return c != 0 ? c : a.key.compareTo(b.key);
  });
}

/// The first index in [byTime] (sorted by time) at or after [micros].
int _firstAtOrAfter(List<FinEntry> byTime, int micros) {
  var lo = 0, hi = byTime.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (byTime[mid].atMicros < micros) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}
