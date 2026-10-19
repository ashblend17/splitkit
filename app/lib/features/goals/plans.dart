import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/copy/copy.dart';
import '../../core/copy/finance_copy.dart';
import '../../core/finance/allocation_providers.dart';
import '../../core/finance/finance.dart';
import '../../core/local/personal_index.dart' show localDay;
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../personal/personal_txn_sheet.dart';
import 'contribution_sheet.dart';

// Pieces the allocation screens share (the Rules page and editor, goal cards and detail, the entry
// sheet, Overview's planned against actual): names, plan states, and the "Planned, not yet saved"
// list with its "Record".

/// The goal or account a rule or plan sends money to, by name.
String destinationName(FinanceEngine? f, {String? goalId, String? accountId}) {
  if (goalId != null) return f?.goalById(goalId)?.name ?? 'a goal';
  if (accountId != null) return f?.account(accountId)?.name ?? 'an account';
  return 'nowhere';
}

/// What rule [r] does and where: "10% of each income → Ladakh trip".
String ruleLine(FinanceEngine? f, FinRule r) =>
    '${ruleAmountLabel(r)} → ${destinationName(f, goalId: r.goalId, accountId: r.accountId)}';

/// Rule [r]'s name, or else [ruleLine].
String ruleTitle(FinanceEngine? f, FinRule r) {
  if (r.name case final name? when name.trim().isNotEmpty) return name;
  return ruleLine(f, r);
}

/// The colour of a plan's state chip.
StatusTone planStatusTone(PlanStatus s) => switch (s) {
  PlanStatus.planned => StatusTone.paid,
  PlanStatus.partial => StatusTone.pending,
  PlanStatus.fulfilled => StatusTone.settledShare,
  PlanStatus.cancelled => StatusTone.youOwe,
};

/// Goal [g]'s plans still to act on: its own while it counts contributions; the followed
/// account's while it follows one (rules send that money to the account). None for a goal that's
/// done or archived, or tracked by hand.
AsyncValue<List<PlanView>> goalOutstandingPlans(WidgetRef ref, FinGoal g) {
  const none = AsyncData(<PlanView>[]);
  if (g.deleted || (g.status != GoalStatus.active && g.status != GoalStatus.paused)) return none;
  return switch ((g.mode, g.linkedAccountId)) {
    (GoalMode.contribution, _) => ref.watch(goalPlansProvider(g.id)),
    (GoalMode.linkedBalance, final String account) => ref.watch(accountPlansProvider(account)),
    _ => none,
  };
}

/// What's still to set aside for [plans], added up.
int outstandingOf(List<PlanView> plans) => plans.fold(0, (sum, v) => sum + v.remainingMinor);

/// "Record" for plan [v] of goal [goal]: the contribution sheet with what's left, or for a plan to
/// an account, the transfer sheet into it with what's left.
Future<void> recordPlan(BuildContext context, GoalProgress goal, PlanView v) async {
  if (v.plan.accountId case final account?) {
    await showPersonalTxnSheet(context, type: 'transfer', toAccountId: account, amountMinor: v.remainingMinor);
    return;
  }
  await showAddMoney(context, goal, amountMinor: v.remainingMinor);
}

/// Goal detail's "Planned, not yet saved": each outstanding plan with what's left of it, where it
/// came from, and "Record". Nothing when there are none. These amounts never count in progress.
class PlannedList extends ConsumerWidget {
  const PlannedList(this.goal, {super.key});

  final GoalProgress goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = goalOutstandingPlans(ref, goal.goal).value ?? const <PlanView>[];
    if (plans.isEmpty) return const SizedBox.shrink();
    final toAccount = goal.goal.mode == GoalMode.linkedBalance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Semantics(header: true, child: Text('Planned, not yet saved', style: SkText.section)),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            toAccount
                ? 'Your rules planned this for the account it follows. It counts once you move the money.'
                : 'Your rules planned this from your income. It counts once you add it.',
            style: SkText.body(12, 400, color: SkColors.ink2),
          ),
        ),
        for (final v in plans) ...[_PlanRow(goal, v), const SizedBox(height: 8)],
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow(this.goal, this.v);
  final GoalProgress goal;
  final PlanView v;

  @override
  Widget build(BuildContext context) {
    final p = v.plan, c = p.currency;
    final detail = [
      if (v.status == PlanStatus.partial)
        '${money(v.filledMinor, c)} of ${money(p.plannedMinor, c)} saved'
      else
        '${money(p.plannedMinor, c)} planned',
      if (v.income case final income?) 'from ${income.description}',
      if (v.incomeDay > 0) dayLabel(localDay(v.incomeDay)),
    ].join(' · ');
    return SkCard(
      key: ValueKey('plan:${p.id}'),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${money(v.remainingMinor, c)} to set aside', style: SkText.body(15, 700)),
                Text(
                  detail,
                  style: SkText.body(12, 400, color: SkColors.ink2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SkButton(
            'Record',
            size: SkButtonSize.small,
            variant: SkButtonVariant.secondary,
            onPressed: () => recordPlan(context, goal, v),
          ),
        ],
      ),
    );
  }
}
