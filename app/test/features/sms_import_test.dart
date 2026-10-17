import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/router/router.dart';
import 'package:splitkit/core/session/session.dart';
import 'package:splitkit/core/sms/sms.dart';
import 'package:splitkit/core/sms/sms_ids.dart';
import 'package:splitkit/core/sms/sms_parser.dart';
import 'package:splitkit/features/sms/sms_importer.dart';
import 'package:splitkit/features/sms/sms_source.dart';

import '../fake_backend.dart';
import '../fake_sms.dart';
import '../helpers.dart';

const tall = Size(390, 1400);
final me = (fixture('login') as Map)['user']['id'] as String;

RawSms _sms(String sender, String body, DateTime at) => RawSms(address: sender, body: body, receivedAt: at);

/// The tests run on 25 Sep 2026 (flutter_test_config.dart).
List<RawSms> _inbox() => [
  // New, so "just in".
  _sms(
    'VM-HDFCBK-S',
    'Sent Rs.320.00\nFrom HDFC Bank A/C *4821\nTo ZOMATO\nOn 24/09/26\nRef 626800000001\nNot You?',
    DateTime(2026, 9, 24, 21, 0),
  ),
  // Older: added, already looked at.
  _sms(
    'AD-ICICIT-S',
    'INR 899.00 spent using ICICI Bank Card XX9012 on 10-Sep-26 on MYNTRA. Avl Limit: INR 1,20,000.00.',
    DateTime(2026, 9, 10, 18, 0),
  ),
  // The seed's Swiggy order, from its SMS: the same reference, so known.
  _sms(
    'VM-HDFCBK-S',
    'Sent Rs.486.00\nFrom HDFC Bank A/C *4821\nTo SWIGGY\nOn 23/09/26\nRef 426613374520\nNot You?',
    DateTime(2026, 9, 23, 13, 10),
  ),
  // Weekend groceries was entered by hand: this gives it the account.
  _sms(
    'VM-HDFCBK-S',
    'Rs.1860.00 debited from a/c **4821 on 19-09-26 to VPA bigbasket@hdfcbank(UPI Ref No 626200000002).',
    DateTime(2026, 9, 19, 11, 35),
  ),
  _sms('VM-HDFCBK-S', '123456 is the OTP for txn of INR 99.00 at AMAZON. Do not share OTP.', DateTime(2026, 9, 20, 9, 0)),
  _sms('VM-HDFCBK-S', 'Txn of Rs.5,000.00 on HDFC Bank Card 5678 at CROMA was declined.', DateTime(2026, 9, 21, 9, 0)),
  _sms('+919876543210', 'Sent you Rs 500 for dinner!', DateTime(2026, 9, 22, 9, 0)), // a person: never read
];

Future<FakeBackend> _setUp(WidgetTester tester, FakeSmsSource sms) async {
  final be = await pumpApp(tester, location: '/profile/sms', size: tall, sms: sms);
  be.offline = true; // what's read stays queued, for the test to see
  return be;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('turning it on says what leaves the phone, then reads each payment once', (tester) async {
    final sms = FakeSmsSource(available: true, inbox: _inbox());
    await _setUp(tester, sms);
    expect(find.text('Your bank SMS, read on this phone'), findsOneWidget);
    expect(find.textContaining('The messages stay on this phone'), findsOneWidget);
    await _tap(tester, find.text('Allow and read my bank SMS'));
    expect(find.text('Added 2 entries, matched 1 you had entered.'), findsOneWidget);
    expect(sms.reads.single.since, DateTime(2026, 7)); // the last 3 months
    expect(RegExp(sms.reads.single.pattern).hasMatch('+919876543210'), isFalse);

    final ops = appContainer(tester).read(outboxProvider);
    final batch = ops.firstWhere((o) => o.path.endsWith('/batch'));
    final items = (batch.body!['items'] as List).cast<Map>();
    final zomato = _inbox().first;
    expect(items[1]['id'], smsEntryId(me, zomato, (parseSms(zomato) as SmsParsed).txn));
    expect([for (final i in items) (i['description'], i['reviewed'], i['source'])], [
      ('Myntra', true, 'sms'),
      ('Zomato', false, 'sms'),
    ]);
    expect((items[1]['account'], items[1]['channel'], items[1]['reference']), ('HDFC ··4821', 'upi', '626800000001'));
    final food = (fixture('personal_categories') as List).firstWhere((c) => c['key'] == 'food')['id'];
    expect(items[1]['category_id'], food); // Zomato
    final attach = ops.firstWhere((o) => o.method == 'PUT');
    expect((attach.body!['description'], attach.body!['account'], attach.body!['merchant']), (
      'Weekend groceries',
      'HDFC ··4821',
      'bigbasket@hdfcbank',
    ));

    // Reading again finds nothing new.
    await _tap(tester, find.text('Read again'));
    expect(find.text('Nothing new.'), findsOneWidget);
    expect(appContainer(tester).read(outboxProvider).length, ops.length);
  });

  testWidgets("a notification's message finds its entry: by id, by reference, or the one you'd made", (tester) async {
    await _setUp(tester, FakeSmsSource(available: true, inbox: _inbox()));
    await _tap(tester, find.text('Allow and read my bank SMS'));
    final container = appContainer(tester);
    final importer = container.read(smsImporterProvider);
    final items = ((await container.read(localStoreProvider.future)).ledger.personalList(limit: 500)['items'] as List)
        .cast<Map<String, dynamic>>();
    String idOf(bool Function(Map<String, dynamic>) test) => items.firstWhere(test)['id'] as String;
    final inbox = _inbox();
    // Read just now: its own id.
    final zomato = smsEntryId(me, inbox[0], (parseSms(inbox[0]) as SmsParsed).txn);
    expect(await runWrite(tester, importer.importOne(inbox[0])), zomato);
    // The seed's Swiggy order: the same reference.
    expect(await runWrite(tester, importer.importOne(inbox[2])), idOf((t) => t['reference'] == '426613374520'));
    // Weekend groceries, entered by hand: the message gave it its account and merchant.
    expect(await runWrite(tester, importer.importOne(inbox[3])), idOf((t) => t['description'] == 'Weekend groceries'));
    // A code is no payment.
    expect(await runWrite(tester, importer.importOne(inbox[4])), isNull);
  });

  testWidgets('what was skipped is listed (never OTPs), with the message, on this phone', (tester) async {
    await _setUp(tester, FakeSmsSource(available: true, inbox: _inbox()));
    await _tap(tester, find.text('Allow and read my bank SMS'));
    await _tap(tester, find.text('Messages we skipped (1)'));
    expect(find.text("Didn't go through"), findsOneWidget);
    expect(find.textContaining('CROMA was declined'), findsOneWidget);
    expect(find.textContaining('OTP'), findsNothing);
  });

  testWidgets('an entry from an SMS shows the message, read on this phone', (tester) async {
    final be = await _setUp(tester, FakeSmsSource(available: true, inbox: _inbox()));
    await _tap(tester, find.text('Allow and read my bank SMS'));
    be.offline = true;
    appContainer(tester).read(routerProvider).go('/personal');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Zomato').first);
    await _tap(tester, find.text('Show the message'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('VM-HDFCBK-S: Sent Rs.320.00'), findsOneWidget);
  });

  testWidgets('a message that arrives while the app is open is read', (tester) async {
    final sms = FakeSmsSource(available: true, inbox: _inbox().take(1).toList());
    await _setUp(tester, sms);
    await _tap(tester, find.text('Allow and read my bank SMS'));
    final before = appContainer(tester).read(outboxProvider).length;
    sms.receive(
      _sms('VM-HDFCBK-S', 'Sent Rs.150.00\nFrom HDFC Bank A/C *4821\nTo RAPIDO\nOn 25/09/26\nRef 626900000003', DateTime(2026, 9, 25, 11)),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    final ops = appContainer(tester).read(outboxProvider);
    expect(ops.length, before + 1);
    expect((ops.last.body!['items'] as List).single['description'], 'Rapido');
  });

  testWidgets('refused access says how to allow it, and reads nothing', (tester) async {
    final sms = FakeSmsSource(available: true, grant: false, inbox: _inbox());
    await _setUp(tester, sms);
    await _tap(tester, find.text('Allow and read my bank SMS'));
    expect(find.text('Open settings'), findsOneWidget);
    expect(sms.reads, isEmpty);
  });

  testWidgets('Overview offers it once; Not now keeps it away', (tester) async {
    await pumpApp(tester, location: '/personal', size: tall, sms: FakeSmsSource(available: true));
    expect(find.text('Add spending from your bank SMS'), findsOneWidget);
    await _tap(tester, find.text('Not now'));
    expect(find.text('Add spending from your bank SMS'), findsNothing);
    appContainer(tester).read(routerProvider).go('/profile');
    await tester.pumpAndSettle();
    expect(find.text('Bank SMS'), findsOneWidget);
  });

  testWidgets('without an SMS inbox (web, iOS) none of it shows', (tester) async {
    await pumpApp(tester, location: '/personal', size: tall);
    expect(find.text('Add spending from your bank SMS'), findsNothing);
    appContainer(tester).read(routerProvider).go('/profile');
    await tester.pumpAndSettle();
    expect(find.text('Bank SMS'), findsNothing);
  });

  test('viewing as someone never reads your SMS into their account', () async {
    final user = UserOut.fromJson((fixture('login') as Map)['user'])!;
    final sms = FakeSmsSource(available: true, access: true, inbox: _inbox());
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(
          () => _FixedSession(Session(token: 'test-token', user: user, adminId: 'an-admin', readOnly: true)),
        ),
        smsSourceProvider.overrideWithValue(sms),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);
    final scan = await container.read(smsImporterProvider).scan();
    expect(scan.added, 0);
    expect(sms.reads, isEmpty);
  });
}

class _FixedSession extends SessionController {
  _FixedSession(this.session);
  final Session session;

  @override
  Future<Session?> build() async => session;
}
