import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/copy/finance_copy.dart';
import '../../core/data/providers.dart';
import '../../core/finance/allocation_providers.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/finance_providers.dart';
import '../../core/integrations.dart';
import '../../core/layout/layout.dart';
import '../../core/local/writes.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'goal_sheet.dart';
import 'plans.dart';
import 'rule_editor_sheet.dart';

/// Personal → Goals → Rules (/personal/goals/rules): your allocation rules in the API's order
/// (priority, then oldest first), each with its name or what it does ("10% of each income →
/// Ladakh trip"), which income it takes, an on/off switch, how many plans it has made, and why it
/// makes none when its account filter names a deleted account or its destination doesn't take
/// money now. Over the list, a warning when your rules set aside more than all of an income
/// (allowed, never changed). A tap edits a rule (or deletes it, with Undo). On a phone the
/// floating "Add rule" adds one; beside the rail and sidebar, the button by the title does.
class RulesPage extends ConsumerWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(allocationRulesProvider);
    final list = AsyncBody.dataOf(rules);
    final load = ref.watch(allocationLoadProvider).value;
    final phone = SkLayout.of(context) == SkLayout.compact;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          // Room at the bottom for the floating "Add rule".
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
                        // The back button and the title are each their own node: on a phone
                        // nothing else in the row keeps them from being read out as one.
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: Semantics(
                            container: true,
                            child: HeaderIconButton(
                              glyph: 'back',
                              label: 'Back to goals',
                              onPressed: () => context.go('/personal/goals'),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            container: true,
                            header: true,
                            child: Text('Rules', style: SkText.display(20, 700)),
                          ),
                        ),
                        if (!phone && list != null && list.isNotEmpty)
                          SkButton(
                            'Add rule',
                            icon: 'plus',
                            variant: SkButtonVariant.strong,
                            size: SkButtonSize.small,
                            onPressed: () => showRuleEditor(context),
                          ),
                      ],
                    ),
                  ),
                  if (list != null && list.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Each time income comes in, your rules plan part of it for a goal or an account. '
                        'Plans are never money: they count once you set the money aside.',
                        style: SkText.body(13, 400, color: SkColors.ink2),
                      ),
                    ),
                  if (load != null && load.over100 && list != null && list.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LoadWarning(load: load),
                    ),
                  AsyncBody(
                    value: rules,
                    onRetry: () => ref.invalidate(allocationRulesProvider),
                    builder: (list) => list.isEmpty
                        ? EmptyState(
                            glyph: 'target',
                            title: 'Set aside part of each income',
                            body: 'A rule plans money for a goal or an account each time income comes in.',
                            actionLabel: 'Add a rule',
                            onAction: () => showRuleEditor(context),
                          )
                        : Column(
                            children: [
                              for (final v in list) ...[_RuleCard(v), const SizedBox(height: 10)],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One rule: what it is, which income it takes, how many plans it has made and why it makes none
/// now, with its on/off switch. A tap opens the editor.
class _RuleCard extends ConsumerWidget {
  const _RuleCard(this.v);
  final RuleView v;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = v.rule;
    final finance = ref.watch(financeEngineProvider).value;
    final categories = ref.watch(allCategoriesProvider).value ?? const <CategoryOut>[];
    final title = ruleTitle(finance, r);
    final named = title != ruleLine(finance, r);
    final destination = v.destinationValid ? null : _destinationNote(finance, r);
    String? category(String id) => [
      for (final c in categories)
        if (c.id == id) c.label,
    ].firstOrNull;
    final from = switch ((r.sourceCategoryId, r.sourceAccountId)) {
      (null, null) => 'From any income',
      (final c?, null) => 'From ${category(c) ?? 'a category'}',
      (null, final a?) => 'From income into ${finance?.account(a)?.name ?? 'an account'}',
      (final c?, final a?) => 'From ${category(c) ?? 'a category'} into ${finance?.account(a)?.name ?? 'an account'}',
    };
    final muted = r.active ? SkColors.ink : SkColors.ink2;
    return SkCard(
      key: ValueKey('rule:${r.id}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      onTap: () => showRuleEditor(context, existing: r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SkText.body(15, 700, color: muted)),
                if (named) Text(ruleLine(finance, r), style: SkText.body(13, 600, color: muted)),
                const SizedBox(height: 2),
                Text(
                  [from, if (!r.active) 'Off', planCountLabel(v.planCount)].join(' · '),
                  style: SkText.body(12, 400, color: SkColors.ink2),
                ),
                if (v.sourceAccountGone)
                  _warning(
                    "The account it takes income from was deleted, so it makes no plans. Edit it to pick "
                    'another.',
                  ),
                if (destination != null) _warning(destination),
              ],
            ),
          ),
          Semantics(
            label: 'Make plans: $title',
            child: Switch(
              value: r.active,
              activeColor: SkColors.personal,
              onChanged: (on) => runGoalWrite(
                context,
                ref,
                (w) => w.setRuleActive(r.id, on),
                done: '${on ? 'Turned on' : 'Turned off'} $title',
                pop: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warning(String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(text, style: SkText.body(12, 600, color: SkColors.owe)),
  );

  /// Why rule [r]'s destination takes no money now: a goal that's paused, done, archived or
  /// counts no contributions; an account that's closed; either gone.
  static String _destinationNote(FinanceEngine? f, FinRule r) {
    if (r.goalId case final id?) {
      final g = f?.goalById(id);
      if (g == null || g.deleted) return 'Its goal is gone, so it makes no plans.';
      if (g.mode != GoalMode.contribution) return "${g.name} doesn't count contributions now, so it makes no plans.";
      return switch (g.status) {
        GoalStatus.paused => '${g.name} is paused, so it makes no plans for now.',
        GoalStatus.completed => '${g.name} is done, so it makes no plans.',
        GoalStatus.archived => '${g.name} is archived, so it makes no plans.',
        GoalStatus.active => '${g.name} takes no money now, so it makes no plans.',
      };
    }
    final a = r.accountId == null ? null : f?.account(r.accountId!);
    if (a == null || a.deleted) return 'Its account is gone, so it makes no plans.';
    return '${a.name} is closed, so it makes no plans.';
  }
}

/// The Goals tab's way to the rules (/personal/goals/rules): how many there are, or an offer to
/// set one. Nothing while Features.allocationRules is off.
class RulesCard extends ConsumerWidget {
  const RulesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featuresProvider).allocationRules) return const SizedBox.shrink();
    final rules = ref.watch(allocationRulesProvider).value ?? const <RuleView>[];
    final off = rules.where((v) => !v.rule.active).length;
    final n = rules.length;
    final text = n == 0
        ? 'Set aside part of each income for a goal or an account'
        : '$n ${n == 1 ? 'rule plans' : 'rules plan'} part of each income${off > 0 ? ' · $off off' : ''}';
    return SkCard(
      key: const Key('rules-card'),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: () => context.go('/personal/goals/rules'),
      child: Row(
        children: [
          IconTile('swap', background: SkColors.personalSoft, foreground: SkColors.personalInk, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rules', style: SkText.body(15, 700)),
                Text(text, style: SkText.body(13, 400, color: SkColors.ink2)),
              ],
            ),
          ),
          SkIcon('next', size: 18, color: SkColors.ink2),
        ],
      ),
    );
  }
}
