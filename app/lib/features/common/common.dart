import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';

/// Screens are designed at 390px. Pages without a tablet or desktop mockup stay
/// phone-width and centred beside the rail or sidebar.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 640});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Loading skeleton, error card with retry, or the data.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
    this.skeletonRows = 3,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  final int skeletonRows;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData(:final value) => builder(value),
      AsyncError(:final error) when !value.isLoading => ErrorState(
        title: "Couldn't load this",
        body: error is ApiException && error.code == 0 || error.toString().contains('SocketException')
            ? "You're offline. Check your connection and try again."
            : apiErrorMessage(error),
        onRetry: onRetry,
      ),
      _ => value.hasValue ? builder(value.requireValue) : LoadingSkeleton(rows: skeletonRows),
    };
  }
}

/// 44px icon button used in page headers.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({super.key, required this.glyph, required this.label, required this.onPressed, this.color});
  final String glyph;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onPressed,
        radius: 22,
        child: SizedBox.square(
          dimension: 44,
          child: Center(child: SkIcon(glyph, size: 22, color: color ?? SkColors.ink)),
        ),
      ),
    );
  }
}

/// Uppercase section heading ("WITH EACH PERSON", "TODAY").
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Semantics(header: true, child: Text(text.toUpperCase(), style: SkText.overline));
}

void showMessage(BuildContext context, String text, {String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, textColor: SkColors.brandSoft, onPressed: onAction!),
      ),
    );
}

/// Pull-to-refresh that invalidates everything derived from the ledger.
class LedgerRefresh extends ConsumerWidget {
  const LedgerRefresh({super.key, required this.child, required this.onRefresh});
  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      RefreshIndicator(color: SkColors.brand, onRefresh: onRefresh, child: child);
}
