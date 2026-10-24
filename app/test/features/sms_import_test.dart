import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/api/api.dart';
import 'package:app/core/finance/finance.dart' show PlanStatus, pairedLegId, smsAccountId, transferGroupIdFor;
import 'package:app/core/integrations.dart';
import 'package:app/core/local/ledger.dart';
import 'package:app/core/local/outbox.dart';
import 'package:app/core/local/providers.dart';
import 'package:app/core/local/store.dart';
import 'package:app/core/local/writes.dart';
import 'package:app/core/router/router.dart';
import 'package:app/core/session/session.dart';
import 'package:app/core/sms/sms.dart';
import 'package:app/core/sms/sms_ids.dart';
import 'package:app/core/sms/sms_parser.dart';
import 'package:app/core/sms/sms_scan.dart' show scanSms;
import 'package:app/features/sms/sms_importer.dart';
import 'package:app/features/sms/sms_source.dart';

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

Future<FakeBackend> _setUp(WidgetTester tester, FakeSmsSource sms, {List<Override> overrides = const []}) async {
  final be = await pumpApp(tester, location: '/profile/sms', size: tall, sms: sms, overrides: overrides);
  be.offline = true; // what's read stays queued, for the test to see
  return be;
}

LocalStore _store(WidgetTester tester) => appContainer(tester).read(localStoreProvider).value!;

Ledger _ledger(WidgetTester tester) => _store(tester).ledger;

String _account(Ledger l, String label) =>
    l.personalAccountList().firstWhere((a) => a['sms_label'] == label || a['name'] == label)['id'] as String;

/// The items of [ops], each a `POST /personal/batch` that parses as the generated client's model
/// (so its shape can't drift from the API's).
List<Map> _items(List<OutboxOp> ops) => [
  for (final op in ops) ...[
    if (op.path != '/api/v1/personal/batch' || PersonalMixedBatchIn.fromJson(op.body) == null)
      throw TestFailure('not a personal batch: ${op.method} ${op.path}'),
    ...(op.body!['items'] as List).cast<Map>(),
  ],
];

Map _txn(Map item) => item['transaction'] as Map;

String _idOf(RawSms sms) => smsEntryId(me, sms, (parseSms(sms) as SmsParsed).txn);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(); // lays out the scroll, so the tap lands
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

    // One request for everything read: the new entries, each in its account, then the entry you'd
    // made, given the account and merchant the message names.
    final ops = appContainer(tester).read(outboxProvider);
    final items = _items(ops);
    expect(ops.length, 1);
    final ledger = _ledger(tester);
    final (hdfc, card) = (_account(ledger, 'HDFC ··4821'), _account(ledger, 'ICICI Credit card ··9012'));
    final zomato = _inbox().first;
    final [myntra, made, attach] = items;
    expect(made['id'], smsEntryId(me, zomato, (parseSms(zomato) as SmsParsed).txn));
    Object entry(Map i) =>
        (i['op'], _txn(i)['description'], _txn(i)['reviewed'], _txn(i)['source'], _txn(i)['account_id']);
    expect([entry(myntra), entry(made)], [
      ('create', 'Myntra', true, 'sms', card),
      ('create', 'Zomato', false, 'sms', hdfc),
    ]);
    expect(
      (_txn(made)['account'], _txn(made)['channel'], _txn(made)['reference']),
      ('HDFC ··4821', 'upi', '626800000001'),
    );
    final food = (fixture('personal_categories') as List).firstWhere((c) => c['key'] == 'food')['id'];
    expect(_txn(made)['category_id'], food); // Zomato
    final a = _txn(attach);
    expect(
      (attach['op'], a['description'], a['account'], a['merchant'], a['account_id']),
      ('update', 'Weekend groceries', 'HDFC ··4821', 'bigbasket@hdfcbank', hdfc),
    );

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

  testWidgets("a notification's refund is added as one; an unpaired card bill isn't an entry", (tester) async {
    final sms = FakeSmsSource(available: true, inbox: _inbox());
    await _setUp(tester, sms);
    await _tap(tester, find.text('Allow and read my bank SMS'));
    final importer = appContainer(tester).read(smsImporterProvider);
    final refund = _swiggyRefund();
    sms.messages.add(refund);
    expect(await runWrite(tester, importer.importOne(refund)), _idOf(refund));
    expect(_ledger(tester).rawPersonal(_idOf(refund))!['type'], 'refund');
    final atm = _atm();
    sms.messages.add(atm);
    expect(await runWrite(tester, importer.importOne(atm)), _idOf(atm));
    expect(await runWrite(tester, importer.isSpend(_idOf(atm))), isFalse); // a transfer: Split isn't offered
    final bill = _cardBill(777700);
    sms.messages.add(bill);
    expect(await runWrite(tester, importer.importOne(bill)), isNull);
  });

  testWidgets('a first read makes the accounts, refunds and transfers it finds, in one batch; again, nothing', (
    tester,
  ) async {
    final inbox = [
      _sms(
        'VM-HDFCBK-S',
        'Rs.200.00 debited from HDFC Bank A/c XX7777 on 20-09-26 towards BLINKIT via NetBanking.',
        DateTime(2026, 9, 20, 10),
      ),
      _sms(
        'VM-HDFCBK-S',
        'Rs.520.00 debited from HDFC Bank A/c XX7777 on 21-09-26 towards SWIGGY via NetBanking. Avl bal Rs.10,000.00',
        DateTime(2026, 9, 21, 10),
      ),
      _swiggyRefund(),
      _sms(
        'VM-HDFCBK-S',
        'Refund of Rs.799.00 from DECATHLON credited to HDFC Bank A/c XX4821 on 24-09-26.',
        DateTime(2026, 9, 24, 12),
      ),
      _atm(),
      _sms(
        'VM-HDFCBK-S',
        'Rs.4,321.00 debited from HDFC Bank A/c XX4821 on 24-09-26 towards ICICI CREDIT CARD via NetBanking. '
        'Avl bal Rs.30,000.00',
        DateTime(2026, 9, 24, 14),
      ),
      _cardBill(432100),
      _cardBill(777700), // no payment of it: skipped, and read again next time
      ..._ownTransfer(25000),
    ];
    final sms = FakeSmsSource(available: true, inbox: inbox);
    await _setUp(tester, sms);
    await _tap(tester, find.text('Allow and read my bank SMS'));
    final ops = appContainer(tester).read(outboxProvider);
    final items = _items(ops);
    final ledger = _ledger(tester);
    Map entry(RawSms m) => _txn(items.singleWhere((i) => i['id'] == _idOf(m)));

    // The accounts first: each label with none gets one, its fixed id, reconciled from the first
    // balance its messages report (₹10,000 after ₹200 and ₹520 went out).
    final newHdfc = smsAccountId(me, 'HDFC ··7777'), icici = smsAccountId(me, 'ICICI ··9911');
    Object account(Map i) => (i['kind'], i['op'], i['id'], (i['account'] as Map)['opening_balance_minor']);
    expect([for (final i in items.take(2)) account(i)], [
      ('account', 'create', newHdfc, 1072000),
      ('account', 'create', icici, 0),
    ]);
    expect((items.first['account'] as Map)['sms_label'], 'HDFC ··7777');
    expect(entry(inbox[1])['account_id'], newHdfc);
    final balance = ledger.finance.balanceOf(newHdfc)!;
    expect((balance.balanceMinor, balance.lastReported!.gapMinor), (1000000, 0));

    // Refunds: the Swiggy order's, in its category; Decathlon's, for no spend we know.
    final swiggy = ledger.rawPersonal(_swiggyOrder)!;
    expect(
      (entry(inbox[2])['type'], entry(inbox[2])['refund_of_id'], entry(inbox[2])['category_id']),
      ('refund', _swiggyOrder, swiggy['category_id']),
    );
    expect((entry(inbox[3])['type'], entry(inbox[3])['refund_of_id']), ('refund', null));

    // The cash withdrawal moved to Cash; the card bill paid from HDFC; the self transfer.
    final hdfc = _account(ledger, 'HDFC ··4821'), cash = _account(ledger, 'Cash');
    final card = _account(ledger, 'ICICI Credit card ··9012');
    final atmLeg = _txn(items.singleWhere((i) => i['id'] == pairedLegId(_idOf(inbox[4]))));
    Object leg(Map t) => (t['type'], t['direction'], t['account_id'], t['transfer_group_id']);
    expect([leg(entry(inbox[4])), leg(atmLeg)], [
      ('transfer', 'out', hdfc, transferGroupIdFor(_idOf(inbox[4]))),
      ('transfer', 'in', cash, transferGroupIdFor(_idOf(inbox[4]))),
    ]);
    expect([leg(entry(inbox[5])), leg(entry(inbox[6]))], [
      ('transfer', 'out', hdfc, transferGroupIdFor(_idOf(inbox[6]))),
      ('transfer', 'in', card, transferGroupIdFor(_idOf(inbox[6]))),
    ]);
    final self = transferGroupIdFor(_idOf(inbox[8]), _idOf(inbox[9]));
    expect([leg(entry(inbox[8])), leg(entry(inbox[9]))], [
      ('transfer', 'in', icici, self),
      ('transfer', 'out', hdfc, self),
    ]);
    expect(items.any((i) => i['id'] == _idOf(inbox[7])), isFalse);
    expect(find.text('Added 9 entries.'), findsOneWidget); // the cash half isn't a message's

    expect(await runWrite(tester, _store(tester).deviceValue(SmsKeys.retry)), isNull);

    // Reading again finds nothing new: the same ids, and the unpaid bill is still waiting.
    await _tap(tester, find.text('Read again'));
    expect(find.text('Nothing new.'), findsOneWidget);
    expect(appContainer(tester).read(outboxProvider).length, ops.length);
    await _tap(tester, find.text('Messages we skipped (1)'));
    expect(find.text('A card bill with no matching payment yet'), findsOneWidget);
  });

  testWidgets('an own transfer pairs with an entry read before: it becomes the other half', (tester) async {
    final [income, debit] = _ownTransfer(5000, plainIncome: true);
    final sms = FakeSmsSource(available: true, inbox: [income]);
    await _setUp(tester, sms);
    await _tap(tester, find.text('Allow and read my bank SMS'));
    expect(_ledger(tester).rawPersonal(_idOf(income))!['type'], 'income');
    // The seed's two allocation rules planned from the income, in its unit.
    final plans = _ledger(tester).finance.plansOfIncome(_idOf(income));
    expect([for (final p in plans) p.plan.plannedMinor], unorderedEquals([50000, 500000]));
    final before = appContainer(tester).read(outboxProvider).length;

    sms.messages.add(debit);
    await runWrite(tester, appContainer(tester).read(smsImporterProvider).scan());
    final ops = appContainer(tester).read(outboxProvider).skip(before).toList();
    // An income becoming a transfer half: its plans are deleted first (income_has_plans), in the
    // same unit as the half.
    expect([for (final i in _items(ops)) (i['kind'], i['op'])], [
      ('allocation_plan', 'delete'),
      ('allocation_plan', 'delete'),
      ('transaction', 'update'),
      ('transaction', 'create'),
    ]);
    expect(_ledger(tester).finance.plansOfIncome(_idOf(income)).map((p) => p.status), everyElement(PlanStatus.cancelled));
    final [changed, made] = [
      for (final i in _items(ops))
        if (i['kind'] == 'transaction') i,
    ];
    final group = transferGroupIdFor(_idOf(debit), _idOf(income));
    final leg = _txn(changed);
    expect(
      (changed['op'], changed['id'], changed['version'], leg['type'], leg['direction'], leg['category_id']),
      ('update', _idOf(income), 1, 'transfer', 'in', null),
    );
    expect(
      (leg['transfer_group_id'], made['id'], _txn(made)['transfer_group_id']),
      (group, _idOf(debit), group),
    );
    expect(_ledger(tester).finance.transferLegs(group).length, 2);
  });

  testWidgets("a card bill skipped for want of its payment pairs on the next read, and isn't listed as skipped", (
    tester,
  ) async {
    final bill = _cardBill(432100);
    final sms = FakeSmsSource(available: true, inbox: [bill]);
    await _setUp(tester, sms);
    await _tap(tester, find.text('Allow and read my bank SMS'));
    expect(find.text('Messages we skipped (1)'), findsOneWidget);
    // The bank's message comes later, the same day; the next read goes back over the bill too.
    sms.messages.add(
      _sms(
        'VM-HDFCBK-S',
        'Rs.4,321.00 debited from HDFC Bank A/c XX4821 on 24-09-26 towards ICICI CREDIT CARD via NetBanking. '
        'Avl bal Rs.30,000.00',
        DateTime(2026, 9, 24, 18),
      ),
    );
    await runWrite(tester, appContainer(tester).read(smsImporterProvider).scan());
    expect(_ledger(tester).rawPersonal(_idOf(bill))!['type'], 'transfer');
    expect(await runWrite(tester, appContainer(tester).read(smsImporterProvider).skipped()), isEmpty);
  });

  testWidgets("a message whose entry the device refuses is read again, then listed as skipped; the rest goes", (
    tester,
  ) async {
    // Over the largest amount an entry can have: refused however often it's read.
    final huge = _sms(
      'VM-HDFCBK-S',
      'Rs.12,00,00,000.00 debited from HDFC Bank A/c XX4821 on 10-09-26 towards ACME CORP via NetBanking.',
      DateTime(2026, 9, 10, 10),
    );
    final zomato = _inbox().first;
    final sms = FakeSmsSource(available: true, inbox: [huge, zomato]);
    final logs = <String?>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message);
    await _setUp(tester, sms);
    await _tap(tester, find.text('Allow and read my bank SMS'));
    expect(find.text('Added 1 entry.'), findsOneWidget);
    final ops = appContainer(tester).read(outboxProvider);
    expect([for (final i in _items(ops)) i['id']], [_idOf(zomato)]);

    final importer = appContainer(tester).read(smsImporterProvider);
    Future<List<Object?>> tries() async => [
      for (final r in (await runWrite(tester, _store(tester).deviceValue(SmsKeys.retry)) as List?) ?? const [])
        (r as Map)['tries'],
    ];
    Future<List<SkippedSms>> skipped() => runWrite(tester, importer.skipped());
    expect(await tries(), [1]);
    expect(await skipped(), isEmpty);
    // The next read starts after it (three days before the newest message): it's read anyway.
    await runWrite(tester, importer.scan());
    expect(sms.reads.last.since.isAfter(huge.receivedAt), isTrue);
    expect(await tries(), [2]);
    // Refused on a third read: listed as skipped, and no longer read.
    await runWrite(tester, importer.scan());
    expect(await tries(), isEmpty);
    expect([for (final s in await skipped()) (s.sms.body, s.reason)], [(huge.body, SmsSkip.noTransaction)]);
    expect(logs.where((l) => l!.contains('refused on 3 reads')), hasLength(1));
    await runWrite(tester, importer.scan());
    expect((await skipped()).length, 1);
    expect(appContainer(tester).read(outboxProvider).length, ops.length);
    debugPrint = print;
  });

  testWidgets('an account closed between a read and its queueing: the rest is queued, its entry read again', (
    tester,
  ) async {
    await _setUp(tester, FakeSmsSource(available: true));
    final [myntra, zomato] = [_inbox()[1], _inbox()[0]];
    final read = scanSms(smsScanInput(_ledger(tester), [myntra, zomato], const Features()));
    final writes = appContainer(tester).read(writesProvider);
    await runWrite(tester, writes.closeAccount(_account(_ledger(tester), 'ICICI Credit card ··9012')));
    final before = appContainer(tester).read(outboxProvider).length;
    final refused = <(String, String?)>[];
    await runWrite(
      tester,
      writes.importUnits(
        smsImportUnits(_ledger(tester), read),
        onRefused: (unit, why) => refused.add((unit.single.id, apiErrorCode(why))),
      ),
    );
    expect(refused, [(_idOf(myntra), 'account_closed')]);
    final ops = appContainer(tester).read(outboxProvider).skip(before).toList();
    expect([for (final i in _items(ops)) i['id']], [_idOf(zomato)]);
  });

  testWidgets("a closed account's label gives the entry no account", (tester) async {
    await _setUp(tester, FakeSmsSource(available: true, inbox: _inbox().sublist(1, 2)));
    final card = _account(_ledger(tester), 'ICICI Credit card ··9012');
    await runWrite(tester, appContainer(tester).read(writesProvider).closeAccount(card));
    final before = appContainer(tester).read(outboxProvider).length;
    await _tap(tester, find.text('Allow and read my bank SMS'));
    final myntra = _txn(_items(appContainer(tester).read(outboxProvider).skip(before).toList()).single);
    expect((myntra['account'], myntra['account_id']), ('ICICI Credit card ··9012', null));
  });

  testWidgets('without a Cash account, a cash withdrawal is spending or left out, as countAtmAsSpending says', (
    tester,
  ) async {
    for (final spending in [true, false]) {
      await _setUp(
        tester,
        FakeSmsSource(available: true, inbox: [_atm()]),
        overrides: [featuresProvider.overrideWithValue(Features(countAtmAsSpending: spending))],
      );
      final cash = _account(_ledger(tester), 'Cash');
      await runWrite(tester, appContainer(tester).read(writesProvider).closeAccount(cash));
      final before = appContainer(tester).read(outboxProvider).length;
      await _tap(tester, find.text('Allow and read my bank SMS'));
      final ops = appContainer(tester).read(outboxProvider).skip(before).toList();
      expect([for (final i in _items(ops)) _txn(i)['type']], [if (spending) 'expense']);
    }
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
    expect(_txn(_items([ops.last]).single)['description'], 'Rapido');
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

const _swiggyOrder = '7519b197-caab-50b4-83b7-16f72b5b9456'; // the seed's, ₹486 on 23 Sep

RawSms _swiggyRefund() => _sms(
  'VM-HDFCBK-S',
  'Rs.486.00 credited to HDFC Bank A/c XX4821 on 24-09-26 by a/c linked to VPA swiggy.stores@icici as a refund '
      '(UPI Ref No 626900000099).',
  DateTime(2026, 9, 24, 11),
);

RawSms _atm() => _sms(
  'VM-HDFCBK-S',
  'Rs.2000.00 withdrawn at ATM HDFC0001234 from A/c XX4821 on 24-09-26. Avl Bal: Rs.40,276.50 Not you? Call '
  '18002586161',
  DateTime(2026, 9, 24, 13),
);

/// The ICICI card's bank saying a bill of [amountMinor] was paid, on 24 Sep.
RawSms _cardBill(int amountMinor) {
  final rupees = amountMinor ~/ 100;
  final amount = rupees >= 1000 ? '${rupees ~/ 1000},${(rupees % 1000).toString().padLeft(3, '0')}' : '$rupees';
  return _sms(
    'VM-ICICIT-S',
    'Dear Customer, Payment of INR $amount.00 has been received on your ICICI Bank Credit Card Account 4xxx9012 on '
        '24-Sep-26. Thank you.',
    DateTime(2026, 9, 24, 15),
  );
}

/// ₹[rupees] from HDFC ··4821 to ICICI ··9911 on 24 Sep, as both banks tell it, the credit first;
/// with [plainIncome], ICICI's message doesn't say it's a transfer.
List<RawSms> _ownTransfer(int rupees, {bool plainIncome = false}) {
  final amount = '${rupees ~/ 1000},${(rupees % 1000).toString().padLeft(3, '0')}.00';
  return [
    _sms(
      'VM-ICICIB-S',
      plainIncome
          ? 'Dear Customer, Acct XX9911 is credited with Rs $amount on 24-Sep-26 from JOHN D. '
                'UPI:626900000123-ICICI Bank.'
          : 'ICICI Bank Acct XX9911 credited with Rs $amount on 24-Sep-26 by self transfer from HDFC Bank A/c XX4821. '
                'IMPS:628712345602.',
      DateTime(2026, 9, 24, 16),
    ),
    _sms(
      'VM-HDFCBK-S',
      'Rs.$amount debited from HDFC Bank A/c XX4821 on 24-09-26 for self transfer to A/c XX9911 (IMPS Ref No '
      '628712345602). Avl bal: Rs.20,276.50',
      DateTime(2026, 9, 24, 16, 2),
    ),
  ];
}

class _FixedSession extends SessionController {
  _FixedSession(this.session);
  final Session session;

  @override
  Future<Session?> build() async => session;
}
