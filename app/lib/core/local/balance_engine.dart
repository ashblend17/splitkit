/// Pure balance maths: a Dart port of api/app/modules/balances/engine.py and
/// api/app/modules/settlements/planner.py. Both pass shared/balance_vectors.json. No I/O.
///
/// A [Flow] means "debtor owes creditor amount" (minor units). An expense produces one flow per
/// participant other than the payer. A settlement from A to B produces "B owes A", which
/// cancels A's debt to B.
library;

class Flow {
  const Flow(this.debtor, this.creditor, this.amount);

  final String debtor;
  final String creditor;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is Flow && other.debtor == debtor && other.creditor == creditor && other.amount == amount;

  @override
  int get hashCode => Object.hash(debtor, creditor, amount);

  @override
  String toString() => 'Flow($debtor owes $creditor $amount)';
}

List<Flow> expenseFlows(String payer, Iterable<(String, int)> shares) => [
  for (final (user, share) in shares)
    if (user != payer && share != 0) Flow(user, payer, share),
];

Flow settlementFlow(String fromUser, String toUser, int amount) => Flow(toUser, fromUser, amount);

/// Net with each other person. Positive: they owe [me]. Negative: [me] owes them.
Map<String, int> pairwise(String me, Iterable<Flow> flows) {
  final net = <String, int>{};
  for (final f in flows) {
    if (f.creditor == me) {
      net[f.debtor] = (net[f.debtor] ?? 0) + f.amount;
    } else if (f.debtor == me) {
      net[f.creditor] = (net[f.creditor] ?? 0) - f.amount;
    }
  }
  return net;
}

/// Each person's overall position. Positive: owed money overall. Sums to zero.
Map<String, int> positions(Iterable<Flow> flows) {
  final net = <String, int>{};
  for (final f in flows) {
    net[f.creditor] = (net[f.creditor] ?? 0) + f.amount;
    net[f.debtor] = (net[f.debtor] ?? 0) - f.amount;
  }
  return net;
}

/// Fewest-ish payments that settle everyone: repeatedly pay the largest creditor from the
/// largest debtor. Ties are broken by id, as in Python. Flows mean "debtor should pay creditor".
List<Flow> simplify(Map<String, int> nets) {
  if (nets.values.fold(0, (a, b) => a + b) != 0) throw ArgumentError('positions must sum to zero');
  var debtors = [for (final e in nets.entries) if (e.value < 0) _Party(e.key, -e.value)];
  var creditors = [for (final e in nets.entries) if (e.value > 0) _Party(e.key, e.value)];
  final payments = <Flow>[];
  while (debtors.isNotEmpty && creditors.isNotEmpty) {
    debtors.sort(_Party.compare);
    creditors.sort(_Party.compare);
    final d = debtors.first, c = creditors.first;
    final amount = d.amount < c.amount ? d.amount : c.amount;
    payments.add(Flow(d.id, c.id, amount));
    d.amount -= amount;
    c.amount -= amount;
    debtors = debtors.where((x) => x.amount != 0).toList();
    creditors = creditors.where((x) => x.amount != 0).toList();
  }
  return payments;
}

class _Party {
  _Party(this.id, this.amount);
  final String id;
  int amount;

  /// Largest first, then by id. Python compares str(person) by code point, as does compareTo.
  static int compare(_Party a, _Party b) {
    final byAmount = b.amount.compareTo(a.amount);
    return byAmount != 0 ? byAmount : a.id.compareTo(b.id);
  }
}

// ---- settle up with a friend across groups (planner.py) ----

class GroupBalance {
  const GroupBalance(this.groupId, this.netMinor);
  final String groupId;

  /// Positive: the friend owes you in this group. Negative: you owe them.
  final int netMinor;
}

class PlannedPayment {
  const PlannedPayment(this.groupId, this.friendPays, this.amountMinor);
  final String groupId;
  final bool friendPays;
  final int amountMinor;
}

class SettleUpException implements Exception {
  const SettleUpException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One settlement per group. With no amount (or the full net) every group with a balance ends
/// at zero; a part payment pays down only the groups owed in its direction, oldest first.
/// [balances] must be in paying-down order.
List<PlannedPayment> planSettleUp(List<GroupBalance> balances, [int? amountMinor]) {
  final owing = balances.where((b) => b.netMinor != 0).toList();
  if (owing.isEmpty) throw const SettleUpException("You're already all square");
  final total = owing.fold(0, (a, b) => a + b.netMinor);

  if (amountMinor == null || (total != 0 && amountMinor == total.abs())) {
    return [for (final b in owing) PlannedPayment(b.groupId, b.netMinor > 0, b.netMinor.abs())];
  }
  if (total == 0) throw const SettleUpException('Your balances cancel out; settle the full amount to clear them');
  if (amountMinor <= 0) throw const SettleUpException('Enter an amount above zero');
  if (amountMinor > total.abs()) throw const SettleUpException("That's more than the balance between you");

  final friendPays = total > 0;
  final plan = <PlannedPayment>[];
  var remaining = amountMinor;
  for (final b in owing) {
    if ((b.netMinor > 0) != friendPays || remaining == 0) continue;
    final pay = remaining < b.netMinor.abs() ? remaining : b.netMinor.abs();
    plan.add(PlannedPayment(b.groupId, friendPays, pay));
    remaining -= pay;
  }
  return plan;
}
