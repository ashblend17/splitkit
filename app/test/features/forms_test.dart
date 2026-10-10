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

  testWidgets('an unknown address gets a friendly page, not a router error', (tester) async {
    await pumpApp(tester, location: '/nowhere/at/all');
    expect(find.text("This page doesn't exist"), findsOneWidget);
    expect(find.textContaining('GoException'), findsNothing);
    await tester.tap(find.text('Go home'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hi, '), findsOneWidget);
  });
}
