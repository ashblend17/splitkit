import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/copy/copy.dart';
import '../../core/copy/finance_copy.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/finance/goal_providers.dart';
import '../../core/local/personal_index.dart' show localDay;
import '../../core/local/writes.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../personal/personal_txn_sheet.dart';
import 'contribution_sheet.dart';
import 'goal_card.dart';
import 'goal_editor_sheet.dart';
import 'goal_sheet.dart';

/// One goal (/personal/goals/:goalId): its progress (the % shown, the true % when it's over, what's
/// left, the months left and what's needed each month, or that it's overdue or has no date; for a
/// goal that's behind, where it should be by now), the estimate with returns, the account it
/// follows or "Update progress", and its contributions, newest first. The menu edits, pauses or
/// resumes, completes, archives or deletes it (with Undo).
class GoalDetailPage extends ConsumerWidget {
  const GoalDetailPage({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(goalProvider(goalId));
    final p = goal.value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          // Room at the bottom for the floating "Add money".
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
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
                            label: 'Back to goals',
                            onPressed: () => context.go('/personal/goals'),
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              p?.goal.name ?? 'Goal',
                              style: SkText.display(20, 700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (p != null)
                          HeaderIconButton(
                            glyph: 'more',
                            label: 'Goal options',
                            onPressed: () => _menu(context, ref, p),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AsyncBody(
                    value: goal,
                    onRetry: () => ref.invalidate(goalProvider(goalId)),
                    builder: (p) => _GoalBody(p),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, GoalProgress p) async {
    final g = p.goal;
    final status = g.status;
    final options = <(String, String)>[
      ('edit', 'Edit'),
      if (status == GoalStatus.active) ('pause', 'Pause'),
      if (status == GoalStatus.paused) ('resume', 'Resume'),
      if (status == GoalStatus.active || status == GoalStatus.paused) ('complete', 'Mark complete'),
      if (status == GoalStatus.completed) ('reopen', 'Reopen'),
      if (status != GoalStatus.archived) ('archive', 'Archive') else ('unarchive', 'Unarchive'),
      ('delete', 'Delete'),
    ];
    final picked = await showAppBottomSheet<String>(
      context,
      title: g.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (key, label) in options)
            Builder(
              builder: (sheet) => InkWell(
                onTap: () => Navigator.of(sheet).pop(key),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: SkText.body(15, 600, color: key == 'delete' ? SkColors.owe : SkColors.ink),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    Future<void> setStatus(GoalStatus s, String done) =>
        runGoalWrite(context, ref, (w) => w.setGoalStatus(g.id, s), done: done, pop: false);
    switch (picked) {
      case 'edit':
        await showGoalEditor(context, existing: p);
      case 'pause':
        await setStatus(GoalStatus.paused, 'Paused ${g.name}');
      case 'resume':
        await setStatus(GoalStatus.active, 'Resumed ${g.name}');
      case 'complete':
        await completeGoal(context, ref, p);
      case 'reopen':
        await setStatus(GoalStatus.active, 'Reopened ${g.name}');
      case 'archive':
        await runGoalWrite(
          context,
          ref,
          (w) => w.setGoalStatus(g.id, GoalStatus.archived),
          done: 'Archived ${g.name}',
          undo: (w) => w.setGoalStatus(g.id, status),
          pop: false,
        );
      case 'unarchive':
        await setStatus(GoalStatus.active, 'Unarchived ${g.name}');
      case 'delete':
        await _delete(context, ref, g);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, FinGoal g) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete ${g.name}?',
      body: 'Its contributions go with it. The entries they were made with stay.',
      confirmLabel: 'Delete',
    );
    if (!ok || !context.mounted) return;
    final router = GoRouter.of(context);
    final done = await runGoalWrite(
      context,
      ref,
      (w) => w.deleteGoal(g.id),
      done: 'Deleted ${g.name}',
      undo: (w) => w.restoreGoal(g.id),
      pop: false,
    );
    if (done) router.go('/personal/goals');
  }
}

/// "Mark complete": confirmed, never done by the app on its own.
Future<void> completeGoal(BuildContext context, WidgetRef ref, GoalProgress p) async {
  final g = p.goal;
  final ok = await showConfirmDialog(
    context,
    title: 'Mark ${g.name} complete?',
    body: p.reached
        ? 'It reached its target. It moves to Done, and you can reopen it.'
        : "It hasn't reached its target yet. It moves to Done, and you can reopen it.",
    confirmLabel: 'Mark complete',
    destructive: false,
  );
  if (!ok || !context.mounted) return;
  await runGoalWrite(
    context,
    ref,
    (w) => w.setGoalStatus(g.id, GoalStatus.completed),
    done: 'Completed ${g.name}',
    undo: (w) => w.setGoalStatus(g.id, g.status),
    pop: false,
  );
}

class _GoalBody extends ConsumerWidget {
  const _GoalBody(this.p);
  final GoalProgress p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = p.goal;
    final history = ref.watch(goalContributionsProvider(g.id));
    final counting = g.mode == GoalMode.contribution;
    final contributions = history.value ?? const <ContributionView>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _progressCard(context, ref),
        if (g.mode == GoalMode.linkedBalance) ...[const SizedBox(height: 12), _followsCard(context, ref)],
        if (goalEstimateSentence(p) case final estimate?) ...[
          const SizedBox(height: 12),
          SkCard(
            key: const Key('goal-estimate'),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Overline('Estimate with returns'),
                const SizedBox(height: 8),
                Text(estimate, style: SkText.body(14, 600)),
                const SizedBox(height: 4),
                Text(
                  "Returns aren't certain: this is only a guide.",
                  style: SkText.body(12, 400, color: SkColors.ink2),
                ),
              ],
            ),
          ),
        ],
        if (counting || contributions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Semantics(header: true, child: Text('Contributions', style: SkText.section)),
          if (!counting)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Kept from when it counted contributions. They don't count now.",
                style: SkText.body(12, 400, color: SkColors.ink2),
              ),
            ),
          const SizedBox(height: 8),
          AsyncBody(
            value: history,
            onRetry: () => ref.invalidate(goalContributionsProvider(g.id)),
            skeletonRows: 2,
            builder: (list) => list.isEmpty
                ? Text('Nothing added yet.', style: SkText.body(13, 400, color: SkColors.ink2))
                : Column(
                    children: [
                      for (final c in list) ...[_ContributionRow(p, c), const SizedBox(height: 8)],
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  Widget _progressCard(BuildContext context, WidgetRef ref) {
    final g = p.goal, c = g.currency;
    final over = goalOverLine(p);
    final expected = goalExpectedLine(p);
    final takes = g.mode == GoalMode.contribution && g.status != GoalStatus.archived;
    Widget line(String label, String value, {Color? color}) => Semantics(
      container: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: SkText.body(13, 600, color: SkColors.ink2)),
              ),
              Text(value, style: SkText.body(13, 700, color: color ?? SkColors.ink)),
            ],
          ),
        ),
      ),
    );
    Widget note(String text, Color color) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(text, style: SkText.body(13, 600, color: color)),
    );
    return SkCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(goalModeLabel(g.mode), style: SkText.body(14, 600, color: SkColors.ink2)),
              ),
              StatusChip(goalStateLabel(p.state), tone: goalStateTone(p.state)),
            ],
          ),
          const SizedBox(height: 12),
          Text('${p.percentShown}%', style: SkText.display(44, 800, height: 1)),
          if (over != null) ...[
            const SizedBox(height: 4),
            Text(over, style: SkText.body(13, 600, color: SkColors.personalInk)),
          ],
          const SizedBox(height: 12),
          ActualPlannedBar(actual: p.barFraction, actualLabel: money(p.progressMinor, c), height: 12),
          const SizedBox(height: 8),
          Text('${money(p.progressMinor, c)} of ${money(g.targetMinor, c)}', style: SkText.body(14, 600)),
          if (!p.reached) line('Left to save', money(p.remainingMinor, c)),
          if (g.targetDay case final day?) line('Target date', goalMonthLabel(day)),
          if (p.monthsLeft case final months? when !p.reached) line('Time left', monthsLeftLabel(months)),
          if (p.requiredMonthlyMinor case final monthly?) line('Needed each month', money(monthly, c)),
          if (p.overdueDays case final days?) note(overdueLabel(days), SkColors.owe),
          if (g.targetDay == null && !p.reached) note(noDateLabel, SkColors.ink2),
          if (expected != null) note(expected, SkColors.pending),
          if (p.issue case final issue?) note(goalIssueLabel(issue), SkColors.owe),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (takes)
                SkButton(
                  'Add money',
                  icon: 'plus',
                  size: SkButtonSize.small,
                  variant: SkButtonVariant.strong,
                  onPressed: () => showAddMoney(context, p),
                ),
              if (g.mode == GoalMode.manual && g.status != GoalStatus.archived)
                SkButton(
                  'Update progress',
                  size: SkButtonSize.small,
                  variant: SkButtonVariant.strong,
                  onPressed: () => showUpdateProgressSheet(context, p),
                ),
              if (p.reached && g.status == GoalStatus.active)
                SkButton(
                  'Mark complete',
                  icon: 'check',
                  size: SkButtonSize.small,
                  variant: SkButtonVariant.secondary,
                  onPressed: () => completeGoal(context, ref, p),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Follows Emergency savings · balance ₹1,20,000", with its entries and "Move money".
  Widget _followsCard(BuildContext context, WidgetRef ref) {
    final g = p.goal;
    final id = g.linkedAccountId;
    final account = id == null ? null : ref.watch(financeEngineProvider).value?.account(id);
    final name = account?.name ?? 'an account';
    return SkCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            p.issue == null ? 'Follows $name · balance ${money(p.progressMinor, g.currency)}' : 'Follows $name',
            style: SkText.body(14, 600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (account != null && !account.deleted)
                SkButton(
                  'Move money to ${account.name}',
                  size: SkButtonSize.small,
                  variant: SkButtonVariant.strong,
                  onPressed: () => showPersonalTxnSheet(context, type: 'transfer'),
                ),
              if (account != null)
                SkButton(
                  'See entries',
                  size: SkButtonSize.small,
                  variant: SkButtonVariant.secondary,
                  onPressed: () => context.go('/personal/transactions?account_id=${account.id}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One contribution: amount, date, and the entry or note it came with. A tap opens its entry
/// (or, with none, edits it); the menu edits or deletes it.
class _ContributionRow extends ConsumerWidget {
  const _ContributionRow(this.p, this.c);
  final GoalProgress p;
  final ContributionView c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = c.contribution;
    final what = [
      if (c.entryDescription case final d? when d.isNotEmpty) d,
      ?c.accountName,
      if (k.note case final n? when n.isNotEmpty) n,
    ];
    return SkCard(
      key: ValueKey('contribution:${k.id}'),
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      onTap: () =>
          k.transactionId != null ? openContributionEntry(context, ref, c) : showEditContribution(context, p, c),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(money(k.amountMinor, k.currency), style: SkText.body(15, 700)),
                Text(
                  [dayLabel(localDay(k.day)), ...what].join(' · '),
                  style: SkText.body(12, 400, color: SkColors.ink2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          HeaderIconButton(
            glyph: 'more',
            label: 'Options for ${money(k.amountMinor, k.currency)} on ${dayLabel(localDay(k.day))}',
            onPressed: () => _menu(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final picked = await showAppBottomSheet<String>(
      context,
      title: money(c.contribution.amountMinor, c.contribution.currency),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (key, label) in [('edit', 'Edit'), ('delete', 'Delete')])
            Builder(
              builder: (sheet) => InkWell(
                onTap: () => Navigator.of(sheet).pop(key),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: SkText.body(15, 600, color: key == 'delete' ? SkColors.owe : SkColors.ink),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!context.mounted) return;
    final k = c.contribution;
    switch (picked) {
      case 'edit':
        await showEditContribution(context, p, c);
      case 'delete':
        await runGoalWrite(
          context,
          ref,
          (w) => w.deleteContribution(k.id),
          done: 'Deleted ${money(k.amountMinor, k.currency)} from ${p.goal.name}',
          undo: (w) => w.restoreContribution(k.id),
          pop: false,
        );
    }
  }
}
