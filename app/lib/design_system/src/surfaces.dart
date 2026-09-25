import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'sk_icon.dart';

/// White card with the hairline border used everywhere in the designs.
class SkCard extends StatelessWidget {
  const SkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = SkRadius.card,
    this.borderColor = SkColors.line,
    this.borderWidth = 1,
    this.color = SkColors.surface,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color borderColor;
  final double borderWidth;
  final Color color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor, width: borderWidth),
    );
    final content = Padding(padding: padding, child: child);
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      container: true,
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Rounded square holding an icon: transaction tiles, group tiles, empty states.
class IconTile extends StatelessWidget {
  const IconTile(
    this.glyph, {
    super.key,
    required this.background,
    required this.foreground,
    this.size = 44,
    this.radius = 12,
    this.iconSize = 22,
  });

  final String glyph;
  final Color background;
  final Color foreground;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius)),
      alignment: Alignment.center,
      child: SkIcon(glyph, size: iconSize, color: foreground),
    );
  }
}
