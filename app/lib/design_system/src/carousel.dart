import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'motion.dart';
import 'navigation.dart';

/// Cards side by side that scroll sideways where they don't all fit: on a phone one at a time
/// with the next peeking in, snapping to each, with dots under them for where you are. Where
/// every card fits, they sit in a row and nothing scrolls.
class BreakdownCarousel extends StatefulWidget {
  const BreakdownCarousel({
    super.key,
    required this.children,
    this.minCardWidth = 280,
    this.gap = 12,
    this.accent = NavAccent.personal,
  });

  final List<Widget> children;
  final double minCardWidth;
  final double gap;
  final NavAccent accent;

  @override
  State<BreakdownCarousel> createState() => _BreakdownCarouselState();
}

class _BreakdownCarouselState extends State<BreakdownCarousel> {
  final _scroll = ScrollController();
  int _page = 0;
  double _extent = 1;

  /// How much of the next card shows.
  static const _peek = 28.0;

  /// Where it can come to rest: one card after another until the last is fully in.
  int _positions = 1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final page = (_scroll.offset / _extent).round().clamp(0, _positions - 1);
      if (page != _page) setState(() => _page = page);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int page) => _scroll.animateTo(
    (page * _extent).clamp(0.0, _scroll.position.maxScrollExtent),
    duration: SkMotion.of(context, SkMotion.settle),
    curve: SkMotion.curve,
  );

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;
    final gap = widget.gap;
    return LayoutBuilder(
      builder: (context, box) {
        final fit = ((box.maxWidth + gap) / (widget.minCardWidth + gap)).floor().clamp(1, n);
        if (fit >= n) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, c) in widget.children.indexed) ...[if (i > 0) SizedBox(width: gap), Expanded(child: c)],
            ],
          );
        }
        final width = (box.maxWidth - _peek - gap * fit) / fit;
        _extent = width + gap;
        _positions = n - fit + 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: _SnapPhysics(extent: _extent),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, c) in widget.children.indexed) ...[
                    if (i > 0) SizedBox(width: gap),
                    SizedBox(width: width, child: c),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _positions; i++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _go(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                        child: AnimatedContainer(
                          duration: SkMotion.of(context, SkMotion.quick),
                          curve: SkMotion.curve,
                          width: i == _page ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _page ? widget.accent.fill : SkColors.lineStrong,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Settles on a whole card after a fling or drag, as a PageView does for whole pages.
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({required this.extent, super.parent});

  final double extent;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) => _SnapPhysics(extent: extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    var page = position.pixels / extent;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    final target = (page.roundToDouble() * extent).clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);
  }

  @override
  bool get allowImplicitScrolling => false;
}
