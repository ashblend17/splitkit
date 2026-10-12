import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'navigation.dart';

/// Split | Personal: swaps the whole app between its two halves. A row at the top of a phone
/// screen and in the sidebar, stacked in the tablet rail. The selected half is raised and
/// takes its own accent, like the period tabs.
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({
    super.key,
    required this.personal,
    required this.onChanged,
    this.direction = Axis.horizontal,
    this.expand = false,
  });

  /// Whether Personal is the selected half (otherwise Split).
  final bool personal;

  /// Called with true for Personal, false for Split; not called for the half already shown.
  final ValueChanged<bool> onChanged;

  final Axis direction;

  /// Fill the width (sidebar) instead of fitting the labels (phone).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final row = direction == Axis.horizontal;
    Widget option(String label, {required bool isPersonal, required NavAccent accent}) {
      final on = personal == isPersonal;
      final tab = Semantics(
        container: true,
        button: true,
        selected: on,
        label: '$label mode',
        onTap: on ? null : () => onChanged(isPersonal),
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: on ? null : () => onChanged(isPersonal),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 36,
              padding: EdgeInsets.symmetric(horizontal: row && !expand ? 18 : 6),
              decoration: BoxDecoration(
                color: on ? SkColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: on ? const [BoxShadow(color: SkPalette.shadowInk, blurRadius: 3, offset: Offset(0, 1))] : null,
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: SkText.body(13, on ? 700 : 600, color: on ? accent.ink : SkColors.ink2),
                ),
              ),
            ),
          ),
        ),
      );
      return row && expand ? Expanded(child: tab) : tab;
    }

    final options = [
      option('Split', isPersonal: false, accent: NavAccent.brand),
      SizedBox(width: row ? 4 : 0, height: row ? 0 : 4),
      option('Personal', isPersonal: true, accent: NavAccent.personal),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(12)),
      child: row
          ? Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: options)
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: options),
    );
  }
}
