import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/copy/copy.dart';
import '../../core/copy/finance_copy.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/goal_providers.dart';
import '../../core/finance/holding_providers.dart';
import '../../core/local/writes.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import 'goal_sheet.dart';

/// "Reconcile": goal [p] tracked another way from now on. Shows its progress now next to what it
/// will be: switching to an account's balance picks the account and shows its balance; by hand
/// starts from today's progress; to contributions offers to record a starting amount, so the
/// progress stays where it was. Blocked, with a link to the rules, while an allocation rule sends
/// money to a goal that counts contributions. Resolves true once the switch is queued.
Future<bool> showModeSwitchDialog(BuildContext context, GoalProgress p) async =>
    await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => Center(
        child: Material(type: MaterialType.transparency, child: _ModeSwitch(p)),
      ),
    ) ??
    false;

class _ModeSwitch extends ConsumerStatefulWidget {
  const _ModeSwitch(this.p);
  final GoalProgress p;

  @override
  ConsumerState<_ModeSwitch> createState() => _ModeSwitchState();
}

class _ModeSwitchState extends ConsumerState<_ModeSwitch> {
  GoalProgress get p => widget.p;
  late GoalMode _to = GoalMode.values.firstWhere((m) => m != p.goal.mode);
  String? _accountId;
  late final _manual = TextEditingController(text: amountFieldText(math.max(0, p.progressMinor), p.goal.currency));
  bool _starting = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _manual.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = p.goal.currency;
    final guards = ref.watch(goalGuardsProvider(p.goal.id)).value;
    final kept = [
      for (final c in ref.watch(goalContributionsProvider(p.goal.id)).value ?? const <ContributionView>[])
        c.contribution.amountMinor,
    ].fold(0, (a, b) => a + b);
    final accounts = ref.watch(followableAccountsProvider(p.goal.id)).value ?? const <FinAccount>[];
    final values = {for (final v in ref.watch(accountValuesProvider).value ?? const <AccountValue>[]) v.account.id: v};
    final blocked = guards != null && !guards.canArchiveOrSwitch && p.goal.mode == GoalMode.contribution;
    final start = math.max(0, p.progressMinor - kept);
    final manual = typedAmount(_manual, currency);
    final after = switch (_to) {
      GoalMode.contribution => kept + (_starting ? start : 0),
      GoalMode.linkedBalance => values[_accountId]?.valueMinor,
      GoalMode.manual => manual,
    };
    final canSwitch = !_busy && !blocked && after != null;
    return Semantics(
      container: true,
      label: 'Track ${p.goal.name} another way',
      child: Container(
        width: 400,
        margin: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        decoration: BoxDecoration(color: SkColors.surface, borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Track ${p.goal.name} another way', style: SkText.display(20, 700)),
              const SizedBox(height: 6),
              Text('Now: ${goalModeLabel(p.goal.mode)}', style: SkText.body(13, 400, color: SkColors.ink2)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in GoalMode.values)
                    if (m != p.goal.mode)
                      SelectableChip(
                        label: goalModeLabel(m),
                        selected: m == _to,
                        accent: ChipAccent.personal,
                        onTap: () => setState(() => _to = m),
                      ),
                ],
              ),
              const SizedBox(height: 14),
              if (blocked) ...[
                Text(
                  'An allocation rule sends money to this goal, so it keeps counting contributions. Change or '
                  'delete the rule first.',
                  style: SkText.body(13, 400, color: SkColors.owe),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SkButton(
                    'See rules',
                    variant: SkButtonVariant.ghost,
                    size: SkButtonSize.small,
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop(false);
                      router.go('/personal/goals/rules');
                    },
                  ),
                ),
              ] else
                ..._fields(currency, accounts, values, kept, start),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _figure('Now', money(p.progressMinor, currency))),
                  const SizedBox(width: 8),
                  Expanded(child: _figure('After', after == null ? '—' : money(after, currency))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SkButton(
                      'Cancel',
                      variant: SkButtonVariant.secondary,
                      expand: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SkButton(
                      _busy ? 'Saving…' : 'Switch',
                      variant: SkButtonVariant.strong,
                      expand: true,
                      onPressed: canSwitch ? () => _switch(start, manual) : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fields(
    String currency,
    List<FinAccount> accounts,
    Map<String, AccountValue> values,
    int kept,
    int start,
  ) => switch (_to) {
    GoalMode.linkedBalance => [
      fieldLabel('Account it follows'),
      if (accounts.isEmpty)
        Text('No account to follow yet.', style: SkText.body(13, 400, color: SkColors.ink2))
      else
        accountChips(accounts, selected: _accountId, onPick: (id) => setState(() => _accountId = id)),
      if (values[_accountId] case final v?) fieldHint('Balance ${money(v.valueMinor, v.account.currency)}'),
    ],
    GoalMode.manual => [
      amountField('Saved so far', _manual, currency, key: const Key('switch-manual')),
      fieldHint('Starts from its progress today; update it whenever you like.'),
    ],
    GoalMode.contribution => [
      if (kept > 0)
        Text(
          'Its ${money(kept, currency)} of contributions count again.',
          style: SkText.body(13, 400, color: SkColors.ink2),
        ),
      if (start > 0)
        Semantics(
          checked: _starting,
          child: InkWell(
            onTap: () => setState(() => _starting = !_starting),
            child: Row(
              children: [
                Checkbox(
                  value: _starting,
                  activeColor: SkColors.personal,
                  onChanged: (v) => setState(() => _starting = v ?? false),
                ),
                Expanded(
                  child: Text('Record a starting amount of ${money(start, currency)}', style: SkText.body(14, 600)),
                ),
              ],
            ),
          ),
        ),
    ],
  };

  Widget _figure(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: SkColors.personalSoft, borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: SkText.body(12, 600, color: SkColors.personalInk)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1, style: SkText.display(18, 700, color: SkColors.personalInk)),
        ),
      ],
    ),
  );

  Future<void> _switch(int start, int? manual) async {
    setState(() => _busy = true);
    final to = _to;
    final ok = await runGoalWrite(
      context,
      ref,
      (w) => w.switchGoalMode(
        p.goal.id,
        to,
        linkedAccountId: to == GoalMode.linkedBalance ? _accountId : null,
        manualProgressMinor: to == GoalMode.manual ? manual : null,
        startingContributionMinor: to == GoalMode.contribution && _starting && start > 0 ? start : null,
      ),
      done: switch (to) {
        GoalMode.contribution => '${p.goal.name} now counts contributions',
        GoalMode.linkedBalance => "${p.goal.name} now follows an account's balance",
        GoalMode.manual => '${p.goal.name} is now tracked by hand',
      },
    );
    if (!ok && mounted) setState(() => _busy = false);
  }
}
