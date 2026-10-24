/// Refunds: which spend money coming back is for, and how much of a spend is left to refund.
library;

import '../categorise/category_rules.dart' as rules;
import 'model.dart';

/// The spend in [entries] a refund of [amountMinor] on [day] gives money back for, or null:
/// - a live spend with the same bank [reference] wins;
/// - otherwise a live spend from the same merchant ([merchantKey]: merchantKey() of the refund's
///   merchant), dated up to [windowDays] before the refund;
/// - either way, with at least [amountMinor] left to refund ([refundableMinor]).
///
/// Of several, the one on the same account ([accountId]) first, then the one of exactly
/// [amountMinor], then the newest, then by id.
FinEntry? refundTarget(
  Iterable<FinEntry> entries, {
  required int amountMinor,
  required int day,
  String? reference,
  String? merchantKey,
  String? accountId,
  int windowDays = 60,
}) {
  final from = addDays(day, -windowDays);
  final ref = reference == null || reference.isEmpty ? null : reference;
  final merchant = merchantKey == null || merchantKey.isEmpty ? null : merchantKey;
  final refunded = <String, int>{};
  final keys = <String?, String>{};
  final byReference = <FinEntry>[], byMerchant = <FinEntry>[];
  for (final e in entries) {
    if (e.deleted) continue;
    if (e.txnType == TxnType.refund) {
      if (e.refundOfId case final of?) refunded[of] = (refunded[of] ?? 0) + e.amount;
      continue;
    }
    if (e.txnType != TxnType.expense) continue;
    if (ref != null && e.reference == ref) {
      byReference.add(e);
    } else if (merchant != null &&
        e.day >= from &&
        e.day <= day &&
        (keys[e.merchant] ??= rules.merchantKey(e.merchant)) == merchant) {
      byMerchant.add(e);
    }
  }

  FinEntry? best(List<FinEntry> found) {
    FinEntry? pick;
    for (final e in found) {
      if (e.amount - (refunded[e.id] ?? 0) < amountMinor) continue;
      if (pick == null || _prefer(e, pick, amountMinor, accountId) < 0) pick = e;
    }
    return pick;
  }

  return best(byReference) ?? best(byMerchant);
}

/// Below zero when [a] is the better refund target than [b] (see [refundTarget]).
int _prefer(FinEntry a, FinEntry b, int amountMinor, String? accountId) {
  if (accountId != null) {
    final aSame = a.accountId == accountId, bSame = b.accountId == accountId;
    if (aSame != bSame) return aSame ? -1 : 1;
  }
  final aExact = a.amount == amountMinor, bExact = b.amount == amountMinor;
  if (aExact != bExact) return aExact ? -1 : 1;
  var c = b.day.compareTo(a.day);
  if (c != 0) return c;
  c = b.atMicros.compareTo(a.atMicros);
  if (c != 0) return c;
  c = b.createdMicros.compareTo(a.createdMicros);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// What's left to refund of spend [original]: its amount less its live refunds in [entries],
/// and never below zero. (The server checks each refund against the spend on its own, ISS-067.)
int refundableMinor(FinEntry original, Iterable<FinEntry> entries) {
  var left = original.amount;
  for (final e in entries) {
    if (!e.deleted && e.txnType == TxnType.refund && e.refundOfId == original.id) left -= e.amount;
  }
  return left < 0 ? 0 : left;
}
