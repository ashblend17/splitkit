import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitkit/features/common/common.dart';

import '../fake_backend.dart';
import '../helpers.dart';

const desktop = Size(1440, 900);

Finder _remove(String name) =>
    find.byWidgetPredicate((w) => w is HeaderIconButton && w.label == 'Remove $name');

Map<String, dynamic> _user(FakeBackend be, String name) =>
    ((be.goa['members'] as List).firstWhere((m) => m['user']['name'] == name) as Map)['user'] as Map<String, dynamic>;

void main() {
  setUpAll(loadFonts);

  testWidgets('the owner can remove someone, after saying yes', (tester) async {
    final be = FakeBackend();
    final rahul = _user(be, 'Rahul Sharma');
    final path = '/api/v1/groups/${be.goa['id']}/members/${rahul['id']}';
    await pumpApp(tester, backend: be, size: desktop, location: '/groups/${be.goa['id']}');
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    await tester.tap(_remove('Rahul Sharma'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Rahul from Goa Trip?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect((be.writes.last.$1, be.writes.last.$2), ('DELETE', path));
    expect(find.text('Rahul is no longer in Goa Trip'), findsOneWidget);
  });

  testWidgets('someone who still owes is refused with the reason', (tester) async {
    final be = FakeBackend();
    final rahul = _user(be, 'Rahul Sharma');
    be.postResponses['/api/v1/groups/${be.goa['id']}/members/${rahul['id']}'] = (409, {
      'error': {'code': 'unsettled', 'message': 'They need to settle up before leaving the group'},
    });
    await pumpApp(tester, backend: be, size: desktop, location: '/groups/${be.goa['id']}');
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    await tester.tap(_remove('Rahul Sharma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('They need to settle up before leaving the group'), findsOneWidget);
  });

  testWidgets('leaving a group asks first, then goes back to the groups', (tester) async {
    final be = FakeBackend();
    final me = ((fixture('login') as Map)['user'] as Map)['id'];
    await pumpApp(tester, backend: be, location: '/groups/${be.goa['id']}');
    await tester.tap(find.bySemanticsLabel('Group settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave group'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Goa Trip?'), findsOneWidget);
    await tester.tap(find.text('Leave group').last); // the dialog's button
    await tester.pumpAndSettle();
    expect((be.writes.last.$1, be.writes.last.$2), ('DELETE', '/api/v1/groups/${be.goa['id']}/members/$me'));
    expect(find.text('You left Goa Trip'), findsOneWidget);
    expect(find.text('New group'), findsWidgets, reason: 'back on the group list');
  });

  testWidgets('people who don\'t own the group get no remove buttons', (tester) async {
    final be = FakeBackend();
    for (final e in (be.snapshots['group:${be.goa['id']}'] as Map)['entities'] as List) {
      if (e['entity'] == 'member') e['data']['role'] = 'member'; // the app reads the synced copy
    }
    await pumpApp(tester, backend: be, size: desktop, location: '/groups/${be.goa['id']}');
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is HeaderIconButton && w.label.startsWith('Remove ')), findsNothing);
  });

  testWidgets('an archived group waits under Archived, and can come back', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, location: '/groups/${be.goa['id']}');
    await tester.tap(find.bySemanticsLabel('Group settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive group'));
    await tester.pumpAndSettle();
    expect(find.text('Goa Trip archived'), findsOneWidget);
    expect(find.text('Archived (1)'), findsOneWidget, reason: 'back on the list, folded away');
    expect(find.text('Goa Trip'), findsNothing);

    await tester.tap(find.text('Archived (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goa Trip'));
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsOneWidget);
    await tester.tap(find.text('Unarchive'));
    await tester.pumpAndSettle();
    expect(find.text('Goa Trip is back'), findsOneWidget);
    expect(find.text('Unarchive'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Back to groups'));
    await tester.pumpAndSettle();
    expect(find.text('Archived (1)'), findsNothing);
    expect(find.text('Goa Trip'), findsOneWidget);
  });

  testWidgets('archiving can be undone from the snackbar', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, location: '/groups/${be.goa['id']}');
    await tester.tap(find.bySemanticsLabel('Group settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Archived (1)'), findsNothing);
    expect(find.text('Goa Trip'), findsOneWidget);
  });

  testWidgets("an archived group's Add split and edits stay in that group", (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, backend: be, location: '/groups/${be.goa['id']}');
    await tester.tap(find.bySemanticsLabel('Group settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive group'));
    await tester.pumpAndSettle();
    final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig as GoRouter;

    router.push('/expenses/new?group=${be.goa['id']}');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^Group: Goa Trip')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Group: Flatmates')), findsNothing);

    router.go('/expenses/${be.dinnerId}/edit');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^Group: Goa Trip')), findsOneWidget);
    expect(find.text('Dinner at Thalassa'), findsOneWidget);
  });
}
