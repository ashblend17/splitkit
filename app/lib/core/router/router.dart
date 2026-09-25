import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../features/personal/personal_history_page.dart';
import '../../features/personal/personal_page.dart';
import '../../features/profile/categories_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/shell/app_shell.dart';
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
    initialLocation: '/home',
    refreshListenable: listenable,
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
        return from != null && from.startsWith('/') && !from.startsWith('/splash') ? from : '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/gallery', builder: (_, _) => const ComponentsGalleryPage()),
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
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/personal',
                builder: (_, _) => const PersonalPage(),
                routes: [GoRoute(path: 'history', builder: (_, _) => const PersonalHistoryPage())],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfilePage(),
                routes: [
                  GoRoute(path: 'analytics', builder: (_, _) => const PersonalAnalyticsPage()),
                  GoRoute(path: 'categories', builder: (_, _) => const CategoriesPage()),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/expenses/new',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => AddExpensePage(groupId: s.uri.queryParameters['group']),
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
