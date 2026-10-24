import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'motion.dart';

/// Two to four choices in a sunken track; the chosen one sits on a raised thumb that slides
/// across when another is picked (Week / Month / Year, Total / Average).
class SkSegmented<T> extends StatelessWidget {
  const SkSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    Color? selectedColor,
    this.height = 36,
    this.fontSize = 13,
  }) : _selectedColor = selectedColor;

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Color? _selectedColor;
  Color get selectedColor => _selectedColor ?? SkColors.brandInk;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final n = options.length;
    final at = options.indexWhere((o) => o.$1 == value);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          if (at >= 0)
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(n == 1 ? 0 : -1 + 2 * at / (n - 1), 0),
                duration: SkMotion.of(context, SkMotion.quick),
                curve: SkMotion.curve,
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  child: Container(
                    decoration: BoxDecoration(
                      color: SkColors.surface,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [BoxShadow(color: SkPalette.shadowInk, blurRadius: 3, offset: const Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final (i, (key, label)) in options.indexed)
                Expanded(
                  child: Semantics(
                    selected: i == at,
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(key),
                      child: SizedBox(
                        height: height,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: SkMotion.of(context, SkMotion.quick),
                            style: SkText.body(
                              fontSize,
                              i == at ? 700 : 600,
                              color: i == at ? selectedColor : SkColors.ink2,
                            ),
                            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
