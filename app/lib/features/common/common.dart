import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/layout/layout.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';

/// Screens are designed at 390px. Pages you open from a tab (a form, Deleted items, Categories)
/// stay phone-width and centred beside the rail or sidebar.
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

// Every tab page (Home, Groups, a group's tabs, Overview, Transactions, Insights, Profile) is
// framed the same way, so moving between them doesn't jump: under 1280px the 390px designs in
// a centred 640px column; from 1280px the frame of HomeDesktop and GroupDesktop, 32px gutters
// and the full width beside the sidebar.

/// From 1280px: the sidebar, and tab pages use the full width.
bool isWideLayout(BuildContext context) => SkLayout.of(context) == SkLayout.expanded;

/// Padding of a tab page. [bottom] is room under the content on phones and tablets (120 clears
/// the phone's floating add button).
EdgeInsets tabPagePadding(BuildContext context, {double bottom = 32}) =>
    isWideLayout(context) ? const EdgeInsets.fromLTRB(32, 28, 32, 40) : EdgeInsets.fromLTRB(16, 24, 16, bottom);

/// [slivers] laid out as one block inside [padding]: its sides around each, its top above the
/// first and its bottom below the last. (A page that scrolls with slivers, so only what's on
/// screen of a long list is built.)
List<Widget> paddedSlivers(EdgeInsets padding, List<Widget> slivers) => [
  for (final (i, sliver) in slivers.indexed)
    SliverPadding(
      padding: EdgeInsets.fromLTRB(
        padding.left,
        i == 0 ? padding.top : 0,
        padding.right,
        i == slivers.length - 1 ? padding.bottom : 0,
      ),
      sliver: sliver,
    ),
];

/// A tab page's content: the 640px column, or the full width from 1280px.
class TabPageWidth extends StatelessWidget {
  const TabPageWidth({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ContentWidth(maxWidth: isWideLayout(context) ? double.infinity : 640, child: child);
}

/// Cards in as many columns as fit [minWidth] each (at most [maxColumns]), dealt left to right
/// so cards of different heights pack without gaps. One column on phones.
class CardColumns extends StatelessWidget {
  const CardColumns({super.key, required this.children, this.minWidth = 360, this.maxColumns = 3, this.gap = 14});
  final List<Widget> children;
  final double minWidth;
  final int maxColumns;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final n = ((box.maxWidth + gap) / (minWidth + gap)).floor().clamp(1, maxColumns);
      Widget column(Iterable<Widget> cards) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in cards.indexed) ...[if (i > 0) SizedBox(height: gap), c],
        ],
      );
      if (n == 1) return column(children);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var col = 0; col < n; col++) ...[
            if (col > 0) SizedBox(width: gap),
            Expanded(child: column([for (var i = col; i < children.length; i += n) children[i]])),
          ],
        ],
      );
    },
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

  /// What [builder] gets for [value], or null when the skeleton or an error shows instead: for
  /// pages that lay the data out themselves (as slivers) and leave the rest to an AsyncBody.
  static T? dataOf<T>(AsyncValue<T> value) => switch (value) {
    AsyncData(:final value) => value,
    AsyncError() when !value.isLoading => null,
    _ => value.hasValue ? value.requireValue : null,
  };

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData(:final value) => builder(value),
      // Gone or never yours: trying again won't help, so offer a way out instead.
      AsyncError(:final error) when !value.isLoading && error is ApiException && error.code == 404 => EmptyState(
        glyph: 'search',
        title: "This isn't here",
        body: "${apiErrorMessage(error)}. It may have been deleted, or you're no longer part of it.",
        actionLabel: 'Go home',
        onAction: () => GoRouter.of(context).go('/home'),
      ),
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
