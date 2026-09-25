import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/providers.dart';
import '../../core/theme/theme.dart';
import '../common/common.dart';
import 'cards.dart';
import 'personal_analytics_page.dart';

/// Screen 15: a group's dashboard, from your group analytics layout.
class GroupAnalyticsPage extends ConsumerWidget {
  const GroupAnalyticsPage({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupProvider(groupId));
    final dashboard = ref.watch(groupDashboardProvider(groupId));
    Widget tab(String label, {bool on = false, VoidCallback? onTap}) => Semantics(
      selected: on,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: on ? SkColors.brand : Colors.transparent, width: 2.5)),
          ),
          alignment: Alignment.center,
          child: Text(label, style: SkText.body(14, on ? 700 : 600, color: on ? SkColors.brandInk : SkColors.ink2)),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: HeaderIconButton(
                            glyph: 'back',
                            label: 'Back to ${group.value?.name ?? 'group'}',
                            onPressed: () => context.go('/groups/$groupId'),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  '${group.value?.name ?? ''} analytics',
                                  style: SkText.display(20, 700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (dashboard.value?.subtitle != null)
                                Text(dashboard.value!.subtitle!, style: SkText.body(12, 400, color: SkColors.ink2)),
                            ],
                          ),
                        ),
                        EditLayoutButton(onPressed: () => showEditLayoutSheet(context, 'group')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: SkColors.line)),
                    ),
                    child: Row(
                      children: [
                        tab('Expenses', onTap: () => context.go('/groups/$groupId')),
                        const SizedBox(width: 4),
                        tab('Balances', onTap: () => context.go('/groups/$groupId/balances')),
                        const SizedBox(width: 4),
                        tab('Analytics', on: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AsyncBody(
                    value: dashboard,
                    onRetry: () => ref.invalidate(groupDashboardProvider(groupId)),
                    builder: (d) => DashboardCards(dashboard: d),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
