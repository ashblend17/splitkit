import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'sk_icon.dart';

enum SkButtonVariant { primary, strong, secondary, ghost, danger }

enum SkButtonSize {
  /// 48 high, 15/700 (Components "Buttons").
  regular(48, 12, 15, 20),

  /// 54 high, 16/700 (screen footers: "Save split", "Done").
  large(54, 14, 16, 20),

  /// 40 high, 14/700 (empty and error states).
  small(40, 10, 14, 14);

  const SkButtonSize(this.height, this.radius, this.fontSize, this.padding);
  final double height;
  final double radius;
  final double fontSize;
  final double padding;
}

/// The six button looks from Components: Primary, Strong, Secondary, Ghost, Delete, Disabled.
/// Disabled is any variant with [onPressed] null.
class SkButton extends StatelessWidget {
  const SkButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.variant = SkButtonVariant.primary,
    this.size = SkButtonSize.regular,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final SkButtonVariant variant;
  final SkButtonSize size;
  final String? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (bg, fg, border) = !enabled
        ? (SkColors.lineStrong, SkColors.ink2, null)
        : switch (variant) {
            SkButtonVariant.primary => (SkColors.brand, Colors.white, null),
            SkButtonVariant.strong => (SkColors.ink, Colors.white, null),
            SkButtonVariant.secondary => (SkColors.surface, SkColors.ink, SkColors.lineStrong),
            SkButtonVariant.ghost => (Colors.transparent, SkColors.brandInk, null),
            SkButtonVariant.danger => (SkColors.oweSoft, SkColors.oweInk, SkPalette.dangerBorder),
          };
    final hPad = variant == SkButtonVariant.ghost ? size.padding - 4 : size.padding;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[SkIcon(icon!, size: size.fontSize + 1, color: fg), const SizedBox(width: 6)],
        Flexible(
          child: Text(
            label,
            style: SkText.body(size.fontSize, 700, color: fg),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: SizedBox(
        height: size.height,
        width: expand ? double.infinity : null,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(size.radius),
            side: border == null ? BorderSide.none : BorderSide(color: border, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one floating action per screen, always "Add split".
class AddSplitFab extends StatelessWidget {
  const AddSplitFab({super.key, required this.onPressed, this.label = 'Add split'});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SkRadius.chip),
          boxShadow: const [BoxShadow(color: SkPalette.fabShadow, blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Material(
          color: SkColors.brand,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 22, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SkIcon('plus', size: 22, color: Colors.white),
                    const SizedBox(width: 8),
                    ExcludeSemantics(
                      child: Text(label, style: SkText.body(16, 700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small bordered pill button, e.g. "All groups" with a filter icon on Home.
class SkPillButton extends StatelessWidget {
  const SkPillButton(this.label, {super.key, required this.onPressed, this.leading, this.trailing});

  final String label;
  final VoidCallback? onPressed;
  final String? leading;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SkColors.surface,
      shape: const StadiumBorder(side: BorderSide(color: SkColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[SkIcon(leading!, size: 16), const SizedBox(width: 6)],
                Text(label, style: SkText.body(13, 600)),
                if (trailing != null) ...[const SizedBox(width: 4), SkIcon(trailing!, size: 14)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
