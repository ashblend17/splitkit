import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/theme/theme.dart';
import '../common/common.dart';
import 'cards.dart';
import 'personal_analytics_page.dart';

/// Screen 15, a group's Analytics tab: its dashboard, from your group analytics layout. Shown
/// under the group's header and tabs (GroupDetailPage).
class GroupAnalyticsTab extends ConsumerWidget {
  const GroupAnalyticsTab({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(groupDashboardProvider(groupId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                dashboard.value?.subtitle ?? '',
                style: SkText.body(13, 400, color: SkColors.ink2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            EditLayoutButton(onPressed: () => showEditLayoutSheet(context, 'group')),
          ],
        ),
        const SizedBox(height: 14),
        AsyncBody(
          value: dashboard,
          onRetry: () => ref.invalidate(groupDashboardProvider(groupId)),
          builder: (d) => DashboardCards(dashboard: d),
        ),
      ],
    );
  }
}
