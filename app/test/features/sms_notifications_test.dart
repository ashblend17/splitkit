import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/session/session.dart';
import 'package:splitkit/core/sms/sms.dart';
import 'package:splitkit/core/sms/sms_notification.dart';
import 'package:splitkit/features/expenses/add_expense_page.dart';
import 'package:splitkit/features/sms/sms_importer.dart';
import 'package:splitkit/features/sms/sms_source.dart';

import '../fake_backend.dart';
import '../fake_sms.dart';
import '../helpers.dart';

const tall = Size(390, 1400);

final _swiggy = RawSms(
  address: 'VM-HDFCBK-S',
  body: 'Sent Rs.450.00\nFrom HDFC Bank A/C *4821\nTo SWIGGY\nOn 25/09/26\nRef 626900000010\nNot You?',
  receivedAt: DateTime(2026, 9, 25, 11, 30),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Turned on from the setup page, with [sms] as the phone.
Future<void> _turnOn(WidgetTester tester, FakeSmsSource sms) async {
  final be = await pumpApp(tester, location: '/profile/sms', size: tall, sms: sms);
  be.offline = true;
  await _tap(tester, find.text('Allow and read my bank SMS'));
}

/// The app goes to the background and comes back (a notification was tapped).
Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  group('what a notification says', () {
    test('a spend, with who was paid and how', () {
      expect(describeForNotification(_swiggy), (title: '₹450 at Swiggy', text: 'HDFC ··4821 · UPI', split: true));
    });

    test('money in, from someone', () {
      final d = describeForNotification(
        RawSms(
          address: 'VM-ICICIB-S',
          body: 'Dear Customer, Acct XX123 is credited with Rs 2500.00 on 25-Sep-26 from RAHUL SHARMA. UPI:626900000011-ICICI Bank.',
          receivedAt: DateTime(2026, 9, 25),
        ),
      );
      expect(d, (title: '₹2,500 from Rahul Sharma', text: 'ICICI ··123 · UPI', split: false));
    });

    test('nothing for what isn\'t a payment, or isn\'t from a bank', () {
      for (final (address, body) in [
        ('VM-HDFCBK-S', '123456 is the OTP for txn of INR 99.00 at AMAZON. Do not share OTP.'),
        ('VM-HDFCBK-P', 'Get a loan of Rs.10 lakh! Apply now.'),
        ('+919876543210', 'Sent Rs.500 from my A/c XX1234'),
      ]) {
        expect(describeForNotification(RawSms(address: address, body: body, receivedAt: DateTime(2026, 9, 25))), isNull);
      }
    });
  });

  testWidgets('the phone is told to notify while reading is on, and Split with it', (tester) async {
    final sms = FakeSmsSource(available: true, inbox: [_swiggy]);
    await _turnOn(tester, sms);
    expect((sms.configured!.notify, sms.configured!.split), (true, true));
    expect(RegExp(sms.configured!.pattern).hasMatch('VM-HDFCBK-S'), isTrue);
    expect(RegExp(sms.configured!.pattern).hasMatch('+919876543210'), isFalse);

    await _tap(tester, find.byType(Switch));
    expect(sms.configured!.notify, isFalse);
    await _tap(tester, find.byType(Switch));
    expect(sms.configured!.notify, isTrue);
    await _tap(tester, find.text('Turn off'));
    expect(sms.configured!.notify, isFalse);
  });

  test('signing out stops the notifications', () async {
    final user = UserOut.fromJson((fixture('login') as Map)['user'])!;
    final sms = FakeSmsSource(available: true);
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _SignedIn(Session(token: 'test-token', user: user))),
        smsSourceProvider.overrideWithValue(sms),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);
    container.read(smsImporterProvider); // the app has it from the start
    (container.read(sessionProvider.notifier) as _SignedIn).signOut();
    await pumpEventQueue();
    expect(sms.configured?.notify, isFalse);
  });

  testWidgets('Split on a notification opens Add split with the payment, and clears it', (tester) async {
    final sms = FakeSmsSource(available: true);
    await _turnOn(tester, sms);
    sms.messages.add(_swiggy); // arrived with the app in the background
    sms.launch = (sms: _swiggy, split: true, notification: 7);
    await _resume(tester);
    final page = tester.widget<AddExpensePage>(find.byType(AddExpensePage));
    expect(page.fromTxnId, isNotNull);
    expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, 'Swiggy');
    expect(sms.cancelled, [7]);
  });

  testWidgets('tapping the notification itself opens Personal', (tester) async {
    final sms = FakeSmsSource(available: true);
    await _turnOn(tester, sms);
    sms.messages.add(_swiggy);
    sms.launch = (sms: _swiggy, split: false, notification: 8);
    await _resume(tester);
    expect(find.byType(AddExpensePage), findsNothing);
    expect(find.text('Just in'), findsOneWidget);
    expect(find.text('Swiggy'), findsWidgets);
  });
}

class _SignedIn extends SessionController {
  _SignedIn(this.session);
  final Session session;

  @override
  Future<Session?> build() async => session;

  void signOut() => state = const AsyncData(null);
}
