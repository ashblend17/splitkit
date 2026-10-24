/// A holding in one of your investment accounts (finance revamp design §5.2): add one with what
/// it's worth, or open one to see its value, update it, edit it or delete it (with Undo).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/clock.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/finance/finance.dart';
import '../../core/finance/holding_providers.dart';
import '../../core/local/writes.dart';
import '../../core/money/money.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'holdings_section.dart';
import 'update_value_sheet.dart';

/// Adds a holding to investment account [accountId], or opens [existing].
Future<void> showHoldingSheet(BuildContext context, {required String accountId, FinHolding? existing}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HoldingSheet(accountId: accountId, existing: existing),
    );

class _HoldingSheet extends ConsumerStatefulWidget {
  const _HoldingSheet({required this.accountId, this.existing});

  final String accountId;
  final FinHolding? existing;

  @override
  ConsumerState<_HoldingSheet> createState() => _HoldingSheetState();
}

class _HoldingSheetState extends ConsumerState<_HoldingSheet> {
  late HoldingType _type = widget.existing?.type ?? HoldingType.mutualFund;
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  final _value = TextEditingController();
  late final _quantity = TextEditingController(text: widget.existing?.quantity ?? '');
  late final _cost = TextEditingController(text: _initialCost);
  DateTime _day = DateUtils.dateOnly(appClock.now());
  bool _busy = false;

  /// The cost basis as the field first shows it (empty for none).
  late final String _initialCost = switch (widget.existing) {
    FinHolding(costBasisMinor: final c?, :final currency) => amountFieldText(c, currency),
    _ => '',
  };

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _value, _quantity, _cost]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _value, _quantity, _cost]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = ref.watch(accountValuesProvider).value ?? const <AccountValue>[];
    final account = values.where((v) => v.account.id == widget.accountId).firstOrNull?.account;
    final view = switch (widget.existing) {
      final h? => values.expand((v) => v.holdings).where((v) => v.holding.id == h.id).firstOrNull,
      null => null,
    };
    final currency = account?.currency ?? widget.existing?.currency ?? 'INR';
    final value = parseMinor(_value.text, currency: currency);
    final cost = _cost.text.trim().isEmpty ? null : parseMinor(_cost.text, currency: currency);
    final canSave =
        !_busy &&
        _name.text.trim().isNotEmpty &&
        (_editing || value != null) &&
        (_cost.text.trim().isEmpty || cost != null);
    return HoldingSheetFrame(
      children: [
        Semantics(
          header: true,
          child: Text(
            view?.holding.name ?? widget.existing?.name ?? 'Add holding',
            style: SkText.display(22, 700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (account != null) ...[
          const SizedBox(height: 6),
          Text(
            [if (view != null) holdingTypeLabel(view.holding.type), 'In ${account.name}'].join(' · '),
            style: SkText.body(13, 400, color: SkColors.ink2),
          ),
        ],
        if (view != null) ..._summary(view),
        const SizedBox(height: 18),
        Text('Type', style: SkText.body(14, 600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in HoldingType.values)
              SelectableChip(
                label: holdingTypeLabel(t),
                selected: t == _type,
                accent: ChipAccent.personal,
                onTap: () => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SkTextField(label: 'Name', controller: _name, hint: 'Nifty 50 index fund, Tata Motors…'),
        if (!_editing) ...[
          const SizedBox(height: 14),
          SkTextField(
            label: 'Value',
            controller: _value,
            hint: '0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [AmountFormatter(currency: currency)],
          ),
          const SizedBox(height: 6),
          Text('What it was worth on the day below.', style: SkText.body(12, 400, color: SkColors.ink2)),
          const SizedBox(height: 14),
          ValueDayField(day: _day, onPicked: (d) => setState(() => _day = d)),
        ],
        const SizedBox(height: 14),
        SkTextField(
          label: 'Quantity (optional)',
          controller: _quantity,
          hint: '412.358',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 6),
        Text('Units, shares or grams.', style: SkText.body(12, 400, color: SkColors.ink2)),
        const SizedBox(height: 14),
        SkTextField(
          label: 'What you paid in all (optional)',
          controller: _cost,
          hint: '0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [AmountFormatter(currency: currency)],
        ),
        const SizedBox(height: 6),
        Text('With it, the gain shows.', style: SkText.body(12, 400, color: SkColors.ink2)),
        const SizedBox(height: 18),
        SkButton(
          _busy ? 'Saving…' : (_editing ? 'Save changes' : 'Add holding'),
          size: SkButtonSize.large,
          expand: true,
          onPressed: canSave ? () => _save(value, cost) : null,
        ),
        if (_editing) ...[
          const SizedBox(height: 8),
          SkButton(
            'Delete',
            icon: 'trash',
            variant: SkButtonVariant.danger,
            expand: true,
            onPressed: _busy ? null : () => _delete(view?.holding ?? widget.existing!),
          ),
        ],
      ],
    );
  }

  /// Its value as it stands, how old it is and its gain, with Update value.
  List<Widget> _summary(HoldingView v) {
    final gain = gainLabel(v);
    return [
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Value', style: SkText.body(13, 600, color: SkColors.ink2)),
                ),
                if (v.stale) const StatusChip('Stale', tone: StatusTone.pending, showDot: false),
              ],
            ),
            const SizedBox(height: 2),
            Text(money(v.valueMinor, v.holding.currency), style: SkText.display(30, 800, height: 1.1)),
            const SizedBox(height: 4),
            Text(valueAsOf(v), style: SkText.body(13, 400, color: SkColors.ink2)),
            if (gain != null) Text('Gain $gain', style: SkText.body(13, 600, color: textColorFor(v.gainMinor!))),
            const SizedBox(height: 12),
            SkButton(
              'Update value',
              icon: 'refresh',
              variant: SkButtonVariant.secondary,
              expand: true,
              onPressed: _busy ? null : () => showUpdateValueSheet(context, v.holding),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _save(int? value, int? cost) async {
    final writes = ref.read(writesProvider);
    final name = _name.text.trim(), quantity = _quantity.text.trim();
    final before = widget.existing;
    setState(() => _busy = true);
    try {
      if (before == null) {
        await writes.createHolding(
          accountId: widget.accountId,
          name: name,
          type: _type,
          marketMinor: value!,
          valuationDay: _day,
          quantity: quantity.isEmpty ? null : quantity,
          costBasisMinor: cost,
        );
      } else {
        // Only what changed: an emptied quantity or cost clears it.
        final costChanged = _cost.text != _initialCost;
        await writes.updateHolding(
          before.id,
          name: name == before.name ? null : name,
          type: _type == before.type ? null : _type,
          quantity: quantity == (before.quantity ?? '') ? null : quantity,
          costBasisMinor: costChanged ? cost : null,
          clearCostBasis: costChanged && cost == null,
        );
      }
      refreshPersonal(ref.invalidate);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, apiErrorMessage(e));
      }
    }
  }

  /// Deleted, with Undo; refused while an entry names it, saying so.
  Future<void> _delete(FinHolding h) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final writes = ref.read(writesProvider);
    setState(() => _busy = true);
    try {
      await writes.deleteHolding(h.id);
      refreshPersonal(ref.invalidate);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Deleted ${h.name}'),
            action: SnackBarAction(
              label: 'Undo',
              textColor: SkColors.brandSoft,
              onPressed: () async {
                try {
                  await writes.restoreHolding(h.id);
                  refreshPersonal(container.invalidate);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
                }
              },
            ),
          ),
        );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, apiErrorMessage(e));
      }
    }
  }
}
