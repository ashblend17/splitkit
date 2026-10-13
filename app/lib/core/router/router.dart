import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_dashboard_page.dart';
import '../../features/admin/admin_users_page.dart';
import '../../features/admin/audit_log_page.dart';
import '../../features/analytics/group_analytics_page.dart';
import '../../features/analytics/personal_analytics_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/expenses/add_expense_page.dart';
import '../../features/expenses/expense_detail_page.dart';
import '../../features/gallery/components_gallery_page.dart';
import '../../features/groups/group_balances_page.dart';
import '../../features/groups/group_detail_page.dart';
import '../../features/groups/group_list_page.dart';
import '../../features/groups/group_trash_page.dart';
import '../../features/home/home_page.dart';
import '../../features/import_tricount/import_done_page.dart';
import '../../features/import_tricount/import_review_page.dart';
import '../../features/import_tricount/import_upload_page.dart';
import '../../features/tricount_sync/tricount_sync_page.dart';
import '../../features/personal/personal_history_page.dart';
import '../../features/personal/personal_page.dart';
import '../../features/profile/categories_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/shell/app_mode.dart';
import '../../features/sms/sms_setup_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/not_found_page.dart';
import '../../features/shell/splash_page.dart';
import '../session/session.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Re-runs redirects whenever the session changes (login, logout, 401).
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _SessionListenable(ref);
  ref.onDispose(listenable.dispose);
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: homeOf(ref.read(savedAppModeProvider)),
    refreshListenable: listenable,
    errorBuilder: (_, _) => const NotFoundPage(),
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.uri.path;
      const public = {'/login', '/register', '/gallery'};
      // Where to go once the session is known: keep deep links through the splash and login.
      final from = state.uri.queryParameters['from'];
      final here = path == '/splash' || path == '/login' ? from : state.uri.toString();
      String withFrom(String to) => here == null || here == '/' ? to : '$to?from=${Uri.encodeComponent(here)}';

      if (!session.hasValue) return path == '/splash' ? null : withFrom('/splash');
      final signedIn = session.value != null;
      if (!signedIn) {
        if (public.contains(path)) return null;
        return withFrom('/login');
      }
      if (path == '/login' || path == '/register' || path == '/splash' || path == '/') {
        return from != null && from.startsWith('/') && !from.startsWith('/splash')
            ? from
            : homeOf(ref.read(appModeProvider));
      }
      // The admin area is for admins only (the API refuses everyone else too).
      if ((path == '/admin' || path.startsWith('/admin/')) && !session.value!.isAdmin) {
        return homeOf(ref.read(appModeProvider));
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/gallery', builder: (_, _) => const ComponentsGalleryPage()),
      // Pages that moved into Personal's own tabs.
      GoRoute(path: '/personal/history', redirect: (_, _) => '/personal/transactions'),
      GoRoute(path: '/profile/history', redirect: (_, _) => '/personal/transactions'),
      GoRoute(path: '/profile/analytics', redirect: (_, _) => '/personal/insights'),
      StatefulShellRoute.indexedStack(
        builder: (_, state, shell) => AppShell(shell: shell, location: state.uri.path),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomePage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                builder: (_, _) => const GroupListPage(),
                routes: [
                  GoRoute(
                    path: ':gid',
                    builder: (_, s) => GroupDetailPage(groupId: s.pathParameters['gid']!),
                    routes: [
                      GoRoute(
                        path: 'balances',
                        builder: (_, s) => GroupBalancesPage(groupId: s.pathParameters['gid']!),
                      ),
                      GoRoute(
                        path: 'deleted',
                        builder: (_, s) => GroupTrashPage(groupId: s.pathParameters['gid']!),
                      ),
                      GoRoute(
                        path: 'analytics',
                        builder: (_, s) => GroupAnalyticsPage(groupId: s.pathParameters['gid']!),
                      ),
                      // Tricount sync (deletable module: features/tricount_sync).
                      GoRoute(
                        path: 'tricount',
                        builder: (_, s) => TricountSyncPage(groupId: s.pathParameters['gid']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Personal's tabs: Overview, Transactions, Insights. AppShell's keys follow this order.
          StatefulShellBranch(
            routes: [GoRoute(path: '/personal', builder: (_, _) => const PersonalPage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/personal/transactions',
                // ?account=: an account's entries (from Overview's Accounts).
                builder: (_, s) => PersonalHistoryPage(account: s.uri.queryParameters['account']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/personal/insights', builder: (_, _) => const PersonalAnalyticsPage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfilePage(),
                routes: [
                  GoRoute(path: 'categories', builder: (_, _) => const CategoriesPage()),
                  // Bank SMS, Android (features/sms).
                  GoRoute(
                    path: 'sms',
                    builder: (_, _) => const SmsSetupPage(),
                    routes: [GoRoute(path: 'skipped', builder: (_, _) => const SmsSkippedPage())],
                  ),
                  // Tricount import (deletable module: features/import_tricount).
                  GoRoute(
                    path: 'import',
                    builder: (_, _) => const ImportUploadPage(),
                    routes: [
                      GoRoute(path: 'review', builder: (_, _) => const ImportReviewPage()),
                      GoRoute(
                        path: 'done/:bid',
                        builder: (_, s) => ImportDonePage(batchId: s.pathParameters['bid']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Admin (screens 16 and 17, plus the audit log). Last, so the branch index matches
          // AppShell's keys; non-admins never see its tab and are redirected away.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                builder: (_, _) => const AdminDashboardPage(),
                routes: [
                  GoRoute(
                    path: 'users',
                    builder: (_, s) => AdminUsersPage(initialQuery: s.uri.queryParameters['q'] ?? ''),
                  ),
                  GoRoute(path: 'audit', builder: (_, _) => const AuditLogPage()),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/expenses/new',
        parentNavigatorKey: _rootKey,
        // ?from_txn=<id>: split one of your personal entries, linked to it.
        builder: (_, s) =>
            AddExpensePage(groupId: s.uri.queryParameters['group'], fromTxnId: s.uri.queryParameters['from_txn']),
      ),
      GoRoute(
        path: '/expenses/:eid',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ExpenseDetailPage(expenseId: s.pathParameters['eid']!),
        routes: [
          GoRoute(
            path: 'edit',
            parentNavigatorKey: _rootKey,
            builder: (_, s) => AddExpensePage(editExpenseId: s.pathParameters['eid']),
          ),
        ],
      ),
    ],
  );
});
