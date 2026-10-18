import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/integrations.dart';

import '../fake_backend.dart';
import '../helpers.dart';

const tall = Size(390, 1400);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets("Overview's accounts show the biggest balances, and open the account's entries", (tester) async {
    await pumpApp(tester, location: '/personal', size: tall);
    expect(find.text('Accounts'), findsOneWidget);
    // From the opening and the entries in it, not what the bank last said (₹39,936).
    expect(find.text('₹96,135'), findsOneWidget);
    expect(find.text('₹39,936'), findsNothing);
    expect(find.text('ICICI Credit card ··9012'), findsNothing); // ₹340 owed: not in the top three
    await _tap(tester, find.text('HDFC ··4821').first);
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('Swiggy order'), findsOneWidget);
    expect(find.text('Rapido ride'), findsOneWidget);
    expect(find.text('Blue Tokai coffee'), findsNothing); // the ICICI card
    expect(find.text('Weekend groceries'), findsNothing); // entered by hand, no account
  });

  testWidgets('Transactions filter by how it was paid', (tester) async {
    await pumpApp(tester, location: '/personal/transactions', size: tall);
    await _tap(tester, find.text('Any way paid'));
    await _tap(tester, find.text('Card').last);
    expect(find.text('Blue Tokai coffee'), findsOneWidget);
    expect(find.text('Swiggy order'), findsNothing);
    await _tap(tester, find.text('Card').first);
    await _tap(tester, find.text('Any way paid').last);
    expect(find.text('Swiggy order'), findsOneWidget);
  });

  testWidgets('with the features off, neither shows', (tester) async {
    final off = [featuresProvider.overrideWithValue(const Features(accounts: false, breakdownFilters: false))];
    await pumpApp(tester, location: '/personal', size: tall, overrides: off);
    expect(find.text('Accounts'), findsNothing);
    await pumpApp(tester, location: '/personal/transactions', size: tall, overrides: off);
    expect(find.text('Any way paid'), findsNothing);
    expect(find.text('All accounts'), findsNothing);
  });
}
