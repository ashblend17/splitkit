import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'admin_dashboard_page.dart' show activityTabs;
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// The full audit log (the dashboard's "Audit log explorer"): every write, newest first,
/// with who acted as whom.
class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  static const _page = 50;
  String _entities = '';
  bool _adminOnly = false;
  int _pages = 1;

  AuditQuery _query(int page) => (entities: _entities, adminOnly: _adminOnly, limit: _page, offset: page * _page);

  void _filter(void Function() change) => setState(() {
    change();
    _pages = 1;
  });

  @override
  Widget build(BuildContext context) {
    // Pages load one after another; each is its own cached request.
    final pages = [for (var i = 0; i < _pages; i++) ref.watch(adminAuditProvider(_query(i)))];
    final first = pages.first;
    final loaded = [for (final p in pages) ...?p.value?.items];
    final last = pages.last;
    return AdminPage(
      children: [
        AdminTitle(
          'Audit log',
          crumb: 'Admin',
          onCrumb: () => context.go('/admin'),
          subtitle: Text(
            'Every change, newest first. Admin means an admin made it while viewing as that person.',
            style: SkText.body(13, 400, color: SkColors.ink2),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, entities) in activityTabs)
              SkFilterChip(
                label: label,
                selected: _entities == entities,
                onTap: () => _filter(() => _entities = entities),
              ),
            SkFilterChip(
              label: 'Admin only',
              selected: _adminOnly,
              onTap: () => _filter(() => _adminOnly = !_adminOnly),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncBody(
          value: first,
          onRetry: () => ref.invalidate(adminAuditProvider),
          skeletonRows: 6,
          builder: (p) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkCard(padding: EdgeInsets.zero, child: AuditTable(entries: loaded)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing ${loaded.length} of ${p.total}',
                      style: SkText.body(13, 400, color: SkColors.ink2),
                    ),
                  ),
                  if (last.isLoading && _pages > 1)
                    const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (last.value?.hasMore ?? false)
                    SkButton(
                      'Show more',
                      variant: SkButtonVariant.secondary,
                      size: SkButtonSize.small,
                      onPressed: () => setState(() => _pages++),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
