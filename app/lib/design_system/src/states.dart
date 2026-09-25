import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'buttons.dart';
import 'sk_icon.dart';
import 'surfaces.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.glyph = 'groups',
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String glyph;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SkCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(
            glyph,
            background: SkColors.brandSoft,
            foreground: SkColors.brand,
            size: 48,
            radius: 14,
            iconSize: 24,
          ),
          const SizedBox(height: 10),
          Text(title, style: SkText.body(15, 700), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            body,
            style: SkText.body(13, 400, color: SkColors.ink2),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 10),
            SkButton(actionLabel!, onPressed: onAction, size: SkButtonSize.small),
          ],
        ],
      ),
    );
  }
}

/// Placeholder rows shaped like transaction cards, pulsing 1 → 0.5 → 1 over 1.4s.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
    ]).animate(_pulse);
    Widget bar(double? width, double height, {double widthFactor = 1}) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(6)),
      ),
    );
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (var i = 0; i < widget.rows; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              FadeTransition(
                opacity: opacity,
                child: Container(
                  height: 78,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: SkColors.surface,
                    borderRadius: BorderRadius.circular(SkRadius.card),
                    border: Border.all(color: SkColors.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bar(null, 12, widthFactor: 0.7),
                            const SizedBox(height: 8),
                            bar(null, 10, widthFactor: 0.45),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 48,
                        height: 16,
                        decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(6)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.title, required this.body, this.onRetry, this.retryLabel = 'Try again'});

  final String title;
  final String body;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: SkCard(
        radius: 18,
        padding: const EdgeInsets.all(18),
        borderColor: SkPalette.dangerBorder,
        borderWidth: 1.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SkIcon('alert', size: 20, color: SkColors.oweInk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: SkText.body(15, 700, color: SkColors.oweInk)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(body, style: SkText.body(13, 400, color: SkColors.ink2)),
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              SkButton(
                retryLabel,
                onPressed: onRetry,
                variant: SkButtonVariant.secondary,
                size: SkButtonSize.small,
                icon: 'refresh',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
