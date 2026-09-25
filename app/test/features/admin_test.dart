import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/design_system/design_system.dart';
import 'package:splitkit/features/admin/admin_dashboard_page.dart';
import 'package:splitkit/features/admin/admin_users_page.dart';
import 'package:splitkit/features/admin/admin_widgets.dart';
import 'package:splitkit/features/admin/audit_log_page.dart';

import '../fake_backend.dart';
import '../helpers.dart';

const desktop = Size(1440, 900);

/// The fake backend plus the admin endpoints (captured from the seeded API).
FakeBackend adminBackend() {
  final be = FakeBackend();
  be.get.addAll({
    '/api/v1/admin/dashboard': fixture('admin_dashboard'),
    '/api/v1/admin/users': fixture('admin_users'),
    '/api/v1/admin/audit': fixture('admin_audit'),
    '/api/v1/admin/sessions': fixture('admin_sessions'),
  });
  be.postResponses['/api/v1/admin/sessions'] = (201, fixture('admin_session_start'));
  return be;
}

Finder viewAsFor(String name) => find.byWidgetPredicate((w) => w is ViewAsButton && w.user.name == name);

Finder inTable(String text) => find.descendant(of: find.byType(AuditTable), matching: find.text(text));

void main() {
  setUpAll(loadFonts);

  group('fixtures parse with the generated client', () {
    test('dashboard', () {
      final d = AdminDashboardOut.fromJson(fixture('admin_dashboard'))!;
      expect((d.users, d.admins, d.expenses, d.expensesImported, d.settlements), (6, 1, 26, 13, 1));
      expect(d.recent.first.summary, 'Added “Dinner at Thalassa” · ₹1,800');
      expect(d.recent.firstWhere((e) => e.doneAs == AuditEntryOutDoneAsEnum.admin).actingAs?.name, 'Priya Nair');
    });

    test('users, audit, sessions and a started session', () {
      final users = AdminUsersPageOut.fromJson(fixture('admin_users'))!;
      expect(users.items.first.role, 'admin');
      expect(AuditPageOut.fromJson(fixture('admin_audit'))!.total, 7);
      expect(AdminSessionsPageOut.fromJson(fixture('admin_sessions'))!.items.single.target.name, 'Priya Nair');
      final start = AdminSessionStartOut.fromJson(fixture('admin_session_start'))!;
      expect((start.user.name, start.session.mode), ('Rahul Sharma', AdminSessionOutModeEnum.readOnly));
    });
  });

  testWidgets('admins get an Admin tab that opens the dashboard', (tester) async {
    await pumpApp(tester, backend: adminBackend());
    final nav = find.byType(BottomNav);
    expect(find.descendant(of: nav, matching: find.text('Admin')), findsOneWidget);
    await tester.tap(find.descendant(of: nav, matching: find.text('Admin')));
    await tester.pumpAndSettle();
    expect(find.byType(AdminDashboardPage), findsOneWidget);
    expect(find.text('View the app as a user'), findsOneWidget);
  });

  testWidgets('non-admins have no Admin tab and are sent home from /admin', (tester) async {
    final be = adminBackend();
    be.get['/api/v1/me'] = {...(be.get['/api/v1/me'] as Map<String, dynamic>), 'role': 'user'};
    await pumpApp(tester, backend: be, location: '/admin/users');
    expect(find.byType(AdminUsersPage), findsNothing);
    expect(find.descendant(of: find.byType(BottomNav), matching: find.text('Admin')), findsNothing);
    expect(be.gets.where((u) => u.path.startsWith('/api/v1/admin')), isEmpty);
  });

  testWidgets('desktop dashboard: totals, recent activity, system', (tester) async {
    await pumpApp(tester, backend: adminBackend(), size: desktop, location: '/admin');
    expect(find.text('Master account · every admin action is written to the audit log'), findsOneWidget);
    for (final text in ['26', '13 imported', '₹500 total', '1 admin', 'across 1 user']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(inTable('Added “Dinner at Thalassa” · ₹1,800'), findsOneWidget);
    expect(inTable('Ansh C → Priya'), findsOneWidget);
    expect(inTable('Tricount importer'), findsOneWidget);
    expect(inTable('Admin'), findsOneWidget); // the Done as chip, in words
    expect(inTable('Import'), findsOneWidget);
    expect(find.textContaining('PostgreSQL 16'), findsOneWidget);
    // The view-as picker lists people who can be viewed as: not the admin.
    expect(find.text('Open as Aman'), findsOneWidget);
  });

  testWidgets('activity tabs ask the audit log for that kind', (tester) async {
    final be = adminBackend();
    await pumpApp(tester, backend: be, size: desktop, location: '/admin');
    await tester.tap(find.text('Settlements').last);
    await tester.pumpAndSettle();
    final audit = be.gets.lastWhere((u) => u.path == '/api/v1/admin/audit');
    expect(audit.queryParametersAll['entity'], ['settlement']);
    await tester.tap(find.text('Users').last);
    await tester.pumpAndSettle();
    expect(be.gets.last.queryParametersAll['entity'], ['user', 'group', 'admin_session']);
  });

  testWidgets('Open as starts a read-only session through the view-as seam', (tester) async {
    final be = adminBackend();
    await pumpApp(tester, backend: be, size: desktop, location: '/admin');
    await tester.tap(find.text('Open as Aman'));
    await tester.pumpAndSettle();
    final (method, path, body) = be.writes.single;
    expect((method, path, body['mode']), ('POST', '/api/v1/admin/sessions', 'read_only'));
    final aman = (fixture('admin_users')['items'] as List).firstWhere((u) => u['name'] == 'Aman Verma');
    expect(body['target_user_id'], aman['id']);
    expect(find.text('View-as will open here'), findsOneWidget);
  });

  testWidgets('users table: counts, balances in words, selected user panel', (tester) async {
    await pumpApp(tester, backend: adminBackend(), size: desktop, location: '/admin/users');
    expect(find.text('6 users'), findsOneWidget);
    expect(find.text('owed ₹1,470'), findsNWidgets(2)); // Ansh's row and his panel
    expect(find.text('owes ₹3,408'), findsOneWidget); // Priya
    expect(find.text('ADMIN', findRichText: true), findsNothing);
    expect(find.textContaining('ADMIN', findRichText: true), findsOneWidget);
    // Admins can't be viewed as: no button on Ansh's row, five for everyone else.
    expect(viewAsFor('Ansh C'), findsNothing);
    expect(find.byType(ViewAsButton), findsNWidgets(5));
    expect(find.text("Admins can't be viewed as."), findsOneWidget);

    await tester.tap(find.text('rahul.sharma@example.com'));
    await tester.pumpAndSettle();
    expect(find.text('View app as Rahul'), findsOneWidget);
    expect(find.text('owed ₹4,518'), findsNWidgets(2));
  });

  testWidgets('View as on a row goes through the seam and says so', (tester) async {
    final be = adminBackend();
    await pumpApp(tester, backend: be, size: desktop, location: '/admin/users');
    await tester.tap(viewAsFor('Rahul Sharma'));
    await tester.pumpAndSettle();
    final rahul = (fixture('admin_users')['items'] as List).firstWhere((u) => u['name'] == 'Rahul Sharma');
    expect(be.writes.single.$3, {'target_user_id': rahul['id'], 'mode': 'read_only'});
    expect(find.text('View-as will open here'), findsOneWidget);
  });

  testWidgets('user search and role filter go to the API', (tester) async {
    final be = adminBackend();
    await pumpApp(tester, backend: be, size: desktop, location: '/admin/users?q=pri');
    expect(be.gets.lastWhere((u) => u.path == '/api/v1/admin/users').queryParameters['q'], 'pri');
    await tester.enterText(find.byType(TextField), 'rahul');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(be.gets.lastWhere((u) => u.path == '/api/v1/admin/users').queryParameters['q'], 'rahul');
    await tester.tap(find.text('Admins'));
    await tester.pumpAndSettle();
    expect(be.gets.last.queryParameters, containsPair('role', 'admin'));
  });

  testWidgets('phone users list: row taps open the user in a sheet', (tester) async {
    await pumpApp(tester, backend: adminBackend(), location: '/admin/users');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('priya.nair@example.com'));
    await tester.pumpAndSettle();
    expect(find.text('View app as Priya'), findsOneWidget);
  });

  testWidgets('audit log page: entries, filters, paging', (tester) async {
    final be = adminBackend();
    await pumpApp(tester, backend: be, size: desktop, location: '/admin/audit');
    expect(find.byType(AuditLogPage), findsOneWidget);
    expect(find.text('Showing 7 of 7'), findsOneWidget);
    expect(inTable('Joined via invite link'), findsOneWidget);
    expect(find.text('Show more'), findsNothing);
    await tester.tap(find.text('Admin only'));
    await tester.pumpAndSettle();
    expect(be.gets.last.queryParameters, containsPair('admin_only', 'true'));
    await tester.tap(find.text('Imports'));
    await tester.pumpAndSettle();
    expect(be.gets.last.queryParametersAll['entity'], ['import_batch']);
  });

  testWidgets('phone dashboard lays out without overflow', (tester) async {
    await pumpApp(tester, backend: adminBackend(), location: '/admin');
    expect(tester.takeException(), isNull);
    expect(find.text('Recent activity'), findsOneWidget);
    // Compact rows: summary over "who · where · when".
    expect(find.textContaining('Rahul Sharma · Goa Trip · '), findsOneWidget);
  });

  for (final path in ['/admin', '/admin/users', '/admin/audit']) {
    testWidgets('tablet $path lays out without overflow', (tester) async {
      await pumpApp(tester, backend: adminBackend(), size: const Size(834, 1112), location: path);
      expect(tester.takeException(), isNull);
      expect(find.byType(NavRail), findsOneWidget);
    });
  }

  test('copy helpers', () {
    final now = DateTime(2026, 9, 23, 22);
    expect(auditWhen(DateTime(2026, 9, 21, 10), now: now), 'Mon 21 Sep');
    expect(auditWhen(DateTime(2026, 9, 22, 10), now: now), 'Yesterday');
    expect(netLabel([]), 'settled up');
    expect(netLabel([MoneyTotal(amountMinor: -85000, currency: 'INR')]), 'owes ₹850');
    expect(lastActiveLabel(null), 'Never');
  });
}
