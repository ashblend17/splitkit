import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../settlements/settlement_sheet.dart';
import 'settle_plan.dart';

/// A group's Balances tab, under its header and tabs (GroupDetailPage): the fewest payments that
/// settle everyone, yours first, then the one-to-one balances. Your own total is in the header.
class GroupBalancesTab extends ConsumerWidget {
  const GroupBalancesTab({super.key, required this.group});
  final GroupOut group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(groupBalancesProvider(group.id));
    return AsyncBody(
      value: balances,
      onRetry: () => ref.invalidate(groupBalancesProvider(group.id)),
      builder: (b) => _Body(group: group, balances: b),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.group, required this.balances});
  final GroupOut group;
  final GroupBalancesOut balances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final b = balances;
    final plan = SettlePlan(b, me.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Overline('Fewest payments'),
        const SizedBox(height: 4),
        Text(
          b.suggested.isEmpty
              ? 'Everyone in ${group.name} is square.'
              : 'The fewest payments that settle everyone in the group.',
          style: SkText.body(12, 400, color: SkColors.ink2),
        ),
        if (b.suggested.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final p in plan.mine) ...[_yours(context, me, plan, p), const SizedBox(height: 8)],
          if (plan.others.isNotEmpty) _theirs(context, plan),
        ],
        if (b.people.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Overline('One-to-one balances'),
          const SizedBox(height: 4),
          Text(
            'What one of you spent for the other, less payments between you two.',
            style: SkText.body(12, 400, color: SkColors.ink2),
          ),
          const SizedBox(height: 8),
          _oneToOne(context, me),
        ],
      ],
    );
  }

  /// One of your payments in the plan: "Omar · Pays you ₹3,160.52" with a button.
  Widget _yours(BuildContext context, UserOut me, SettlePlan plan, SuggestedPayment p) {
    final youPay = p.fromUser.id == me.id;
    final other = youPay ? p.toUser : p.fromUser;
    final c = balances.currency;
    void pay() => showGroupPaymentSheet(context, plan.target(group, p));
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        color: SkColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SkColors.line),
      ),
      child: Row(
        children: [
          Avatar(personOf(other), size: 40, fontSize: 13),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(firstName(other.name), style: SkText.body(15, 700)),
                const SizedBox(height: 1),
                Text(
                  youPay ? 'You pay ${money(p.amountMinor, c)}' : 'Pays you ${money(p.amountMinor, c)}',
                  style: SkText.body(14, 600, color: youPay ? SkColors.oweInk : SkColors.owedInk),
                ),
              ],
            ),
          ),
          if (youPay)
            SkButton('Settle', variant: SkButtonVariant.strong, size: SkButtonSize.small, onPressed: pay)
          else
            SkButton('Record payment', variant: SkButtonVariant.secondary, size: SkButtonSize.small, onPressed: pay),
        ],
      ),
    );
  }

  /// The rest of the plan, between other people: "Nihit pays Vagish ₹1,519.28".
  Widget _theirs(BuildContext context, SettlePlan plan) => SkCard(
    radius: 14,
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final (i, p) in plan.others.indexed)
          InkWell(
            onTap: () => showGroupPaymentSheet(context, plan.target(group, p)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: i == plan.others.length - 1 ? null : Border(bottom: BorderSide(color: SkColors.line)),
              ),
              child: Row(
                children: [
                  Text(firstName(p.fromUser.name), style: SkText.body(14, 700)),
                  const SizedBox(width: 8),
                  Text('pays', style: SkText.body(14, 400, color: SkColors.ink2)),
                  const SizedBox(width: 8),
                  Text(firstName(p.toUser.name), style: SkText.body(14, 700)),
                  const Spacer(),
                  Text(money(p.amountMinor, balances.currency), style: SkText.display(16, 700)),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  /// A small table of the one-to-one balances. A row records a payment for just that pair.
  Widget _oneToOne(BuildContext context, UserOut me) {
    final meBrief = UserBrief(id: me.id, name: me.name, avatarUrl: me.avatarUrl);
    final people = balances.people;
    return SkCard(
      radius: 14,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, p) in people.indexed)
            InkWell(
              onTap: p.netMinor == 0
                  ? null
                  : () => showGroupPaymentSheet(
                      context,
                      GroupPaymentTarget(
                        group: group,
                        members: people,
                        from: p.netMinor < 0 ? meBrief : p.user,
                        to: p.netMinor < 0 ? p.user : meBrief,
                        balanceMinor: p.netMinor.abs(),
                      ),
                    ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: i == people.length - 1 ? null : Border(bottom: BorderSide(color: SkColors.line)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(firstName(p.user.name), style: SkText.body(13, 600))),
                    Text(
                      personRowState(p.netMinor, balances.currency),
                      style: SkText.body(13, 600, color: textColorFor(p.netMinor)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
