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
import '../personal/account_sheet.dart' show accountGlyph;

// Pieces the goal sheets share (the editor, the contribution sheet, the mode switch): the sheet's
// frame, a date button, account chips, and running a write with a "done" message and Undo.

/// Opens [sheet] as the goal sheets open: over the tab bar, scrolling, sized to its content.
Future<T?> showGoalSheet<T>(BuildContext context, Widget sheet) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => sheet,
);

/// A goal sheet's frame, as the account and entry sheets draw theirs: grab handle, [title], then
/// [children], in a column no wider than 560.
class GoalSheetFrame extends StatelessWidget {
  const GoalSheetFrame({super.key, required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
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
                Semantics(
                  header: true,
                  child: Text(title, style: SkText.display(22, 700), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: SkText.body(13, 400, color: SkColors.ink2)),
                ],
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A field's label above it.
Widget fieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(text, style: SkText.body(14, 600)),
);

/// A small grey line under a field.
Widget fieldHint(String text) => Padding(
  padding: const EdgeInsets.only(top: 6),
  child: Text(text, style: SkText.body(12, 400, color: SkColors.ink2)),
);

/// [minor] as an amount field shows it ("1,500.50"), without the symbol.
String amountFieldText(int minor, String currency) => money(minor, currency).substring(currencySymbol(currency).length);

/// An amount field ([SkTextField] with the currency's formatter).
Widget amountField(String label, TextEditingController controller, String currency, {Key? key}) => SkTextField(
  key: key,
  label: label,
  controller: controller,
  hint: '0',
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  inputFormatters: [AmountFormatter(currency: currency)],
);

/// The amount typed in [c], or null when it's empty or not an amount.
int? typedAmount(TextEditingController c, String currency) =>
    c.text.trim().isEmpty ? null : parseMinor(c.text, currency: currency);

/// A date as a bordered button, opening the date picker between [first] and [last]. [onClear]
/// adds a way to take the date away.
class GoalDateButton extends StatelessWidget {
  const GoalDateButton({
    super.key,
    required this.date,
    required this.onPicked,
    required this.first,
    required this.last,
    this.onClear,
    this.emptyLabel = 'No date',
  });

  final DateTime? date;
  final ValueChanged<DateTime> onPicked;
  final DateTime first;
  final DateTime last;
  final VoidCallback? onClear;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: SkColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: SkColors.line, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final now = appClock.now();
          final initial = date ?? DateTime(now.year, now.month, now.day);
          final picked = await showDatePicker(
            context: context,
            initialDate: initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial),
            firstDate: first,
            lastDate: last,
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
                  child: Text(
                    date == null ? emptyLabel : formDateLabel(date!),
                    style: SkText.body(14, 600, color: date == null ? SkColors.ink2 : SkColors.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (onClear == null || date == null) return button;
    return Row(
      children: [
        Expanded(child: button),
        const SizedBox(width: 8),
        SkButton('Clear', variant: SkButtonVariant.secondary, onPressed: onClear),
      ],
    );
  }
}

/// [accounts] as chips, [selected] marked; [disabled] can't be picked.
Widget accountChips(
  List<FinAccount> accounts, {
  required String? selected,
  required ValueChanged<String> onPick,
  String? disabled,
}) => Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    for (final a in accounts)
      SelectableChip(
        label: a.name,
        icon: accountGlyph(a.type),
        selected: a.id == selected,
        accent: ChipAccent.personal,
        onTap: a.id == disabled ? null : () => onPick(a.id),
      ),
  ],
);

/// [showMessage] through a messenger held from before a sheet closed or a page left.
void sayDone(ScaffoldMessengerState messenger, String text, {VoidCallback? undo}) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(
      content: Text(text),
      action: undo == null ? null : SnackBarAction(label: 'Undo', textColor: SkColors.brandSoft, onPressed: undo),
    ),
  );

/// Runs [write] from [ref]'s screen; then refreshes Personal, closes the sheet or dialog [context]
/// is in when [pop], and says [done] (with [undo], which runs another write). Refused: says why and
/// resolves false.
Future<bool> runGoalWrite(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(LocalWrites w) write, {
  String? done,
  Future<void> Function(LocalWrites w)? undo,
  bool pop = true,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final writes = ref.read(writesProvider);
  try {
    await write(writes);
  } catch (e) {
    sayDone(messenger, apiErrorMessage(e));
    return false;
  }
  refreshPersonal(container.invalidate);
  if (pop && context.mounted) Navigator.of(context).pop(true);
  if (done != null) {
    sayDone(
      messenger,
      done,
      undo: undo == null
          ? null
          : () async {
              try {
                await undo(writes);
                refreshPersonal(container.invalidate);
              } catch (e) {
                sayDone(messenger, apiErrorMessage(e));
              }
            },
    );
  }
  return true;
}
