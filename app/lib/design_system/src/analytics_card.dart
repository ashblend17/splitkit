import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'motion.dart';
import 'navigation.dart';
import 'sk_icon.dart';
import 'surfaces.dart';

/// Frame for one config-driven dashboard card: an icon tile, the title with its period under
/// it, then the renderer for its type. [trailing] sits at the header's end.
class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({
    super.key,
    required this.title,
    required this.period,
    required this.child,
    this.compact = false,
    this.glyph,
    this.accent = NavAccent.brand,
    this.trailing,
  });

  final String title;
  final String period;
  final Widget child;

  /// Components-gallery size (14px title, 10px gap) instead of the screens' 15px / 14px.
  final bool compact;

  /// What the card is about ('chart', 'wallet'…), in a tile tinted with [accent].
  final String? glyph;
  final NavAccent accent;
  final Widget? trailing;

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
              children: [
                if (glyph != null) ...[GlyphTile(glyph!, accent: accent, size: 34), const SizedBox(width: 10)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: SkText.body(compact ? 14 : 15, 700)),
                      // Another period: the old label fades out as the new one comes in.
                      AnimatedSwitcher(
                        duration: SkMotion.of(context, SkMotion.quick),
                        layoutBuilder: (current, previous) =>
                            Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                        child: Text(period, key: ValueKey(period), style: SkText.body(12, 400, color: SkColors.ink2)),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
            SizedBox(height: compact ? 10 : 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// A glyph on a rounded tile in [accent]'s soft colour.
class GlyphTile extends StatelessWidget {
  const GlyphTile(this.glyph, {super.key, this.accent = NavAccent.personal, this.size = 28});

  final String glyph;
  final NavAccent accent;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: accent.soft, borderRadius: BorderRadius.circular(size * 0.3)),
      alignment: Alignment.center,
      child: SkIcon(glyph, size: size * 0.55, color: accent.ink),
    ),
  );
}

/// A bar in a trend chart.
typedef TrendBar = ({String label, int value, bool highlight});

/// Vertical bars (spending per month / per day). The highlighted bar is in [accent] with its
/// value on top; the rest are pale. Bars are scaled to the largest value (112px of a 140px
/// plot), and grow from the axis when first shown, or to their new height for another period.
///
/// Tapping a bar picks it (the whole column, so short bars are easy to hit): it takes the accent
/// and [formatTip] ("12 Sep: ₹19,160") shows above it. Tapping it again puts the chart back.
/// With a mouse, pointing at a bar shows it too.
class TrendBars extends StatefulWidget {
  const TrendBars({
    super.key,
    required this.bars,
    required this.formatTop,
    required this.formatTip,
    this.headline,
    this.accent = NavAccent.brand,
  });

  final List<TrendBar> bars;
  final String Function(int value) formatTop;
  final String Function(TrendBar bar) formatTip;
  final String? headline;
  final NavAccent accent;

  @override
  State<TrendBars> createState() => _TrendBarsState();
}

class _TrendBarsState extends State<TrendBars> {
  /// The bar tapped, and the one under the mouse (which wins while it's there).
  int? _picked, _hovered;

  static const _plot = 140.0, _tallest = 112.0;

  @override
  void didUpdateWidget(TrendBars old) {
    super.didUpdateWidget(old);
    // Another period: the same index is another day or month.
    final same = old.bars.length == widget.bars.length &&
        [for (final (i, b) in widget.bars.indexed) b.label == old.bars[i].label].every((x) => x);
    if (!same) _picked = _hovered = null;
  }

  void _pick(int i) => setState(() => _picked = _picked == i ? null : i);

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    final max = bars.fold(0, (m, b) => b.value > m ? b.value : m);
    final gap = bars.length > 9 ? 6.0 : 10.0;
    final shown = _hovered ?? _picked;
    double height(TrendBar b) => max == 0 ? 0 : (b.value / max * _tallest).roundToDouble();
    // 28px on a phone; wider in a chart across a desktop, so its bars don't look lost.
    double barWidth(double plot) => ((plot - gap * (bars.length - 1)) / bars.length * 0.45).clamp(28.0, 56.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.headline != null) ...[
          AnimatedSwitcher(
            duration: SkMotion.of(context, SkMotion.quick),
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
            child: Text(widget.headline!, key: ValueKey(widget.headline), style: SkText.display(26, 800)),
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: _plot,
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: SkColors.lineStrong)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final (i, b) in bars.indexed) ...[
                          if (i > 0) SizedBox(width: gap),
                          Expanded(child: _bar(context, i, b, shown, height(b), barWidth(c.maxWidth))),
                        ],
                      ],
                    ),
                  ),
                ),
                if (shown != null && shown < bars.length)
                  _readout(context, c.maxWidth, gap, shown, height(bars[shown])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, c) {
              final style = SkText.body(11, 400, color: SkColors.ink2);
              // Labels wider than their bar show every few bars, whole, rather than each one clipped.
              final column = (c.maxWidth - gap * (bars.length - 1)) / bars.length;
              final widest = bars.fold(0.0, (w, b) => math.max(w, _textWidth(context, b.label, style)));
              final every = widest <= column ? 1 : ((widest + 6) / (column + gap)).ceil();
              return Row(
                children: [
                  for (final (i, b) in bars.indexed) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(
                      child: i % every != 0
                          ? const SizedBox.shrink()
                          : SizedBox(
                              height: style.fontSize! * 1.4,
                              child: OverflowBox(
                                maxWidth: double.infinity,
                                alignment: every == 1 || (i > 0 && i < bars.length - every)
                                    ? Alignment.center
                                    : i == 0
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                child: Text(b.label, style: style, maxLines: 1, softWrap: false),
                              ),
                            ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// One bar's column, tappable from the axis to the top of the plot.
  Widget _bar(BuildContext context, int i, TrendBar b, int? shown, double height, double width) {
    final on = shown == null ? b.highlight : shown == i;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = i),
      onExit: (_) => setState(() => _hovered = _hovered == i ? null : _hovered),
      child: Semantics(
        button: true,
        selected: _picked == i,
        label: widget.formatTip(b),
        onTap: () => _pick(i),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () => _pick(i),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // A picked bar says its own amount, above the chart (_readout), instead.
              if (shown == null && b.highlight)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _TopLabel(widget.formatTop(b.value), first: i == 0, last: i == widget.bars.length - 1),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width),
                // Left to right, each a little after the one before: a wave across the chart.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: height),
                  duration: SkMotion.of(context, SkMotion.settle + SkMotion.stagger * (i / 2)),
                  curve: SkMotion.curve,
                  builder: (context, h, _) => SizedBox(
                    height: h,
                    child: AnimatedContainer(
                      duration: SkMotion.of(context, SkMotion.quick),
                      decoration: BoxDecoration(
                        color: on ? widget.accent.fill : _muted,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The bars not picked: brand's pale chart colour, or the personal colour see-through (its
  /// soft colour is too close to a dark card to read).
  Color get _muted => widget.accent == NavAccent.personal ? SkColors.personal.withValues(alpha: 0.3) : SkPalette.chartBar;

  /// "12 Sep: ₹19,160" in a dark pill over the picked bar, kept inside the chart.
  Widget _readout(BuildContext context, double width, double gap, int i, double barHeight) {
    final text = widget.formatTip(widget.bars[i]);
    final style = SkText.body(12, 700, color: SkColors.surface);
    const pad = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final pillWidth = _textWidth(context, text, style).ceilToDouble() + pad.horizontal;
    final pillHeight = (style.fontSize! * 1.4).ceilToDouble() + pad.vertical;
    final n = widget.bars.length;
    final column = (width - gap * (n - 1)) / n;
    final centre = i * (column + gap) + column / 2;
    return Positioned(
      left: (centre - pillWidth / 2).clamp(0.0, math.max(0.0, width - pillWidth)),
      top: (_plot - barHeight - 6 - pillHeight).clamp(0.0, _plot),
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Container(
            padding: pad,
            decoration: BoxDecoration(color: SkColors.ink, borderRadius: BorderRadius.circular(6)),
            child: Text(text, style: style, maxLines: 1, softWrap: false),
          ),
        ),
      ),
    );
  }
}

/// The figure over the highlighted bar. Wider than a narrow bar's column, it is centred over
/// the bar but kept inside the chart at either end (the last bar is usually the highlighted one).
class _TopLabel extends StatelessWidget {
  const _TopLabel(this.text, {required this.first, required this.last});
  final String text;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final style = SkText.body(11, 700);
    return LayoutBuilder(
      builder: (context, c) {
        final size = (TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout()).size;
        final width = size.width;
        final alignment = width <= c.maxWidth
            ? Alignment.center
            : last
            ? Alignment.centerRight
            : first
            ? Alignment.centerLeft
            : Alignment.center;
        return SizedBox(
          width: c.maxWidth,
          height: size.height,
          child: OverflowBox(
            maxWidth: double.infinity,
            alignment: alignment,
            child: Text(text, style: style, maxLines: 1, softWrap: false),
          ),
        );
      },
    );
  }
}

/// A rounded track with a fill that grows to [fraction] (0–1), from nothing when first shown
/// and from the old length when it changes. [index] staggers a list of them.
class _Meter extends StatelessWidget {
  const _Meter({required this.fraction, required this.color, this.index = 0, this.marks = const [], this.past});

  final double fraction;
  final Color color;
  final int index;
  static const height = 8.0;

  /// Ticks along the track (0–1): a usual amount to set the fill against.
  final List<double> marks;

  /// The fill's colour beyond the first mark, if it goes past it.
  final Color? past;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(height / 2));
    return SizedBox(
      height: height + (marks.isEmpty ? 0 : 6),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(color: SkColors.sunken, borderRadius: radius),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
            duration: SkMotion.of(context, SkMotion.settle + SkMotion.stagger * math.min(index, 8)),
            curve: SkMotion.curve,
            builder: (context, f, _) {
              Widget fill(double to, Color c) => FractionallySizedBox(
                widthFactor: to,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(color: c, borderRadius: radius),
                ),
              );
              final upTo = past == null || marks.isEmpty ? f : math.min(f, marks.first.clamp(0.0, 1.0));
              return Stack(
                alignment: Alignment.centerLeft,
                children: [if (upTo < f) fill(f, past!), fill(upTo, color)],
              );
            },
          ),
          for (final m in marks)
            Align(
              alignment: Alignment(-1 + 2 * m.clamp(0.0, 1.0), 0),
              child: Container(
                width: 3,
                height: height + 6,
                decoration: BoxDecoration(
                  color: SkColors.ink,
                  borderRadius: BorderRadius.circular(1.5),
                  border: Border.all(color: SkColors.surface, width: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rows of a breakdown (by category, by account, who paid): the name and its amount, and under
/// them a bar scaled to the largest row. With [glyphs], a row whose name has one starts with
/// its tile and the bar lines up under the name.
class BreakdownBars extends StatelessWidget {
  const BreakdownBars({
    super.key,
    required this.rows,
    required this.format,
    Color? color,
    this.glyphs,
    this.accent = NavAccent.personal,
  }) : _color = color;

  final List<({String label, int value})> rows;
  final String Function(int value) format;
  final Color? _color;
  Color get color => _color ?? accent.fill;
  final String? Function(String label)? glyphs;

  /// The tiles' colours.
  final NavAccent accent;

  @override
  Widget build(BuildContext context) {
    final max = rows.fold(0, (m, r) => r.value > m ? r.value : m);
    final tiled = glyphs != null && rows.any((r) => glyphs!(r.label) != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          Semantics(
            label: '${r.label}: ${format(r.value)}',
            child: ExcludeSemantics(
              child: _BreakdownRow(
                glyph: tiled ? glyphs!(r.label) ?? 'other' : null,
                accent: accent,
                label: r.label,
                amount: Text(format(r.value), style: SkText.body(13, 700), maxLines: 1, softWrap: false),
                meter: _Meter(fraction: max == 0 ? 0 : r.value / max, color: color, index: i),
              ),
            ),
          ),
        ],
      ],
    );
  }

}

/// One breakdown row: [glyph]'s tile (if any), then the name with [amount] at the end, [meter]
/// under them and [note] under that.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.glyph,
    required this.accent,
    required this.label,
    required this.amount,
    required this.meter,
    this.note,
  });

  final String? glyph;
  final NavAccent accent;
  final String label;
  final Widget amount;
  final Widget meter;
  final Widget? note;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (glyph != null) ...[GlyphTile(glyph!, accent: accent), const SizedBox(width: 10)],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: SkText.body(13, 600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 10),
                amount,
              ],
            ),
            const SizedBox(height: 6),
            meter,
            if (note != null) ...[const SizedBox(height: 4), note!],
          ],
        ),
      ),
    ],
  );
}

/// A row of [AverageBars]: what a usual week or month came to, and the one under way so far.
typedef AverageRow = ({String label, int average, int now});

/// Each row's spending so far against its usual: the fill is so far, the tick is usual, and
/// the fill past the tick is in the owe colour ("₹3,990 more"). [unit] is 'week' or 'month';
/// [nowLabel] what "so far" covers ("October so far").
class AverageBars extends StatelessWidget {
  const AverageBars({
    super.key,
    required this.rows,
    required this.format,
    required this.unit,
    required this.nowLabel,
    this.glyphs,
    this.accent = NavAccent.personal,
  });

  final List<AverageRow> rows;
  final String Function(int value) format;
  final String unit;
  final String nowLabel;
  final String? Function(String label)? glyphs;
  final NavAccent accent;

  @override
  Widget build(BuildContext context) {
    final scale = rows.fold(0, (m, r) => math.max(m, math.max(r.average, r.now)));
    final tiled = glyphs != null && rows.any((r) => glyphs!(r.label) != null);
    Widget key(Widget swatch, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [swatch, const SizedBox(width: 6), Text(text, style: SkText.body(12, 400, color: SkColors.ink2))],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              key(
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: accent.fill, borderRadius: BorderRadius.circular(3)),
                ),
                nowLabel,
              ),
              key(
                Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(color: SkColors.ink, borderRadius: BorderRadius.circular(1.5)),
                ),
                'Usual $unit',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          _averageRow(i, r, scale, tiled),
        ],
      ],
    );
  }

  Widget _averageRow(int i, AverageRow r, int scale, bool tiled) {
    final more = r.average > 0 && r.now > r.average ? r.now - r.average : 0;
    final usual = r.average == 0 ? 'Nothing in a usual $unit' : 'Usually ${format(r.average)}';
    final said = [
      '${r.label}: ${format(r.now)} $nowLabel',
      r.average == 0 ? 'nothing in a usual $unit' : '${format(r.average)} in a usual $unit',
      if (more > 0) '${format(more)} more',
    ].join(', ');
    return Semantics(
      label: said,
      child: ExcludeSemantics(
        child: _BreakdownRow(
          glyph: tiled ? glyphs!(r.label) ?? 'other' : null,
          accent: accent,
          label: r.label,
          amount: Text(format(r.now), style: SkText.body(13, 700), maxLines: 1, softWrap: false),
          meter: _Meter(
            fraction: scale == 0 ? 0 : r.now / scale,
            color: accent.fill,
            past: SkColors.owe,
            index: i,
            marks: [if (r.average > 0 && scale > 0) r.average / scale],
          ),
          note: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: usual),
                if (more > 0) TextSpan(text: ' · ${format(more)} more', style: SkText.body(12, 600, color: SkColors.oweInk)),
              ],
            ),
            style: SkText.body(12, 400, color: SkColors.ink2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Two-part bar (personal vs group) with a legend underneath. It grows in from the left when
/// first shown and slides to the new split when the figures change.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.a, required this.b, required this.format, this.accent = NavAccent.personal});

  final ({String label, int value}) a;
  final ({String label, int value}) b;
  final String Function(int value) format;

  /// The first part's colour; the second is always brand.
  final NavAccent accent;

  @override
  Widget build(BuildContext context) {
    final total = a.value + b.value;
    final pa = total == 0 ? 0 : (a.value / total * 100).round();
    final pb = total == 0 ? 0 : 100 - pa;
    final share = total == 0 ? 0.0 : a.value / total;
    final duration = SkMotion.of(context, SkMotion.settle);
    Widget legend(String label, int pct, int value, Color c) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text('$label · $pct%', style: SkText.body(12, 400, color: SkColors.ink2)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          AnimatedMoney(value: value, format: format, style: SkText.display(18, 700)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 16,
          decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.centerLeft,
          child: total == 0
              ? null
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: duration,
                  curve: SkMotion.curve,
                  builder: (context, grown, _) => FractionallySizedBox(
                    widthFactor: grown,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: share, end: share),
                      duration: duration,
                      curve: SkMotion.curve,
                      builder: (context, s, _) => _parts(s),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            legend(a.label, pa, a.value, accent.fill),
            const SizedBox(width: 8),
            legend(b.label, pb, b.value, SkColors.brand),
          ],
        ),
      ],
    );
  }

  /// The two parts at [share] for the first, 2px apart where both show.
  Widget _parts(double share) {
    final first = (share * 1000).round(), second = 1000 - first;
    return Row(
      children: [
        if (first > 0)
          Expanded(
            flex: first,
            child: Container(
              decoration: BoxDecoration(
                color: accent.fill,
                borderRadius: BorderRadius.horizontal(
                  left: const Radius.circular(8),
                  right: Radius.circular(second > 0 ? 2 : 8),
                ),
              ),
            ),
          ),
        if (first > 0 && second > 0) const SizedBox(width: 2),
        if (second > 0)
          Expanded(
            flex: second,
            child: Container(
              decoration: BoxDecoration(
                color: SkColors.brand,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(first > 0 ? 2 : 8),
                  right: const Radius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One big figure with a note ("₹1,411" / "August averaged ₹993 per day"). With [amount] and
/// [format] the figure counts up to it (and from the old one to a new one).
class StatBlock extends StatelessWidget {
  const StatBlock({super.key, required this.value, this.note, this.amount, this.format});

  final String value;
  final String? note;
  final int? amount;
  final String Function(int value)? format;

  @override
  Widget build(BuildContext context) {
    final style = SkText.display(36, 800, height: 1.05);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (amount != null && format != null)
          AnimatedMoney(value: amount!, format: format!, style: style)
        else
          AnimatedSwitcher(
            duration: SkMotion.of(context, SkMotion.quick),
            child: Text(value, key: ValueKey(value), style: style),
          ),
        if (note != null) ...[
          const SizedBox(height: 4),
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

double _textWidth(BuildContext context, String text, TextStyle style) => (TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
  textScaler: MediaQuery.textScalerOf(context),
  maxLines: 1,
)..layout()).width;
