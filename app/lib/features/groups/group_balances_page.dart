import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../settlements/settlement_sheet.dart';
import 'settle_plan.dart';

class GroupBalancesPage extends ConsumerWidget {
  const GroupBalancesPage({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupProvider(groupId));
    final balances = ref.watch(groupBalancesProvider(groupId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: SkColors.brand,
          onRefresh: () async {
            refreshLedger(ref.invalidate);
            await ref.read(groupBalancesProvider(groupId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          Transform.translate(
                            offset: const Offset(-8, 0),
                            child: HeaderIconButton(
                              glyph: 'back',
                              label: 'Back to ${group.value?.name ?? 'group'}',
                              onPressed: () => context.go('/groups/$groupId'),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(header: true, child: Text('Balances', style: SkText.display(20, 700))),
                                if (group.hasValue)
                                  Text(
                                    '${group.value!.name} · ${group.value!.members.length} members',
                                    style: SkText.body(12, 400, color: SkColors.ink2),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AsyncBody(
                      value: balances,
                      onRetry: () => ref.invalidate(groupBalancesProvider(groupId)),
                      builder: (b) =>
                          group.hasValue ? _Body(group: group.value!, balances: b) : const LoadingSkeleton(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    final c = b.currency;
    final plan = SettlePlan(b, me.id);
    final (bg, ink, headline) = b.netMinor > 0
        ? (SkColors.owedSoft, SkColors.owedInk, 'In this group, overall you are owed')
        : b.netMinor < 0
        ? (SkColors.oweSoft, SkColors.oweInk, 'In this group, overall you owe')
        : (SkColors.settledSoft, SkColors.ink2, "In this group, you're all square");
    final n = plan.mine.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: SkText.body(14, 600, color: ink)),
                const SizedBox(height: 4),
                Text(
                  money(b.netMinor.abs(), c),
                  style: SkText.display(40, 800, height: 1.05, color: textColorFor(b.netMinor)),
                ),
                const SizedBox(height: 4),
                Text(
                  n == 0
                      ? 'Nothing for you to pay or get'
                      : n == 1
                      ? '1 payment settles you up'
                      : '$n payments settle you up',
                  style: SkText.body(13, 400, color: ink),
                ),
              ],
            ),
          ),
        ),
        if (b.suggested.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Overline('Fewest payments'),
          const SizedBox(height: 4),
          Text(
            'The fewest payments that settle everyone in the group.',
            style: SkText.body(12, 400, color: SkColors.ink2),
          ),
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

  /// One of your payments in the plan: "Abdul · Pays you ₹3,160.52" with a button.
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
