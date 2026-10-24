import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';

/// What a renderer gets besides its card: the dashboard's currency, its colours (personal or
/// brand), and the glyph of a category, by the name a breakdown row has.
typedef CardContext = ({String currency, NavAccent accent, String? Function(String label) glyphOf});

/// Renders one configured card. Each `type` maps to one reusable renderer; a type the app
/// doesn't know yet shows the dashed placeholder instead of breaking the dashboard.
typedef CardRenderer = Widget Function(AnalyticsCardOut card, CardContext ctx);

String Function(int) _fmt(String currency) =>
    (v) => money(v, currency);

Widget _trend(AnalyticsCardOut c, CardContext ctx) => TrendBars(
  headline: c.headline,
  accent: ctx.accent,
  bars: [for (final b in c.bars) (label: b.label, value: b.valueMinor, highlight: b.highlight)],
  formatTop: (v) => compactMoney(v, ctx.currency),
  formatTip: (b) => '${b.label}: ${money(b.value, ctx.currency)}',
);

Widget _breakdown(AnalyticsCardOut c, CardContext ctx) => c.rows.isEmpty
    ? const _Nothing()
    : BreakdownBars(
        rows: [for (final r in c.rows) (label: r.label, value: r.valueMinor)],
        format: _fmt(ctx.currency),
        accent: ctx.accent,
        glyphs: c.type == 'spending_by_category' ? ctx.glyphOf : null,
        color: ctx.accent == NavAccent.personal
            ? null
            : c.type == 'paid_by_member'
            ? SkColors.brand
            : SkPalette.chartBarAlt,
      );

Widget _split(AnalyticsCardOut c, CardContext ctx) {
  if (c.rows.length < 2) return AnalyticsPlaceholder(type: c.type);
  return SplitBar(
    a: (label: c.rows[0].label, value: c.rows[0].valueMinor),
    b: (label: c.rows[1].label, value: c.rows[1].valueMinor),
    format: _fmt(ctx.currency),
    accent: ctx.accent,
  );
}

Widget _stat(AnalyticsCardOut c, CardContext ctx) => StatBlock(
  value: money(c.stat?.valueMinor ?? 0, ctx.currency),
  amount: c.stat?.valueMinor ?? 0,
  format: _fmt(ctx.currency),
  note: c.stat?.note,
);

/// The share of income kept: the rate as the headline ("23%", "−13%" with a typographic minus,
/// or "—" with no income) and what was saved of what came in.
Widget _savingsRate(AnalyticsCardOut c, CardContext ctx) {
  final headline = c.headline;
  final rate = headline == null || headline.isEmpty
      ? '—'
      : headline.startsWith('-')
      ? '$minus${headline.substring(1)}'
      : headline;
  return StatBlock(value: rate, note: c.stat?.note);
}

/// Needs against wants, from the categories' kind (never below zero), and what isn't sorted
/// either way, when there's some. No headline.
Widget _needWant(AnalyticsCardOut c, CardContext ctx) {
  int row(String label) => c.rows.where((r) => r.label == label).fold(0, (a, r) => a + r.valueMinor);
  final needs = row('Needs'), wants = row('Wants'), unsorted = row('Not sorted');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      SplitBar(
        a: (label: 'Needs', value: needs < 0 ? 0 : needs),
        b: (label: 'Wants', value: wants < 0 ? 0 : wants),
        format: _fmt(ctx.currency),
        accent: ctx.accent,
      ),
      if (unsorted > 0) ...[
        const SizedBox(height: 10),
        Text('${money(unsorted, ctx.currency)} not sorted', style: SkText.body(13, 400, color: SkColors.ink2)),
      ],
    ],
  );
}

const cardRenderers = <String, CardRenderer>{
  'spending_trend': _trend,
  'spending_by_category': _breakdown,
  'spending_by_account': _breakdown,
  'spending_by_channel': _breakdown,
  'top_merchants': _breakdown,
  'paid_by_member': _breakdown,
  'personal_vs_group': _split,
  'average_daily': _stat,
  'total_spend': _stat,
  'savings_rate': _savingsRate,
  'need_vs_want': _needWant,
};

/// Each card type's tile in its header.
const cardGlyphs = {
  'spending_trend': 'chart',
  'spending_by_category': 'grid',
  'spending_by_account': 'wallet',
  'spending_by_channel': 'swap',
  'top_merchants': 'shopping',
  'paid_by_member': 'user',
  'personal_vs_group': 'groups',
  'average_daily': 'calendar',
  'total_spend': 'chart',
  'savings_rate': 'target',
  'need_vs_want': 'shield',
};

/// Personal's breakdowns that sit side by side, in one carousel (where the first of them is in
/// your layout).
const carouselTypes = {'spending_by_category', 'spending_by_account', 'spending_by_channel'};

class _Nothing extends StatelessWidget {
  const _Nothing();

  @override
  Widget build(BuildContext context) => Text('Nothing here yet.', style: SkText.body(13, 400, color: SkColors.ink2));
}

/// The dashboard: loops over the cards the API returns (from analytics_configuration). Each
/// comes in a moment after the one before; in Personal the three breakdowns share a carousel.
class DashboardCards extends ConsumerWidget {
  const DashboardCards({super.key, required this.dashboard, this.hideTypes = const {}});
  final DashboardOut dashboard;

  /// Card types not shown here, though they stay in the layout (an integration that's off).
  final Set<String> hideTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personal = dashboard.scope.value == 'personal';
    final icons = {for (final c in ref.watch(allCategoriesProvider).value ?? const <CategoryOut>[]) c.label: c.icon};
    final ctx = (
      currency: dashboard.currency,
      accent: personal ? NavAccent.personal : NavAccent.brand,
      glyphOf: (String label) => icons[label],
    );
    final cards = [for (final c in dashboard.cards) if (!hideTypes.contains(c.type)) c];
    if (cards.isEmpty) return const EmptyState(glyph: 'chart', title: 'No cards', body: 'Use Edit layout to add some.');
    final together = personal ? [for (final c in cards) if (carouselTypes.contains(c.type)) c] : const <AnalyticsCardOut>[];
    // Runs of cards (in columns where there's room) with the carousel, across the page, between.
    final sections = <List<Widget>>[[]];
    var shown = 0;
    for (final c in cards) {
      if (together.length > 1 && together.contains(c)) {
        if (c != together.first) continue;
        sections
          ..add([
            Reveal(
              key: const ValueKey('breakdowns'),
              index: shown++,
              child: BreakdownCarousel(accent: ctx.accent, children: [for (final t in together) _card(t, ctx)]),
            ),
          ])
          ..add([]);
      } else {
        sections.last.add(Reveal(key: ValueKey(c.id), index: shown++, child: _card(c, ctx)));
      }
    }
    // A run shorter than a row of columns spreads across it, rather than leaving gaps beside it.
    final parts = [
      for (final (i, s) in sections.indexed)
        if (s.isNotEmpty) i.isOdd ? s.single : CardColumns(maxColumns: s.length.clamp(1, 3), children: s),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, p) in parts.indexed) ...[if (i > 0) const SizedBox(height: 14), p],
      ],
    );
  }

  static Widget _card(AnalyticsCardOut c, CardContext ctx) {
    if (c.type == 'spending_by_category' && c.averages != null) {
      return _CategoryCard(key: ValueKey(c.id), card: c, ctx: ctx);
    }
    return AnalyticsCard(
      key: ValueKey(c.id),
      title: c.title,
      period: c.periodLabel,
      glyph: cardGlyphs[c.type],
      accent: ctx.accent,
      child: (cardRenderers[c.type] ?? (c, _) => AnalyticsPlaceholder(type: c.type))(c, ctx),
    );
  }
}

/// Spending by category, with Total (what each category came to in the period) or Average (each
/// category's usual week or month, next to the one under way).
class _CategoryCard extends StatefulWidget {
  const _CategoryCard({super.key, required this.card, required this.ctx});
  final AnalyticsCardOut card;
  final CardContext ctx;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _average = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.card, ctx = widget.ctx;
    final a = c.averages!;
    final unit = a.unit.value;
    final Widget body = !_average
        ? _breakdown(c, ctx)
        : a.rows.isEmpty
        ? Text(
            "Each category's usual $unit shows here once there's a whole $unit before this one.",
            style: SkText.body(13, 400, color: SkColors.ink2),
          )
        : AverageBars(
            rows: [for (final r in a.rows) (label: r.label, average: r.averageMinor, now: r.nowMinor)],
            format: _fmt(ctx.currency),
            unit: unit,
            nowLabel: a.nowLabel,
            glyphs: ctx.glyphOf,
            accent: ctx.accent,
          );
    final duration = SkMotion.of(context, SkMotion.quick);
    return AnalyticsCard(
      title: c.title,
      period: _average ? a.label : c.periodLabel,
      glyph: cardGlyphs[c.type],
      accent: ctx.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SkSegmented(
            options: const [(false, 'Total'), (true, 'Average')],
            value: _average,
            onChanged: (v) => setState(() => _average = v),
            selectedColor: ctx.accent.ink,
            height: 30,
            fontSize: 12,
          ),
          const SizedBox(height: 14),
          AnimatedSize(
            duration: duration,
            curve: SkMotion.curve,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: duration,
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
              child: KeyedSubtree(key: ValueKey(_average), child: body),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reorder, remove and add dashboard cards; saved as your own layout for this scope.
Future<void> showEditLayoutSheet(BuildContext context, String scope) => showAppBottomSheet<void>(
  context,
  title: 'Edit layout',
  child: _EditLayout(scope: scope),
);

class _EditLayout extends ConsumerStatefulWidget {
  const _EditLayout({required this.scope});
  final String scope;

  @override
  ConsumerState<_EditLayout> createState() => _EditLayoutState();
}

class _EditLayoutState extends ConsumerState<_EditLayout> {
  List<LayoutCard>? _cards;
  bool _busy = false;

  bool _same(LayoutCard a, LayoutCard b) => a.source_ == b.source_ && a.type == b.type;

  Future<void> _save(Future<LayoutOut?> Function() request) async {
    setState(() => _busy = true);
    try {
      await request();
      ref.invalidate(layoutProvider(widget.scope));
      widget.scope == 'personal' ? ref.invalidate(personalDashboardProvider) : ref.invalidate(groupDashboardProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, apiErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(layoutProvider(widget.scope));
    return AsyncBody(
      value: layout,
      onRetry: () => ref.invalidate(layoutProvider(widget.scope)),
      skeletonRows: 2,
      builder: (l) {
        final cards = _cards ??= [...l.cards];
        final missing = l.available.where((a) => !cards.any((c) => _same(a, c))).toList();
        final api = ref.read(apiProvider).analytics;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, c) in cards.indexed)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(child: Text(c.title, style: SkText.body(15, 600))),
                    HeaderIconButton(
                      glyph: 'up',
                      label: 'Move ${c.title} up',
                      onPressed: i == 0 ? null : () => setState(() => cards.insert(i - 1, cards.removeAt(i))),
                      color: i == 0 ? SkColors.lineStrong : SkColors.ink,
                    ),
                    HeaderIconButton(
                      glyph: 'close',
                      label: 'Remove ${c.title}',
                      onPressed: () => setState(() => cards.removeAt(i)),
                      color: SkColors.owe,
                    ),
                  ],
                ),
              ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Overline('Add a card'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in missing)
                    SelectableChip(
                      label: m.title,
                      icon: 'plus',
                      selected: false,
                      onTap: () => setState(() => cards.add(m)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            SkButton(
              'Save layout',
              size: SkButtonSize.large,
              expand: true,
              onPressed: _busy ? null : () => _save(() => api.saveLayout(widget.scope, LayoutIn(cards: cards))),
            ),
            if (l.customised) ...[
              const SizedBox(height: 8),
              SkButton(
                'Reset to default',
                variant: SkButtonVariant.ghost,
                expand: true,
                onPressed: _busy ? null : () => _save(() => api.resetLayout(widget.scope)),
              ),
            ],
          ],
        );
      },
    );
  }
}
