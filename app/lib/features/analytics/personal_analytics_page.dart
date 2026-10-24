import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/data/providers.dart';
import '../../core/integrations.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'cards.dart';

/// Screen 14, Personal's Insights tab: your dashboard, rendered by looping over your
/// analytics layout. Switching period keeps the cards up, dimmed, until the new figures come,
/// and then the bars and amounts move to them.
class PersonalAnalyticsPage extends ConsumerStatefulWidget {
  const PersonalAnalyticsPage({super.key});

  @override
  ConsumerState<PersonalAnalyticsPage> createState() => _PersonalAnalyticsPageState();
}

class _PersonalAnalyticsPageState extends ConsumerState<PersonalAnalyticsPage> {
  String _period = 'month';

  /// The last dashboard shown, kept up while another period loads.
  DashboardOut? _shown;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(personalDashboardProvider(_period));
    final groupShare = ref.watch(integrationsProvider).groupShareInPersonal;
    // Remembered as it's drawn, not a state change: nothing else depends on it.
    if (dashboard.hasValue) _shown = dashboard.value;
    final failed = dashboard.hasError && !dashboard.isLoading;
    final kept = failed ? null : _shown;
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
            padding: tabPagePadding(context),
            children: [
              TabPageWidth(
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
                    // A phone's width at most, so the three tabs don't stretch across a desktop.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: PeriodTabs(
                          value: _period,
                          onChanged: (p) => setState(() => _period = p),
                          selectedColor: SkColors.personalInk,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (kept == null)
                      AsyncBody(
                        value: dashboard,
                        onRetry: () => ref.invalidate(personalDashboardProvider(_period)),
                        builder: (d) => DashboardCards(dashboard: d, hideTypes: {if (!groupShare) 'personal_vs_group'}),
                      )
                    else
                      AnimatedOpacity(
                        opacity: dashboard.hasValue ? 1 : 0.55,
                        duration: SkMotion.of(context, SkMotion.quick),
                        child: DashboardCards(dashboard: kept, hideTypes: {if (!groupShare) 'personal_vs_group'}),
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
    shape: StadiumBorder(side: BorderSide(color: SkColors.line)),
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

/// Week / Month / Year, on a thumb that slides to the one picked.
class PeriodTabs extends StatelessWidget {
  const PeriodTabs({super.key, required this.value, required this.onChanged, Color? selectedColor})
    : _selectedColor = selectedColor;
  final String value;
  final ValueChanged<String> onChanged;

  /// The selected tab's label: brand in groups, personal in Insights.
  final Color? _selectedColor;
  Color get selectedColor => _selectedColor ?? SkColors.brandInk;

  @override
  Widget build(BuildContext context) => SkSegmented(
    options: const [('week', 'Week'), ('month', 'Month'), ('year', 'Year')],
    value: value,
    onChanged: onChanged,
    selectedColor: selectedColor,
  );
}
