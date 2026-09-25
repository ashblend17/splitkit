import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/session/session.dart';

// Admin data comes straight from the API (never from the synced local data): it spans every
// user, and only admins can read it.

/// The generated admin client on the signed-in admin's token.
final adminApiProvider = Provider<AdminApi>((ref) => AdminApi(ref.watch(apiProvider).client));

/// Awaits an admin call. A 401 ends the session; a null body counts as an error.
Future<T> _fetch<T>(Ref ref, Future<T?> request) async {
  try {
    final result = await request;
    if (result == null) throw ApiException(500, 'Empty response');
    return result;
  } on ApiException catch (e) {
    if (e.code == 401) await ref.read(sessionProvider.notifier).expire();
    rethrow;
  }
}

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboardOut>(
  (ref) => _fetch(ref, ref.watch(adminApiProvider).adminDashboard()),
);

/// Search text and role (`user`, `admin` or null for any).
typedef AdminUsersQuery = ({String q, String? role});

final adminUsersProvider = FutureProvider.autoDispose.family<AdminUsersPageOut, AdminUsersQuery>(
  (ref, query) => _fetch(
    ref,
    ref
        .watch(adminApiProvider)
        .listAdminUsers(q: query.q.trim().isEmpty ? null : query.q.trim(), role: query.role, limit: 200),
  ),
);

/// Which audit entries to show. [entities] is a comma-separated list of entity kinds
/// (`expense,settlement`); empty means every kind. A string, not a list, so equal queries
/// share one provider.
typedef AuditQuery = ({String entities, bool adminOnly, int limit, int offset});

final adminAuditProvider = FutureProvider.autoDispose.family<AuditPageOut, AuditQuery>(
  (ref, query) => _fetch(
    ref,
    ref
        .watch(adminApiProvider)
        .listAuditLog(
          entity: query.entities.isEmpty ? null : query.entities.split(','),
          adminOnly: query.adminOnly ? true : null,
          limit: query.limit,
          offset: query.offset,
        ),
  ),
);
