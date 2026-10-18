import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

/// A bar of what's saved against a whole, with an optional planned part after it: the actual
/// segment is a solid personal fill, the planned one only a 1.5px outline in the same colour,
/// so planned money never reads as money saved (finance revamp design §2.4, step DS1).
///
/// [actual] and [planned] are fractions of the whole bar; together they're clamped to 1.
/// [actualLabel] and [plannedLabel] are the amounts as text ("₹2,000"); screen readers hear
/// "Saved ₹2,000" and "Planned ₹6,500, not yet saved".
class ActualPlannedBar extends StatelessWidget {
  const ActualPlannedBar({
    super.key,
    required this.actual,
    this.planned = 0,
    this.actualLabel,
    this.plannedLabel,
    this.height = 10,
  });

  final double actual;
  final double planned;
  final String? actualLabel;
  final String? plannedLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final saved = actual.isNaN ? 0.0 : actual.clamp(0.0, 1.0);
    final plan = planned.isNaN ? 0.0 : planned.clamp(0.0, 1.0 - saved);
    final radius = BorderRadius.circular(height / 2);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          // A sliver of progress still shows, as a dot the bar's height wide.
          final savedWidth = saved <= 0 ? 0.0 : (w * saved).clamp(height, w);
          final gap = savedWidth > 0 ? 2.0 : 0.0;
          final planWidth = plan <= 0 ? 0.0 : (w * plan - gap).clamp(height, w - savedWidth - gap);
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: SkColors.sunken, borderRadius: radius),
                ),
              ),
              if (savedWidth > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: savedWidth,
                  child: Semantics(
                    container: actualLabel != null,
                    label: actualLabel == null ? null : 'Saved $actualLabel',
                    child: Container(
                      key: const Key('bar-actual'),
                      decoration: BoxDecoration(color: SkColors.personal, borderRadius: radius),
                    ),
                  ),
                ),
              if (planWidth > 0)
                Positioned(
                  left: savedWidth + gap,
                  top: 0,
                  bottom: 0,
                  width: planWidth,
                  child: Semantics(
                    container: plannedLabel != null,
                    label: plannedLabel == null ? null : 'Planned $plannedLabel, not yet saved',
                    child: Container(
                      key: const Key('bar-planned'),
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(color: SkColors.personal, width: 1.5),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
