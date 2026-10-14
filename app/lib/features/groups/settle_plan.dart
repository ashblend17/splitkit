import '../../core/api/api.dart';
import '../settlements/settlement_sheet.dart';

/// Settling a group by its fewest payments (`suggested`), the default way to settle up. The plan
/// routes everyone's overall position, so in it you either pay or get paid, never both. The
/// one-to-one balances (`people`) are shown as well, but nothing settles by them by default.
class SettlePlan {
  SettlePlan(this.balances, String meId)
    : mine = [...balances.suggested.where((p) => p.fromUser.id == meId || p.toUser.id == meId)]
        ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor)),
      others = [...balances.suggested.where((p) => p.fromUser.id != meId && p.toUser.id != meId)],
      _meId = meId;

  final GroupBalancesOut balances;
  final String _meId;

  /// Your payments in the plan, largest first.
  final List<SuggestedPayment> mine;

  /// Everyone else's.
  final List<SuggestedPayment> others;

  int get youPayMinor => _sum(mine.where((p) => p.fromUser.id == _meId));
  int get youGetMinor => _sum(mine.where((p) => p.toUser.id == _meId));

  bool isMine(SuggestedPayment p) => p.fromUser.id == _meId || p.toUser.id == _meId;

  /// The payment sheet for one payment of the plan. For yours, the other side can be switched
  /// to anyone in the group, with what the plan has between you (+ they pay you).
  GroupPaymentTarget target(GroupOut group, SuggestedPayment p) => GroupPaymentTarget(
    group: group,
    from: p.fromUser,
    to: p.toUser,
    balanceMinor: p.amountMinor,
    members: isMine(p)
        ? [for (final person in balances.people) PersonBalance(user: person.user, netMinor: _between(person.user.id))]
        : const [],
  );

  int _between(String userId) {
    var net = 0;
    for (final p in mine) {
      if (p.fromUser.id == userId) net += p.amountMinor;
      if (p.toUser.id == userId) net -= p.amountMinor;
    }
    return net;
  }

  static int _sum(Iterable<SuggestedPayment> ps) => ps.fold(0, (s, p) => s + p.amountMinor);
}
