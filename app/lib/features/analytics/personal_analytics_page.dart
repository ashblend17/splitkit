import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/integrations.dart';
import '../../core/theme/theme.dart';
import '../common/common.dart';
import 'cards.dart';

/// Screen 14, Personal's Insights tab: your dashboard, rendered by looping over your
/// analytics layout.
class PersonalAnalyticsPage extends ConsumerStatefulWidget {
  const PersonalAnalyticsPage({super.key});

  @override
  ConsumerState<PersonalAnalyticsPage> createState() => _PersonalAnalyticsPageState();
}

class _PersonalAnalyticsPageState extends ConsumerState<PersonalAnalyticsPage> {
  String _period = 'month';

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(personalDashboardProvider(_period));
    final groupShare = ref.watch(integrationsProvider).groupShareInPersonal;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: SkColors.personal,
          onRefresh: () async {
            ref.invalidate(personalDashboardProvider);
            await ref.read(personalDashboardProvider(_period).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Semantics(header: true, child: Text('Insights', style: SkText.title))),
                        EditLayoutButton(onPressed: () => showEditLayoutSheet(context, 'personal')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PeriodTabs(
                      value: _period,
                      onChanged: (p) => setState(() => _period = p),
                      selectedColor: SkColors.personalInk,
                    ),
                    const SizedBox(height: 14),
                    AsyncBody(
                      value: dashboard,
                      onRetry: () => ref.invalidate(personalDashboardProvider(_period)),
                      builder: (d) => DashboardCards(dashboard: d, hideTypes: {if (!groupShare) 'personal_vs_group'}),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditLayoutButton extends StatelessWidget {
  const EditLayoutButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: SkColors.surface,
    shape: const StadiumBorder(side: BorderSide(color: SkColors.line)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: Text('Edit layout', style: SkText.body(13, 600)),
      ),
    ),
  );
}

/// Week / Month / Year.
class PeriodTabs extends StatelessWidget {
  const PeriodTabs({super.key, required this.value, required this.onChanged, this.selectedColor = SkColors.brandInk});
  final String value;
  final ValueChanged<String> onChanged;

  /// The selected tab's label: brand in groups, personal in Insights.
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    Widget tab(String key, String label) {
      final on = key == value;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: GestureDetector(
            onTap: () => onChanged(key),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: on ? SkColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: on
                    ? const [BoxShadow(color: SkPalette.shadowInk, blurRadius: 3, offset: Offset(0, 1))]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(label, style: SkText.body(13, on ? 700 : 600, color: on ? selectedColor : SkColors.ink2)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: SkColors.sunken, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          tab('week', 'Week'),
          const SizedBox(width: 4),
          tab('month', 'Month'),
          const SizedBox(width: 4),
          tab('year', 'Year'),
        ],
      ),
    );
  }
}
