import 'package:flutter/material.dart';

/// How long things move, and how. Everything that moves goes through [SkMotion.of], so the
/// phone's "Remove animations" setting stops all of it.
abstract final class SkMotion {
  /// A control's thumb or a switch between two views.
  static const quick = Duration(milliseconds: 220);

  /// Bars, figures and cards settling into place.
  static const settle = Duration(milliseconds: 520);

  /// Between one card and the next as a dashboard comes in.
  static const stagger = Duration(milliseconds: 60);

  static const curve = Curves.easeOutCubic;

  /// [d], or nothing when the platform asks for no animations.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

/// An amount that counts up to [value] when first shown, and from the old figure to the new
/// one when it changes (another period). Screen readers get the final figure only.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney({super.key, required this.value, required this.format, required this.style});

  final int value;
  final String Function(int value) format;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Semantics(
    label: format(value),
    child: ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: SkMotion.of(context, SkMotion.settle),
        curve: SkMotion.curve,
        builder: (context, v, _) {
          // Whole units on the way, so paise don't flicker past; the exact figure at the end.
          final shown = v == value ? value : (v / 100).round() * 100;
          return Text(format(shown), style: style, maxLines: 1, softWrap: false);
        },
      ),
    ),
  );
}

/// [child] fades in and rises a little the first time it's built, [index] steps after the
/// first, so a dashboard's cards come in one after another. Rebuilds don't run it again.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  /// Cards after this many come in with the last (a long dashboard shouldn't keep you waiting).
  static const _maxSteps = 6;

  @override
  Widget build(BuildContext context) {
    final step = SkMotion.stagger * (index < _maxSteps ? index : _maxSteps);
    final total = SkMotion.of(context, SkMotion.settle + step);
    final start = total == Duration.zero ? 0.0 : step.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: SkMotion.curve),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
    );
  }
}
