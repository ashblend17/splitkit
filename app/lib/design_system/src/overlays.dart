import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'avatar.dart';
import 'sk_icon.dart';

/// The dialog body on its own, so the gallery can show it inline.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.destructive = true,
    this.onCancel,
    this.onConfirm,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    Widget button(String label, VoidCallback? onTap, {required bool primary}) => Expanded(
      child: SizedBox(
        height: 46,
        child: Material(
          color: primary ? (destructive ? SkColors.owe : SkColors.brand) : SkColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: primary ? BorderSide.none : const BorderSide(color: SkColors.lineStrong, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Text(label, style: SkText.body(15, 700, color: primary ? Colors.white : SkColors.ink)),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      label: title,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: SkColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: SkText.display(20, 700)),
            const SizedBox(height: 12),
            Text(body, style: SkText.body(14, 400, color: SkColors.ink2, height: 1.45)),
            const SizedBox(height: 12),
            Row(
              children: [
                button(cancelLabel, onCancel, primary: false),
                const SizedBox(width: 8),
                button(confirmLabel, onConfirm, primary: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [ConfirmDialog]; resolves true only when the person confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConfirmDialog(
          title: title,
          body: body,
          confirmLabel: confirmLabel,
          destructive: destructive,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () => Navigator.of(context).pop(true),
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Sheet body: grab handle, title, content (Paid by, Record payment…).
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
      decoration: const BoxDecoration(
        color: SkColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 10),
            Semantics(header: true, child: Text(title, style: SkText.display(18, 700))),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

Future<T?> showAppBottomSheet<T>(BuildContext context, {required String title, required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    // Cover the tab bar: sheets belong to the whole screen, not the current tab.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AppBottomSheet(title: title, child: child),
  );
}

/// A person to pick in a sheet, with a check on the current choice.
class SheetPersonOption extends StatelessWidget {
  const SheetPersonOption({super.key, required this.person, required this.selected, required this.onTap, this.label});

  final SkPerson person;
  final bool selected;
  final VoidCallback onTap;

  /// Defaults to the person's name; "You" for the viewer.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label ?? person.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Avatar(person, size: 30, fontSize: 11),
                const SizedBox(width: 10),
                Expanded(child: Text(label ?? person.name, style: SkText.body(15, 600))),
                if (selected) const SkIcon('check', size: 20, color: SkColors.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
