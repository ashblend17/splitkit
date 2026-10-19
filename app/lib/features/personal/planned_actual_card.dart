import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/copy/copy.dart';
import '../../core/finance/allocation_providers.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/integrations.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import '../goals/plans.dart';
import '../goals/rule_editor_sheet.dart';

/// Overview's planned against actual, for [month] (the month the cash flow card shows): what your
/// allocation rules planned from that month's income (outlined) against what has been set aside
/// for it so far (solid), then each goal or account it went to. With no rules, an offer to set
/// one up; with rules but no plans that month, says when plans appear. Nothing while
/// Features.allocationRules is off.
class PlannedActualCard extends ConsumerWidget {
  const PlannedActualCard({super.key, required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(featuresProvider);
    if (!features.allocationRules) return const SizedBox.shrink();
    final value = ref.watch(plannedVsActualProvider(month));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(header: true, child: Text('Planned from income', style: SkText.section)),
              ),
              if (features.goals && value.value?.hasRules == true)
                InkWell(
                  onTap: () => context.go('/personal/goals/rules'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Rules', style: SkText.body(14, 700, color: SkColors.brandInk)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AsyncBody(
            value: value,
            onRetry: () => ref.invalidate(plannedVsActualProvider(month)),
            skeletonRows: 1,
            builder: (pva) => !pva.hasRules
                ? _setUp(context)
                : pva.isEmpty
                ? SkCard(
                    key: const Key('planned-none'),
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Plans appear when income comes in.',
                      style: SkText.body(13, 400, color: SkColors.ink2),
                    ),
                  )
                : _plans(ref, pva),
          ),
        ],
      ),
    );
  }

  /// No rules yet: an offer to set one.
  Widget _setUp(BuildContext context) => SkCard(
    key: const Key('planned-setup'),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Set a savings % of each income', style: SkText.body(15, 700)),
        const SizedBox(height: 4),
        Text(
          'A rule plans part of each income for a goal or an account, and this shows what you set aside.',
          style: SkText.body(13, 400, color: SkColors.ink2),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SkButton(
            'Set up',
            size: SkButtonSize.small,
            variant: SkButtonVariant.secondary,
            onPressed: () => showRuleEditor(context),
          ),
        ),
      ],
    ),
  );

  Widget _plans(WidgetRef ref, PlannedVsActual pva) {
    final c = ref.watch(meProvider).currency;
    final finance = ref.watch(financeEngineProvider).value;
    double share(int part, int whole) => whole <= 0 ? 0 : part / whole;
    return SkCard(
      key: const Key('planned-actual'),
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${money(pva.actualMinor, c)} of ${money(pva.plannedMinor, c)} set aside',
            style: SkText.display(22, 700),
          ),
          const SizedBox(height: 4),
          Text(
            "So far, for what your rules planned from ${DateFormat('MMMM').format(month)}'s income.",
            style: SkText.body(13, 400, color: SkColors.ink2),
          ),
          const SizedBox(height: 12),
          ActualPlannedBar(
            actual: share(pva.actualMinor, pva.plannedMinor),
            planned: 1,
            actualLabel: money(pva.actualMinor, c),
            plannedLabel: money(pva.plannedMinor - pva.actualMinor, c),
          ),
          for (final row in pva.rows) ...[
            const SizedBox(height: 14),
            Semantics(
              container: true,
              label:
                  '${destinationName(finance, goalId: row.goalId, accountId: row.accountId)}: '
                  '${money(row.actualMinor, c)} of ${money(row.plannedMinor, c)}',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            destinationName(finance, goalId: row.goalId, accountId: row.accountId),
                            style: SkText.body(13, 600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${money(row.actualMinor, c)} of ${money(row.plannedMinor, c)}',
                          style: SkText.body(13, 400, color: SkColors.ink2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ActualPlannedBar(actual: share(row.actualMinor, row.plannedMinor), planned: 1, height: 8),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
