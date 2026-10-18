import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/goal_providers.dart';
import '../../core/layout/layout.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'goal_card.dart';
import 'goal_editor_sheet.dart';

/// Personal → Goals (/personal/goals): what you're saving towards. Active goals first, then
/// paused ones, then "Done and archived", folded away. On a phone the floating "New goal" adds
/// one; beside the rail and sidebar, the button by the title does.
class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    final list = AsyncBody.dataOf(goals);
    final phone = SkLayout.of(context) == SkLayout.compact;
    final active = <GoalProgress>[], paused = <GoalProgress>[], done = <GoalProgress>[];
    for (final g in list ?? const <GoalProgress>[]) {
      (switch (g.goal.status) {
        GoalStatus.active => active,
        GoalStatus.paused => paused,
        GoalStatus.completed || GoalStatus.archived => done,
      }).add(g);
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: SkColors.personal,
          onRefresh: () async {
            refreshPersonal(ref.invalidate);
            await ref.read(goalsProvider.future);
          },
          child: CustomScrollView(
            // Room at the bottom for the floating "New goal".
            slivers: paddedSlivers(tabPagePadding(context, bottom: 120), [
              SliverToBoxAdapter(
                child: TabPageWidth(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(header: true, child: Text('Goals', style: SkText.title)),
                        ),
                        if (!phone && list != null && list.isNotEmpty)
                          SkButton(
                            'New goal',
                            icon: 'plus',
                            variant: SkButtonVariant.strong,
                            size: SkButtonSize.small,
                            onPressed: () => showGoalEditor(context),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (list == null)
                SliverToBoxAdapter(
                  child: TabPageWidth(
                    child: AsyncBody(
                      value: goals,
                      onRetry: () => ref.invalidate(goalsProvider),
                      builder: (_) => const SizedBox.shrink(),
                    ),
                  ),
                )
              else if (list.isEmpty)
                SliverToBoxAdapter(
                  child: TabPageWidth(
                    child: EmptyState(
                      glyph: 'target',
                      title: 'No goals yet',
                      body: 'Save towards something: a trip, an emergency fund, a gadget.',
                      actionLabel: 'New goal',
                      onAction: () => showGoalEditor(context),
                    ),
                  ),
                )
              else ...[
                ..._section('Active', active),
                ..._section('Paused', paused),
                if (done.isNotEmpty) ...[
                  SliverToBoxAdapter(child: TabPageWidth(child: _doneToggle(done.length))),
                  if (_showDone) ..._section(null, done),
                ],
              ],
            ]),
          ),
        ),
      ),
    );
  }

  /// [goals] under [title] (none for the folded section): in columns where there's room, else
  /// one long list built as it scrolls.
  List<Widget> _section(String? title, List<GoalProgress> goals) {
    if (goals.isEmpty) return const [];
    return [
      if (title != null)
        SliverToBoxAdapter(
          child: TabPageWidth(
            child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Overline(title)),
          ),
        ),
      if (isWideLayout(context))
        SliverToBoxAdapter(
          child: TabPageWidth(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: CardColumns(children: [for (final g in goals) GoalCard(g)]),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 12),
          sliver: SliverList.builder(
            itemCount: goals.length,
            itemBuilder: (_, i) => TabPageWidth(
              child: Padding(padding: const EdgeInsets.only(bottom: 10), child: GoalCard(goals[i])),
            ),
          ),
        ),
    ];
  }

  Widget _doneToggle(int count) => Semantics(
    button: true,
    expanded: _showDone,
    child: InkWell(
      onTap: () => setState(() => _showDone = !_showDone),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(child: Overline('Done and archived ($count)')),
            SkIcon(_showDone ? 'up' : 'down', size: 18, color: SkColors.ink2),
          ],
        ),
      ),
    ),
  );
}
