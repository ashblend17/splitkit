import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_backend.dart';
import '../helpers.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('login errors go away as the field is fixed', (tester) async {
    await pumpApp(tester, token: null);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the email you signed up with'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'a');
    await tester.pump();
    expect(find.text('Enter the email you signed up with'), findsNothing);
    expect(find.text('Enter your password'), findsOneWidget, reason: 'only the edited field clears');
    await tester.enterText(find.byType(TextField).at(1), 'x');
    await tester.pump();
    expect(find.text('Enter your password'), findsNothing);
  });

  testWidgets('sign-up errors go away as the field is fixed, and Enter submits', (tester) async {
    final be = FakeBackend();
    await pumpApp(tester, token: null, backend: be, location: '/register');
    await tester.enterText(find.byType(TextField).at(2), 'short');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Tell us your name'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Neha');
    await tester.pump();
    expect(find.text('Tell us your name'), findsNothing);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('a new group opens straight away, and its name error clears as you type', (tester) async {
    final be = FakeBackend();
    be.postResponses['/api/v1/groups'] = (201, be.goa); // what the server answers doesn't matter here
    await pumpApp(tester, backend: be, location: '/groups');
    await tester.tap(find.text('New group').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();
    expect(find.text('Give the group a name'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'NYC conference');
    await tester.pump();
    expect(find.text('Give the group a name'), findsNothing);

    await tester.tap(find.text('USD \$'));
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();
    expect(find.text('Group not found'), findsNothing);
    expect(find.text('NYC conference'), findsWidgets, reason: 'the new group is open');
    expect(find.text('Create group'), findsNothing, reason: 'the sheet closed');
    final (method, path, body) = be.writes.firstWhere((w) => w.$2 == '/api/v1/groups');
    expect((method, body['name'], body['currency']), ('POST', 'NYC conference', 'USD'));
  });

  testWidgets('an email without an account can be invited by name', (tester) async {
    final be = FakeBackend();
    final path = '/api/v1/groups/${be.goa['id']}/members';
    be.postResponses[path] = (404, {
      'error': {'code': 'no_account', 'message': "There's no Splitkit account with that email yet"},
    });
    await pumpApp(tester, backend: be, size: const Size(1440, 900), location: '/groups/${be.goa['id']}');
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'neha.k@example.com');
    await tester.tap(find.text('Add to group'));
    await tester.pumpAndSettle();
    expect(find.textContaining("There's no Splitkit account with that email yet. Add their name"), findsOneWidget);
    expect(find.text('Add and invite'), findsOneWidget);

    await tester.tap(find.text('Add and invite'));
    await tester.pumpAndSettle();
    expect(find.text('Enter their name'), findsOneWidget);

    be.postResponses[path] = (201, be.goa);
    await tester.enterText(find.byType(TextField).last, 'Neha');
    await tester.tap(find.text('Add and invite'));
    await tester.pumpAndSettle();
    expect(be.writes.last.$3, {'email': 'neha.k@example.com', 'name': 'Neha'});
    expect(find.text('Add and invite'), findsNothing, reason: 'the sheet closed');
  });

  testWidgets('an unknown address gets a friendly page, not a router error', (tester) async {
    await pumpApp(tester, location: '/nowhere/at/all');
    expect(find.text("This page doesn't exist"), findsOneWidget);
    expect(find.textContaining('GoException'), findsNothing);
    await tester.tap(find.text('Go home'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hi, '), findsOneWidget);
  });
}
