import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/copy/copy.dart';
import '../../core/data/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';

/// Renders one configured card. Each `type` maps to one reusable renderer; a type the app
/// doesn't know yet shows the dashed placeholder instead of breaking the dashboard.
typedef CardRenderer = Widget Function(AnalyticsCardOut card, String currency, String scope);

String Function(int) _fmt(String currency) =>
    (v) => money(v, currency);

Widget _trend(AnalyticsCardOut c, String currency, String scope) => TrendBars(
  headline: c.headline,
  bars: [for (final b in c.bars) (label: b.label, value: b.valueMinor, highlight: b.highlight)],
  formatTop: (v) => compactMoney(v, currency),
  formatTip: (b) => '${b.label}: ${money(b.value, currency)}',
);

Widget _breakdown(AnalyticsCardOut c, String currency, String scope) => c.rows.isEmpty
    ? Text('Nothing here yet.', style: SkText.body(13, 400, color: SkColors.ink2))
    : BreakdownBars(
        rows: [for (final r in c.rows) (label: r.label, value: r.valueMinor)],
        format: _fmt(currency),
        color: scope == 'personal'
            ? SkColors.personal
            : c.type == 'paid_by_member'
            ? SkColors.brand
            : SkPalette.chartBarAlt,
      );

Widget _split(AnalyticsCardOut c, String currency, String scope) {
  if (c.rows.length < 2) return AnalyticsPlaceholder(type: c.type);
  return SplitBar(
    a: (label: c.rows[0].label, value: c.rows[0].valueMinor),
    b: (label: c.rows[1].label, value: c.rows[1].valueMinor),
    format: _fmt(currency),
  );
}

Widget _stat(AnalyticsCardOut c, String currency, String scope) =>
    StatBlock(value: money(c.stat?.valueMinor ?? 0, currency), note: c.stat?.note);

const cardRenderers = <String, CardRenderer>{
  'spending_trend': _trend,
  'spending_by_category': _breakdown,
  'paid_by_member': _breakdown,
  'personal_vs_group': _split,
  'average_daily': _stat,
  'total_spend': _stat,
};

/// The dashboard: loops over the cards the API returns (from analytics_configuration).
class DashboardCards extends StatelessWidget {
  const DashboardCards({super.key, required this.dashboard});
  final DashboardOut dashboard;

  @override
  Widget build(BuildContext context) {
    final scope = dashboard.scope.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in dashboard.cards) ...[
          AnalyticsCard(
            title: c.title,
            period: c.periodLabel,
            child: (cardRenderers[c.type] ?? (c, _, _) => AnalyticsPlaceholder(type: c.type))(
              c,
              dashboard.currency,
              scope,
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (dashboard.cards.isEmpty)
          const EmptyState(glyph: 'chart', title: 'No cards', body: 'Use Edit layout to add some.'),
      ],
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
                      glyph: 'back',
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
