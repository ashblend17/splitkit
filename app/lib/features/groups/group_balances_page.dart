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
    final (bg, ink, headline) = b.netMinor > 0
        ? (SkColors.owedSoft, SkColors.owedInk, 'In this group, overall you are owed')
        : b.netMinor < 0
        ? (SkColors.oweSoft, SkColors.oweInk, 'In this group, overall you owe')
        : (SkColors.settledSoft, SkColors.ink2, "In this group, you're all square");
    final others = b.suggested.where((p) => p.fromUser.id != me.id && p.toUser.id != me.id).toList();

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
                  'You owe ${money(b.youOweMinor, c)} · You are owed ${money(b.youAreOwedMinor, c)}',
                  style: SkText.body(13, 400, color: ink),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Overline('With each person'),
        const SizedBox(height: 8),
        for (final p in b.people) ...[_row(context, me, p), const SizedBox(height: 8)],
        if (others.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Overline('Everyone else · fewest payments'),
          const SizedBox(height: 8),
          SkCard(
            radius: 14,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, p) in others.indexed)
                  InkWell(
                    onTap: () => showGroupPaymentSheet(
                      context,
                      GroupPaymentTarget(group: group, from: p.fromUser, to: p.toUser, balanceMinor: p.amountMinor),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: i == others.length - 1 ? null : const Border(bottom: BorderSide(color: SkColors.line)),
                      ),
                      child: Row(
                        children: [
                          Text(firstName(p.fromUser.name), style: SkText.body(14, 700)),
                          const SizedBox(width: 8),
                          Text('pays', style: SkText.body(14, 400, color: SkColors.ink2)),
                          const SizedBox(width: 8),
                          Text(firstName(p.toUser.name), style: SkText.body(14, 700)),
                          const Spacer(),
                          Text(money(p.amountMinor, c), style: SkText.display(16, 700)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, UserOut me, PersonBalance p) {
    final meBrief = UserBrief(id: me.id, name: me.name, avatarUrl: me.avatarUrl);
    final net = p.netMinor;
    void pay() => showGroupPaymentSheet(
      context,
      GroupPaymentTarget(
        group: group,
        members: balances.people,
        from: net < 0 ? meBrief : p.user,
        to: net < 0 ? p.user : meBrief,
        balanceMinor: net.abs(),
      ),
    );
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
          Avatar(personOf(p.user), size: 40, fontSize: 13),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(firstName(p.user.name), style: SkText.body(15, 700)),
                const SizedBox(height: 1),
                Text(personRowState(net, balances.currency), style: SkText.body(14, 600, color: textColorFor(net))),
              ],
            ),
          ),
          if (net < 0)
            SkButton('Settle', variant: SkButtonVariant.strong, size: SkButtonSize.small, onPressed: pay)
          else if (net > 0)
            SkButton('Record payment', variant: SkButtonVariant.secondary, size: SkButtonSize.small, onPressed: pay)
          else
            Row(
              children: [
                const SkIcon('check', size: 16, color: SkColors.ink2),
                const SizedBox(width: 4),
                Text('Settled', style: SkText.body(13, 700, color: SkColors.ink2)),
              ],
            ),
        ],
      ),
    );
  }
}
