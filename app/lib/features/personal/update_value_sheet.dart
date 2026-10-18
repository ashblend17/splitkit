/// "Update value" (finance revamp design §5.2): what a holding is worth now, on a day no later than
/// today, and optionally what you've paid for it in all.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/clock.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/finance/finance.dart';
import '../../core/local/writes.dart';
import '../../core/money/money.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'account_sheet.dart';

/// Updates [holding]'s value, with the day it's from (today unless picked) and optionally its
/// cost basis. Resolves to whether it was saved.
Future<bool> showUpdateValueSheet(BuildContext context, FinHolding holding) async =>
    await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpdateValueSheet(holding),
    ) ??
    false;

/// The frame the holding sheets share with the account sheet: a handle, then [children],
/// scrolling, in a column no wider than 560.
class HoldingSheetFrame extends StatelessWidget {
  const HoldingSheetFrame({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.94),
      decoration: BoxDecoration(
        color: SkColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(SkRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          child: ContentWidth(
            maxWidth: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: SkColors.lineStrong,
                      borderRadius: BorderRadius.circular(SkRadius.chip),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Value on": the day a value is from, picked from 2000 up to today.
class ValueDayField extends StatelessWidget {
  const ValueDayField({super.key, required this.day, required this.onPicked});

  final DateTime day;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Value on', style: SkText.body(14, 600)),
      const SizedBox(height: 8),
      Material(
        color: SkColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: SkColors.line, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final today = DateUtils.dateOnly(appClock.now());
            final picked = await showDatePicker(
              context: context,
              initialDate: day.isAfter(today) ? today : day,
              firstDate: DateTime(2000),
              lastDate: today,
            );
            if (picked != null) onPicked(picked);
          },
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const SkIcon('calendar', size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(formDateLabel(day), style: SkText.body(14, 600), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// An amount as an amount field shows it, without its symbol: 6000000 is "60,000".
String amountFieldText(int minor, String currency) => money(minor, currency).substring(currencySymbol(currency).length);

class _UpdateValueSheet extends ConsumerStatefulWidget {
  const _UpdateValueSheet(this.holding);

  final FinHolding holding;

  @override
  ConsumerState<_UpdateValueSheet> createState() => _UpdateValueSheetState();
}

class _UpdateValueSheetState extends ConsumerState<_UpdateValueSheet> {
  final _value = TextEditingController();
  final _cost = TextEditingController();
  DateTime _day = DateUtils.dateOnly(appClock.now());
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_value, _cost]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _value.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.holding, c = h.currency;
    final value = parseMinor(_value.text, currency: c);
    final cost = _cost.text.trim().isEmpty ? null : parseMinor(_cost.text, currency: c);
    final costOk = _cost.text.trim().isEmpty || cost != null;
    return HoldingSheetFrame(
      children: [
        Semantics(header: true, child: Text('Update value', style: SkText.display(22, 700))),
        const SizedBox(height: 6),
        Text(
          '${h.name} · ${money(h.marketValueMinor, c)} on ${dayKeyLabel(h.valuationDay)}',
          style: SkText.body(13, 400, color: SkColors.ink2),
        ),
        const SizedBox(height: 18),
        SkTextField(
          label: 'Value',
          controller: _value,
          hint: amountFieldText(h.marketValueMinor, c),
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [AmountFormatter(currency: c)],
        ),
        const SizedBox(height: 6),
        Text('What it was worth on the day below.', style: SkText.body(12, 400, color: SkColors.ink2)),
        const SizedBox(height: 14),
        ValueDayField(day: _day, onPicked: (d) => setState(() => _day = d)),
        const SizedBox(height: 14),
        SkTextField(
          label: 'What you paid in all (optional)',
          controller: _cost,
          hint: h.costBasisMinor == null ? '0' : amountFieldText(h.costBasisMinor!, c),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [AmountFormatter(currency: c)],
        ),
        const SizedBox(height: 6),
        Text(
          h.costBasisMinor == null
              ? 'With it, the gain shows.'
              : 'Leave it empty to keep ${money(h.costBasisMinor!, c)}.',
          style: SkText.body(12, 400, color: SkColors.ink2),
        ),
        const SizedBox(height: 18),
        SkButton(
          _busy ? 'Saving…' : 'Update value',
          size: SkButtonSize.large,
          expand: true,
          onPressed: !_busy && value != null && costOk ? () => _save(value, cost) : null,
        ),
      ],
    );
  }

  Future<void> _save(int value, int? cost) async {
    final h = widget.holding;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(writesProvider).updateValue(h.id, value, _day, costBasisMinor: cost);
      refreshPersonal(ref.invalidate);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Updated the value of ${h.name}')));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, apiErrorMessage(e));
      }
    }
  }
}
