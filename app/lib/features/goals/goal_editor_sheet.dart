import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/copy/copy.dart';
import '../../core/copy/finance_copy.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/goal_providers.dart';
import '../../core/finance/holding_providers.dart';
import '../../core/local/personal_index.dart' show localDay;
import '../../core/local/writes.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import 'goal_sheet.dart';
import 'mode_switch_dialog.dart';

/// A new goal, or goal [existing] to edit: its name, target, an optional date (2000 to 2100), how
/// its progress is tracked (contributions, an account's balance, or by hand), and an optional
/// monthly return for an estimate. An existing goal changes how it's tracked through the mode
/// switch ([showModeSwitchDialog]). Resolves to the new goal's id when one was added.
Future<String?> showGoalEditor(BuildContext context, {GoalProgress? existing}) async {
  final result = await showGoalSheet<String>(context, _GoalEditor(existing: existing));
  if (result != _switchMode) return result;
  if (context.mounted) await showModeSwitchDialog(context, existing!);
  return null;
}

/// What the editor closes with for "Change" (how the goal is tracked).
const _switchMode = '/switch-mode';

class _GoalEditor extends ConsumerStatefulWidget {
  const _GoalEditor({this.existing});
  final GoalProgress? existing;

  @override
  ConsumerState<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<_GoalEditor> {
  FinGoal? get _goal => widget.existing?.goal;
  late final _name = TextEditingController(text: _goal?.name ?? '');
  late final _target = TextEditingController(text: _goal == null ? '' : amountFieldText(_goal!.targetMinor, _currency));
  late final _manual = TextEditingController(
    text: _goal?.manualProgressMinor == null ? '' : amountFieldText(_goal!.manualProgressMinor!, _currency),
  );
  late final _return = TextEditingController(
    text: _goal?.expectedReturnBp == null ? '' : returnPercentLabel(_goal!.expectedReturnBp!).replaceAll('%', ''),
  );
  late DateTime? _date = _goal?.targetDay == null ? null : localDay(_goal!.targetDay!);
  late GoalMode _mode = _goal?.mode ?? GoalMode.contribution;
  late String? _accountId = _goal?.linkedAccountId;
  bool _busy = false;

  String get _currency => _goal?.currency ?? ref.read(meProvider).currency;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _target, _manual, _return]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _target, _manual, _return]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The monthly return typed, in basis points ("0.8" is 80); null when empty; -1 when it isn't
  /// a percentage.
  int? get _returnBp {
    final t = _return.text.trim().replaceAll('%', '');
    if (t.isEmpty) return null;
    final m = RegExp(r'^(\d{1,3})(?:\.(\d{0,2}))?$').firstMatch(t);
    if (m == null) return -1;
    final bp = int.parse(m.group(1)!) * 100 + int.parse((m.group(2) ?? '').padRight(2, '0'));
    return bp > 10000 ? -1 : bp;
  }

  @override
  Widget build(BuildContext context) {
    final currency = _currency;
    final target = typedAmount(_target, currency);
    final manual = typedAmount(_manual, currency);
    final bp = _returnBp;
    final accounts = ref.watch(followableAccountsProvider(_goal?.id)).value ?? const <FinAccount>[];
    final values = {for (final v in ref.watch(accountValuesProvider).value ?? const <AccountValue>[]) v.account.id: v};
    final canSave =
        !_busy &&
        _name.text.trim().isNotEmpty &&
        (target ?? 0) > 0 &&
        bp != -1 &&
        switch (_mode) {
          GoalMode.contribution => true,
          GoalMode.linkedBalance => _accountId != null,
          GoalMode.manual => manual != null,
        };
    final picked = values[_accountId];
    return GoalSheetFrame(
      title: _goal == null ? 'New goal' : 'Edit goal',
      children: [
        SkTextField(
          key: const Key('goal-name'),
          label: 'Name',
          controller: _name,
          hint: 'Ladakh trip, Emergency fund…',
        ),
        const SizedBox(height: 14),
        amountField('Target', _target, currency, key: const Key('goal-target')),
        const SizedBox(height: 14),
        fieldLabel('Target date (optional)'),
        GoalDateButton(
          key: const Key('goal-date'),
          date: _date,
          first: DateTime(2000),
          last: DateTime(2100, 12, 31),
          onPicked: (d) => setState(() => _date = d),
          onClear: () => setState(() => _date = null),
        ),
        const SizedBox(height: 16),
        fieldLabel('How is progress tracked?'),
        if (_goal == null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in GoalMode.values)
                SelectableChip(
                  label: goalModeLabel(m),
                  selected: m == _mode,
                  accent: ChipAccent.personal,
                  onTap: () => setState(() => _mode = m),
                ),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: Text(goalModeLabel(_mode), style: SkText.body(15, 600))),
              SkButton(
                'Change',
                variant: SkButtonVariant.secondary,
                size: SkButtonSize.small,
                onPressed: _busy ? null : _changeMode,
              ),
            ],
          ),
        fieldHint(switch (_mode) {
          GoalMode.contribution => 'Add money to it as you save: from an account, an investment, or noted by hand.',
          GoalMode.linkedBalance => "Its progress is an account's balance, like a savings account kept for it.",
          GoalMode.manual => 'Type what is saved so far, and update it now and then.',
        }),
        if (_mode == GoalMode.linkedBalance) ...[
          const SizedBox(height: 14),
          fieldLabel('Account it follows'),
          if (accounts.isEmpty)
            Text(
              'No account to follow yet: add a bank, cash or savings account first.',
              style: SkText.body(13, 400, color: SkColors.ink2),
            )
          else
            accountChips(accounts, selected: _accountId, onPick: (id) => setState(() => _accountId = id)),
          if (picked != null) fieldHint('Balance ${money(picked.valueMinor, picked.account.currency)}'),
        ],
        if (_mode == GoalMode.manual) ...[
          const SizedBox(height: 14),
          amountField('Saved so far', _manual, currency, key: const Key('goal-manual')),
        ],
        const SizedBox(height: 16),
        fieldLabel('Estimate with returns'),
        SkTextField(
          key: const Key('goal-return'),
          label: 'Monthly return % (optional)',
          controller: _return,
          hint: '0.8',
          errorText: bp == -1 ? 'A percentage, like 0.8' : null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        fieldHint('Only an estimate of what to save each month if the money grows. Leave it empty for none.'),
        const SizedBox(height: 18),
        SkButton(
          _busy ? 'Saving…' : (_goal == null ? 'Add goal' : 'Save changes'),
          size: SkButtonSize.large,
          expand: true,
          onPressed: canSave ? () => _save(target!, manual, bp) : null,
        ),
      ],
    );
  }

  Future<void> _save(int target, int? manual, int? bp) async {
    final before = _goal;
    final draft = GoalDraft(
      name: _name.text.trim(),
      targetMinor: target,
      targetDate: _date,
      mode: _mode,
      linkedAccountId: _mode == GoalMode.linkedBalance ? _accountId : null,
      manualProgressMinor: _mode == GoalMode.manual ? manual : null,
      expectedReturnBp: bp == 0 ? null : bp,
      priority: before?.priority ?? 0,
      status: before?.status ?? GoalStatus.active,
    );
    setState(() => _busy = true);
    String? made;
    final ok = await runGoalWrite(context, ref, (w) async {
      if (before == null) {
        made = await w.createGoal(draft);
      } else {
        await w.updateGoal(before.id, draft);
      }
    }, pop: false);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(made);
    } else {
      setState(() => _busy = false);
    }
  }

  /// Closes the editor for the mode switch, which saves on its own.
  void _changeMode() => Navigator.of(context).pop(_switchMode);
}
