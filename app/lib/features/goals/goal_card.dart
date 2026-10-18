import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/copy/copy.dart';
import '../../core/copy/finance_copy.dart';
import '../../core/finance/finance.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';

/// The colour of a goal's state chip.
StatusTone goalStateTone(GoalState s) => switch (s) {
  GoalState.onTrack => StatusTone.personal,
  GoalState.behind => StatusTone.pending,
  GoalState.overdue => StatusTone.youOwe,
  GoalState.reached || GoalState.completed => StatusTone.settledShare,
  GoalState.noDate || GoalState.paused || GoalState.archived => StatusTone.paid,
};

/// One goal in a list (the Goals tab, Overview's top goals): its name and state, what's saved as
/// a bar, "₹17,000 of ₹60,000 · 28%" and its timeline ("₹4,777.78/month to May 2027"). A tap
/// opens it (/personal/goals/:goalId).
class GoalCard extends StatelessWidget {
  const GoalCard(this.progress, {super.key, this.compact = false});

  final GoalProgress progress;

  /// Overview's card: no border of its own, tighter.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final timeline = goalTimeline(p);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(p.goal.name, style: SkText.body(15, 700), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            StatusChip(goalStateLabel(p.state), tone: goalStateTone(p.state)),
          ],
        ),
        const SizedBox(height: 10),
        ActualPlannedBar(actual: p.barFraction, actualLabel: money(p.progressMinor, p.goal.currency)),
        const SizedBox(height: 8),
        Text(goalAmountLine(p), style: SkText.body(13, 600)),
        if (timeline != null) ...[
          const SizedBox(height: 2),
          Text(timeline, style: SkText.body(13, 400, color: p.overdueDays != null ? SkColors.owe : SkColors.ink2)),
        ],
        if (p.issue case final issue?) ...[
          const SizedBox(height: 4),
          Text(goalIssueLabel(issue), style: SkText.body(12, 400, color: SkColors.owe)),
        ],
      ],
    );
    void open() => context.go('/personal/goals/${p.goal.id}');
    if (compact) {
      return Semantics(
        button: true,
        child: InkWell(
          key: ValueKey('goal:${p.goal.id}'),
          onTap: open,
          borderRadius: BorderRadius.circular(12),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: content),
        ),
      );
    }
    return SkCard(key: ValueKey('goal:${p.goal.id}'), radius: 18, onTap: open, child: content);
  }
}
