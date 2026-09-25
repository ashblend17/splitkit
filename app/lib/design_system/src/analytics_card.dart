import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'surfaces.dart';

/// Frame for one config-driven dashboard card: title, period, then the renderer for its type.
class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({
    super.key,
    required this.title,
    required this.period,
    required this.child,
    this.compact = false,
  });

  final String title;
  final String period;
  final Widget child;

  /// Components-gallery size (14px title, 10px gap) instead of the screens' 15px / 12px.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title,
      child: SkCard(
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(title, style: SkText.body(compact ? 14 : 15, 700))),
                Text(period, style: SkText.body(12, 400, color: SkColors.ink2)),
              ],
            ),
            SizedBox(height: compact ? 10 : 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// A bar in a trend chart.
typedef TrendBar = ({String label, int value, bool highlight});

/// Vertical bars (spending per month / per day). The highlighted bar is indigo with its value
/// on top; the rest are pale. Bars are scaled to the largest value (112px of a 140px plot).
class TrendBars extends StatelessWidget {
  const TrendBars({super.key, required this.bars, required this.formatTop, required this.formatTip, this.headline});

  final List<TrendBar> bars;
  final String Function(int value) formatTop;
  final String Function(TrendBar bar) formatTip;
  final String? headline;

  @override
  Widget build(BuildContext context) {
    final max = bars.fold(0, (m, b) => b.value > m ? b.value : m);
    final gap = bars.length > 9 ? 6.0 : 10.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (headline != null) ...[Text(headline!, style: SkText.display(26, 800)), const SizedBox(height: 6)],
        Container(
          height: 140,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: SkColors.lineStrong)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, b) in bars.indexed) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: Tooltip(
                    message: formatTip(b),
                    child: Semantics(
                      label: formatTip(b),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (b.highlight)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                formatTop(b.value),
                                style: SkText.body(11, 700),
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                              ),
                            ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 28),
                            child: Container(
                              height: max == 0 ? 0 : (b.value / max * 112).roundToDouble(),
                              decoration: BoxDecoration(
                                color: b.highlight ? SkColors.brand : SkPalette.chartBar,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final (i, b) in bars.indexed) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: Text(
                    b.label,
                    textAlign: TextAlign.center,
                    style: SkText.body(11, 400, color: SkColors.ink2),
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontal bars (by category, who paid), scaled to the largest row.
class BreakdownBars extends StatelessWidget {
  const BreakdownBars({super.key, required this.rows, required this.format, this.color = SkColors.personal});

  final List<({String label, int value})> rows;
  final String Function(int value) format;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final max = rows.fold(0, (m, r) => r.value > m ? r.value : m);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          Semantics(
            label: '${r.label}: ${format(r.value)}',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(r.label, style: SkText.body(13, 600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: max == 0 ? 0 : r.value / max,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 72,
                    child: Text(format(r.value), textAlign: TextAlign.right, style: SkText.body(13, 600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Two-part bar (personal vs group) with a legend underneath.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.a, required this.b, required this.format});

  final ({String label, int value}) a;
  final ({String label, int value}) b;
  final String Function(int value) format;

  @override
  Widget build(BuildContext context) {
    final total = a.value + b.value;
    final pa = total == 0 ? 0 : (a.value / total * 100).round();
    final pb = total == 0 ? 0 : 100 - pa;
    Widget legend(String label, int pct, int value, Color c) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text('$label · $pct%', style: SkText.body(12, 400, color: SkColors.ink2)),
              ),
            ],
          ),
          Text(format(value), style: SkText.display(18, 700)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 16,
          child: total == 0
              ? Container(
                  decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(4)),
                )
              : Row(
                  children: [
                    if (pa > 0)
                      Expanded(
                        flex: pa,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: SkColors.personal,
                            borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                          ),
                        ),
                      ),
                    if (pa > 0 && pb > 0) const SizedBox(width: 2),
                    if (pb > 0)
                      Expanded(
                        flex: pb,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: SkColors.brand,
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            legend(a.label, pa, a.value, SkColors.personal),
            const SizedBox(width: 8),
            legend(b.label, pb, b.value, SkColors.brand),
          ],
        ),
      ],
    );
  }
}

/// One big figure with a note ("₹1,411" / "August averaged ₹993 per day").
class StatBlock extends StatelessWidget {
  const StatBlock({super.key, required this.value, this.note});

  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: SkText.display(36, 800, height: 1.05)),
        if (note != null) ...[
          const SizedBox(height: 2),
          Text(note!, style: SkText.body(13, 400, color: SkColors.ink2)),
        ],
      ],
    );
  }
}

/// Dashed placeholder shown for an analytics type with no renderer registered.
class AnalyticsPlaceholder extends StatelessWidget {
  const AnalyticsPlaceholder({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedBorder(),
      child: Container(
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: SkPalette.brandWash, borderRadius: BorderRadius.circular(10)),
        child: Text('renderer for $type', style: SkText.body(13, 600, color: SkColors.brandInk)),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)).deflate(0.75);
    final paint = Paint()
      ..color = SkPalette.brandTint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}
