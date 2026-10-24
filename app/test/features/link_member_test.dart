import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/design_system/design_system.dart';

import '../fake_backend.dart';
import '../helpers.dart';

const desktop = Size(1440, 900);
const sam = '00000000-0000-4000-8000-00000000c0de';

/// Adds a placeholder member "Sam" to Goa Trip's snapshot, as the API would sync it.
Map<String, dynamic> _addPlaceholder(FakeBackend be, {String? inviteEmail}) {
  final goa = be.goa['id'] as String;
  final user = {'id': sam, 'name': 'Sam', 'avatar_url': null, 'is_placeholder': true};
  final member = {
    'group_id': goa,
    'user_id': sam,
    'role': 'member',
    'joined_at': '2026-09-25T10:00:00+00:00',
    'left_at': null,
    'placeholder_name': 'Sam',
    'invite_email': inviteEmail,
    'import_batch_id': null,
    'user': user,
  };
  ((be.snapshots['group:$goa'] as Map)['entities'] as List).add({
    'entity': 'member',
    'entity_id': sam,
    'version': null,
    'data': member,
  });
  return member;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a placeholder member gets a Link button that saves an invite', (tester) async {
    final be = FakeBackend();
    final goa = be.goa['id'] as String;
    final member = _addPlaceholder(be);
    final path = '/api/v1/groups/$goa/members/$sam/link';
    // No account has that email yet: Sam stays a placeholder, now with the invite.
    final answer = jsonDecode(jsonEncode(be.goa)) as Map<String, dynamic>;
    answer['members'] = [
      ...answer['members'] as List,
      {...member, 'invite_email': 'sam@example.com'},
    ];
    be.postResponses[path] = (200, answer);
    await pumpApp(tester, backend: be, size: desktop, location: '/groups/$goa');
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    expect(find.text('No account yet'), findsOneWidget);
    expect(find.widgetWithText(SkButton, 'Link'), findsOneWidget); // only Sam: Kabir is linked

    await tester.tap(find.widgetWithText(SkButton, 'Link'));
    await tester.pumpAndSettle();
    expect(find.text('Link Sam to an account'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'sam@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();

    final (method, wrotePath, body) = be.writes.last;
    expect((method, wrotePath), ('POST', path));
    expect(body, {'email': 'sam@example.com'});
    expect(find.text('Invite saved. Signing up with sam@example.com takes Sam’s place.'), findsOneWidget);
  });

  testWidgets('an invited placeholder shows the email', (tester) async {
    final be = FakeBackend();
    _addPlaceholder(be, inviteEmail: 'sam@example.com');
    await pumpApp(tester, backend: be, size: desktop, location: '/groups/${be.goa['id']}');
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    expect(find.text('Invited · sam@example.com'), findsOneWidget);
  });
}
