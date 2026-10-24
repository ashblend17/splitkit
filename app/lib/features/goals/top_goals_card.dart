import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/finance/finance.dart';
import '../../core/finance/goal_providers.dart';
import '../../core/integrations.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'goal_card.dart';
import 'goal_editor_sheet.dart';

/// Overview's goals: the first three active ones, each opening its page, and All goals
/// (/personal/goals). With none active, an offer to set one. Nothing while Features.goals is off.
class TopGoalsCard extends ConsumerWidget {
  const TopGoalsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featuresProvider).goals) return const SizedBox.shrink();
    // goalsProvider rather than topGoalsProvider: that one watches goalsProvider's future, and
    // resuming it under a page that was covered (Back from Add split) rebuilds it mid-frame.
    final top = ref
        .watch(goalsProvider)
        .whenData(
          (goals) => [
            for (final g in goals)
              if (g.goal.status == GoalStatus.active) g,
          ].take(3).toList(),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(header: true, child: Text('Goals', style: SkText.section)),
              ),
              InkWell(
                onTap: () => context.go('/personal/goals'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('All goals', style: SkText.body(14, 700, color: SkColors.brandInk)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AsyncBody(
            value: top,
            onRetry: () => ref.invalidate(goalsProvider),
            skeletonRows: 1,
            builder: (goals) => goals.isEmpty
                ? SkCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Set a goal', style: SkText.body(15, 700)),
                        const SizedBox(height: 4),
                        Text(
                          'A trip, an emergency fund, a gadget: see how close you are and what to put aside.',
                          style: SkText.body(13, 400, color: SkColors.ink2),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SkButton(
                            'New goal',
                            icon: 'plus',
                            size: SkButtonSize.small,
                            variant: SkButtonVariant.secondary,
                            onPressed: () => showGoalEditor(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : SkCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, g) in goals.indexed) ...[
                          if (i > 0) Divider(height: 1, color: SkColors.line),
                          GoalCard(g, compact: true),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
