import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/categorise/category_guesser.dart';
import 'package:splitkit/core/clock.dart';
import 'package:splitkit/core/finance/finance.dart';
import 'package:splitkit/core/integrations.dart';
import 'package:splitkit/core/local/ledger.dart';
import 'package:splitkit/core/sms/merchant_names.dart';
import 'package:splitkit/core/sms/sms.dart';
import 'package:splitkit/core/sms/sms_ids.dart';
import 'package:splitkit/core/sms/sms_parser.dart';
import 'package:splitkit/core/sms/sms_scan.dart';
import 'package:splitkit/features/sms/sms_importer.dart' show smsScanInput, runSmsScan, smsScanInlineUpTo;

import '../perf/heavy_data.dart';

/// The pure SMS scan (core/sms/sms_scan.dart). Payments against the importer's per-message reading
/// as it was before it moved there ([_ReferenceRead], a copy of the old `_Read` that also puts each
/// entry in its account, design §5.2 rule 1), on the heavy dataset and on the parser's corpus over
/// the seed; then refunds, cash withdrawals, card bills and own transfers, rule by rule, over the
/// seed.
void main() {
  late HeavyData data;
  late Ledger heavy;
  late List<RawSms> heavySmsList;
  late Ledger seed;
  late List<RawSms> corpus;

  setUpAll(() {
    data = buildHeavyData();
    heavy = Ledger(data.entities);
    heavySmsList = heavySms(data);
    seed = _seed();
    final messages = (jsonDecode(File('test/fixtures/sms/corpus.json').readAsStringSync()) as Map)['messages'] as List;
    corpus = [
      for (final m in messages.cast<Map<String, dynamic>>())
        RawSms(address: m['sender'], body: m['body'], receivedAt: DateTime.parse(m['received'])),
    ]..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
  });

  /// The scan's output and the reference's, side by side, over the messages the importer read as
  /// payments before refunds, card bills and own transfers were read (they're checked below), and
  /// with cash withdrawals read the old way ([Features.atmToCash] off).
  void same(
    Ledger ledger,
    List<RawSms> messages, {
    Features features = const Features(atmToCash: false),
    Set<String> before = const {},
  }) {
    final payments = [
      for (final m in messages)
        if (parseSms(m) case SmsSkipped() || SmsParsed(txn: SmsTxn(kind: SmsKind.payment))) m,
    ];
    final want = _ReferenceRead(ledger, features, before)..addAll(payments);
    final got = scanSms(smsScanInput(ledger, payments, features, attachedBefore: before));
    expect(got.convert, isEmpty);
    expect(_normal(got), want.normal());
  }

  test('reads the heavy SMS set as the importer did, in your accounts', () {
    same(heavy, heavySmsList);
    final out = scanSms(smsScanInput(heavy, heavySmsList, const Features()));
    // It meets every case: new, attached, known. The heavy data has no accounts yet, so each
    // label gets one.
    expect((out.created.length, out.attached.length, out.known), (1719, 81, 200));
    expect(out.newAccounts.length, 10);
  });

  test('with messages attached before, and other settings', () {
    final attached = scanSms(smsScanInput(heavy, heavySmsList, const Features())).attached;
    same(heavy, heavySmsList, before: {for (final a in attached.take(30)) a.smsId});
    same(heavy, heavySmsList, features: const Features(suggestCategories: false, atmToCash: false));
    same(
      heavy,
      heavySmsList,
      features: const Features(learnCategories: false, justInBackfillDays: 30, atmToCash: false),
    );
  });

  test('reads the corpus over the seed as the importer did: skips, ATM, manual entries', () {
    same(seed, corpus);
    same(seed, corpus, features: const Features(countAtmAsSpending: false, atmToCash: false));
    final out = scanSms(smsScanInput(seed, corpus, const Features()));
    expect(
      out.skipped.map((s) => s.reason).toSet(),
      containsAll([SmsSkip.failed, SmsSkip.refund, SmsSkip.promotional, SmsSkip.cardBill, SmsSkip.ownTransfer]),
    );
    expect(out.skipped.where((s) => s.reason == SmsSkip.otp || s.reason == SmsSkip.notABank), isEmpty);
    expect(out.last, corpus.last.receivedAt);
    // Skipped in the order they came, card bills and own transfers (decided last) too.
    final order = [for (final s in out.skipped) corpus.indexOf(s.sms)];
    expect(order, [...order]..sort());
  });

  test('gives the same on another isolate', () async {
    final input = smsScanInput(heavy, heavySmsList, const Features());
    final inline = _normal(scanSms(input));
    expect(_normal(await Isolate.run(() => scanSms(input))), inline);
    expect(heavySmsList.length, greaterThan(smsScanInlineUpTo)); // so runSmsScan goes to an isolate
    expect(_normal(await runSmsScan(input)), inline);
    // The corpus over the seed meets every kind.
    final kinds = smsScanInput(seed, corpus, const Features());
    expect(_normal(await Isolate.run(() => scanSms(kinds))), _normal(scanSms(kinds)));
  });

  test('nothing to read gives nothing', () {
    final out = scanSms(smsScanInput(heavy, const [], const Features()));
    expect([...out.created, ...out.attached, ...out.skipped, ...out.newAccounts, ...out.convert], isEmpty);
    expect((out.known, out.last), (0, null));
  });

  group('accounts', () {
    test('a label with no account gets one, made with its fixed id, that starts reconciled', () {
      final out = _scan(seed, [
        _hdfc('Rs.200.00 debited from HDFC Bank A/c XX7777 on 20-09-26 towards BLINKIT via NetBanking.', 20),
        _hdfc(
          'Rs.520.00 debited from HDFC Bank A/c XX7777 on 21-09-26 towards SWIGGY via NetBanking. Avl bal Rs.10,000.00',
          21,
        ),
        _hdfc(
          'Rs.300.00 debited from HDFC Bank A/c XX7777 on 22-09-26 towards ZEPTO via NetBanking. Avl bal Rs.9,700.00',
          22,
        ),
        _icici('INR 899.00 spent using ICICI Bank Card XX4444 on 22-Sep-26 on MYNTRA. Avl Limit: INR 1,20,000.00.', 22),
      ]);
      final hdfc = smsAccountId(me, 'HDFC ··7777'), card = smsAccountId(me, 'ICICI Credit card ··4444');
      // Up to the first reported balance, ₹200 and ₹520 went out of it: ₹10,000 + ₹720.
      expect(out.newAccounts, [
        (id: hdfc, label: 'HDFC ··7777', type: AccountType.bank, openingMinor: 1072000),
        (id: card, label: 'ICICI Credit card ··4444', type: AccountType.creditCard, openingMinor: 0),
      ]);
      expect([for (final (_, t) in out.created) t.accountId], [hdfc, hdfc, hdfc, card]);
      expect({for (final (_, t) in out.created) t.direction}, {PersonalTxnInDirectionEnum.out_});
    });

    test("an open account's label puts entries in it; a closed or deleted one's gives none, and makes none", () {
      final myntra = _icici(
        'INR 899.00 spent using ICICI Bank Card XX9012 on 22-Sep-26 on MYNTRA. Avl Limit: INR 1,20,000.00.',
        22,
      );
      final open = _scan(seed, [myntra]);
      expect(open.created.single.$2.accountId, _accountId(seed, 'ICICI Credit card ··9012'));
      for (final ledger in [
        _seed(closed: {'ICICI Credit card ··9012'}),
        _seed(deleted: {'ICICI Credit card ··9012'}),
      ]) {
        final out = _scan(ledger, [myntra]);
        expect((out.created.single.$2.accountId, out.created.single.$2.account), (null, 'ICICI Credit card ··9012'));
        expect(out.newAccounts, isEmpty);
      }
    });

    test('a label no account has goes in the account whose full number it ends', () {
      final ledger = _seed(patch: {'HDFC ··4821': {'account_number': '50100123454821'}});
      final out = _scan(ledger, [
        _hdfc('Rs.200.00 debited from HDFC Bank A/c XX54821 on 20-09-26 towards BLINKIT via NetBanking.', 20),
      ]);
      expect(out.newAccounts, isEmpty);
      expect(
        (out.created.single.$2.accountId, out.created.single.$2.account),
        (_accountId(ledger, 'HDFC ··4821'), 'HDFC ··54821'),
      );
    });

    test("a card's other wording goes in the card's account (ISS-088)", () {
      final ledger = _seed(accounts: ['HDFC Card ··5678']);
      final out = _scan(ledger, [
        _hdfc('Spent Rs.1,299.00 On HDFC Bank Credit Card 5678 At AMAZON On 2026-09-22', 22),
      ]);
      expect(out.newAccounts, isEmpty);
      expect(out.created.single.$2.accountId, _accountId(ledger, 'HDFC Card ··5678'));
    });

    test("an account linked to a closed one takes no entries, and one linked to a card is the card's type", () {
      final hdfc = _accountId(_seed(), 'HDFC ··4821'), card = _accountId(_seed(), 'ICICI Credit card ··9012');
      final debit = _hdfc('Rs.640.00 spent on HDFC Bank Debit Card XX3016 on 20-09-26 at STARBUCKS.', 20);
      final open = _seed(accounts: ['HDFC Debit card ··3016'], patch: {'HDFC Debit card ··3016': {'linked_account_id': hdfc}});
      expect(_scan(open, [debit]).created.single.$2.accountId, _accountId(open, 'HDFC Debit card ··3016'));
      final closed = _seed(
        closed: {'HDFC ··4821'},
        accounts: ['HDFC Debit card ··3016'],
        patch: {'HDFC Debit card ··3016': {'linked_account_id': hdfc}},
      );
      expect(_scan(closed, [debit]).created.single.$2.accountId, isNull);
      final onCard = _seed(accounts: ['HDFC Card ··3016'], patch: {'HDFC Card ··3016': {'linked_account_id': card}});
      final input = smsScanInput(onCard, const [], const Features());
      expect(input.accountsByLabel['HDFC Card ··3016']?.type, AccountType.creditCard);
    });

    test('an entry you made by hand gets the account with the message', () {
      final out = _scan(seed, [
        _hdfc('Rs.1860.00 debited from a/c **4821 on 19-09-26 to VPA bigbasket@hdfcbank(UPI Ref No 626200000002).', 19),
      ]);
      expect(out.attached.single.accountId, _accountId(seed, 'HDFC ··4821'));
      expect(out.created, isEmpty);
    });
  });

  group('refunds', () {
    test('match the spend by merchant, in its category and account, or are money back on their own', () {
      final swiggy = seed.rawPersonal(_swiggyOrder)!;
      final out = _scan(seed, [
        _hdfc(
          'Rs.486.00 credited to HDFC Bank A/c XX4821 on 24-09-26 by a/c linked to VPA swiggy.stores@icici as a refund '
          '(UPI Ref No 626900000099).',
          24,
        ),
        _hdfc('Refund of Rs.799.00 from DECATHLON credited to HDFC Bank A/c XX4821 on 24-09-26.', 24, minute: 5),
      ]);
      final [(_, matched), (_, alone)] = out.created;
      expect(
        (matched.type, matched.direction, matched.refundOfId, matched.categoryId, matched.accountId),
        (
          PersonalTxnInTypeEnum.refund,
          PersonalTxnInDirectionEnum.in_,
          _swiggyOrder,
          swiggy['category_id'],
          _accountId(seed, 'HDFC ··4821'),
        ),
      );
      final categories = seed.learnedCategories('personal');
      expect(
        (alone.type, alone.refundOfId, alone.categoryId),
        (PersonalTxnInTypeEnum.refund, null, personalCategory(categories, 'Decathlon', merchant: 'DECATHLON')),
      );
    });

    test('match by reference first, a spend read in the same read, and only what is left to refund', () {
      final out = _scan(seed, [
        // The Rapido ride's own reference, reversed by another bank's message.
        _sms(
          'JD-SBIUPI-S',
          'Dear UPI user, Rs.400.00 debited from A/c X4821 on 21Sep26 for UPI txn to RAPIDO has been reversed. '
              'Refno 426401938271 -SBI',
          21,
        ),
        _hdfc('Sent Rs.1,200.00\nFrom HDFC Bank A/C *4821\nTo DECATHLON\nOn 20/09/26\nRef 626300000004\nNot You?', 20),
        _hdfc('Refund of Rs.1,000.00 from DECATHLON credited to HDFC Bank A/c XX4821 on 23-09-26.', 23),
        // ₹200 of the ₹1,200 is left: this one is for no spend we know.
        _hdfc('Refund of Rs.300.00 from DECATHLON credited to HDFC Bank A/c XX4821 on 23-09-26.', 23, minute: 5),
      ]);
      final byDescription = <String, List<String?>>{};
      for (final (_, t) in out.created) {
        (byDescription[t.type.value] ??= []).add(t.refundOfId);
      }
      final decathlon = out.created.firstWhere((c) => c.$2.type == PersonalTxnInTypeEnum.expense).$1;
      expect(byDescription['refund'], [_rapidoRide, decathlon, null]);
    });

    test('a spend refunded in full already is no refund target', () {
      final message = _hdfc(
        'Rs.486.00 credited to HDFC Bank A/c XX4821 on 24-09-26 by a/c linked to VPA swiggy.stores@icici as a refund '
        '(UPI Ref No 626900000099).',
        24,
      );
      final refunded = _seed(
        entries: [
          {
            'id': 'a0000000-0000-4000-8000-0000000000aa',
            'type': 'refund',
            'direction': 'in',
            'amount_minor': 48600,
            'currency': 'INR',
            'date': '2026-09-23',
            'description': 'Swiggy refund',
            'account': 'HDFC ··4821',
            'source': 'manual',
            'refund_of_id': _swiggyOrder,
            'created_at': '2026-09-23T12:00:00+00:00',
            'deleted_at': null,
            'version': 1,
          },
        ],
      );
      expect(_scan(seed, [message]).created.single.$2.refundOfId, _swiggyOrder);
      expect(_scan(refunded, [message]).created.single.$2.refundOfId, isNull);
    });

    test('with refunds off, are skipped as before', () {
      final out = _scan(seed, [
        _hdfc('Refund of Rs.799.00 from DECATHLON credited to HDFC Bank A/c XX4821 on 24-09-26.', 24),
      ], features: const Features(refunds: false));
      expect(out.created, isEmpty);
      expect(out.skipped.single.reason, SmsSkip.refund);
    });
  });

  group('cash withdrawals', () {
    final atm = _hdfc(
      'Rs.2000.00 withdrawn at ATM HDFC0001234 from A/c XX4821 on 24-09-26. Avl Bal: Rs.40,276.50 Not you? Call 18002586161',
      24,
    );

    test('with a Cash account, are a transfer into it', () {
      final out = _scan(seed, [atm]);
      final id = smsEntryId(me, atm, (parseSms(atm) as SmsParsed).txn);
      final group = transferGroupIdFor(id);
      final [(bankId, bank), (cashId, cash)] = out.created;
      expect((bankId, cashId), (id, pairedLegId(id)));
      for (final (leg, account, direction) in [
        (bank, _accountId(seed, 'HDFC ··4821'), PersonalTxnInDirectionEnum.out_),
        (cash, _accountIdByName(seed, 'Cash'), PersonalTxnInDirectionEnum.in_),
      ]) {
        expect(
          (
            leg.type,
            leg.direction,
            leg.accountId,
            leg.transferGroupId,
            leg.description,
            leg.categoryId,
            leg.amountMinor,
          ),
          (PersonalTxnInTypeEnum.transfer, direction, account, group, 'Cash withdrawal', null, 200000),
        );
      }
      expect(
        (bank.source_, bank.balanceMinor, cash.source_),
        (PersonalTxnInSource_Enum.sms, 4027650, PersonalTxnInSource_Enum.manual),
      );
      expect(out.bodies.keys, [id]);
    });

    test('without one (or with atmToCash off, or out of a closed account), countAtmAsSpending decides', () {
      for (final (ledger, atmToCash) in [
        (_seed(closed: {'Cash'}), true),
        (seed, false),
        (_seed(closed: {'HDFC ··4821'}), true),
      ]) {
        for (final spending in [true, false]) {
          final out = _scan(ledger, [atm], features: Features(atmToCash: atmToCash, countAtmAsSpending: spending));
          expect([for (final (_, t) in out.created) t.type], [if (spending) PersonalTxnInTypeEnum.expense]);
        }
      }
    });
  });

  group('card bills', () {
    final rapidoBill = _sms(
      'VM-ICICIT-S',
      'Dear Customer, Payment of INR 400.00 has been received on your ICICI Bank Credit Card Account 4xxx9012 on '
          '22-Sep-26. Thank you.',
      22,
    );

    test('pair with the one payment of the bill out of a bank account: an entry here becomes its other half', () {
      final out = _scan(seed, [rapidoBill]);
      final cardLeg = smsEntryId(me, rapidoBill, (parseSms(rapidoBill) as SmsParsed).txn);
      final group = transferGroupIdFor(cardLeg);
      expect(out.convert, [(id: _rapidoRide, version: 1, flow: MoneyFlow.outflow, groupId: group)]);
      final (id, leg) = out.created.single;
      expect(
        (id, leg.type, leg.direction, leg.accountId, leg.transferGroupId, leg.description),
        (
          cardLeg,
          PersonalTxnInTypeEnum.transfer,
          PersonalTxnInDirectionEnum.in_,
          _accountId(seed, 'ICICI Credit card ··9012'),
          group,
          'Credit card bill',
        ),
      );
    });

    test('pair with a payment read in the same read, before or after it', () {
      final debit = _hdfc(
        'Rs.4,321.00 debited from HDFC Bank A/c XX4821 on 24-09-26 towards ICICI CREDIT CARD via NetBanking. '
        'Avl bal Rs.30,000.00',
        24,
        minute: 30,
      );
      final bill = _sms(
        'VM-ICICIT-S',
        'Dear Customer, Payment of INR 4,321.00 has been received on your ICICI Bank Credit Card Account 4xxx9012 on '
            '24-Sep-26. Thank you.',
        24,
      );
      final out = _scan(seed, [bill, debit]);
      expect(out.convert, isEmpty);
      final legs = {for (final (id, t) in out.created) id: t};
      final txn = (parseSms(debit) as SmsParsed).txn;
      final bank = legs[smsEntryId(me, debit, txn)]!;
      final card = legs[smsEntryId(me, bill, (parseSms(bill) as SmsParsed).txn)]!;
      expect(
        (bank.type, bank.direction, bank.categoryId, bank.description, bank.accountId),
        (
          PersonalTxnInTypeEnum.transfer,
          PersonalTxnInDirectionEnum.out_,
          null,
          'Credit card bill',
          _accountId(seed, 'HDFC ··4821'),
        ),
      );
      expect((card.direction, card.transferGroupId), (PersonalTxnInDirectionEnum.in_, bank.transferGroupId));
    });

    test('with no payment, two, or with pairCardBills off, are skipped', () {
      final unpaid = _sms(
        'VM-ICICIT-S',
        'Dear Customer, Payment of INR 7,777.00 has been received on your ICICI Bank Credit Card Account 4xxx9012 on '
            '24-Sep-26. Thank you.',
        24,
      );
      expect(_scan(seed, [unpaid]).skipped.single.reason, SmsSkip.cardBill);
      // A second ₹400 out of HDFC two days after the ride: which one paid the bill isn't clear.
      final two = _scan(seed, [
        _hdfc('Rs.400.00 debited from HDFC Bank A/c XX4821 on 23-09-26 towards SWIGGY via NetBanking.', 23),
        rapidoBill,
      ]);
      expect(two.convert, isEmpty);
      expect(two.skipped.single.reason, SmsSkip.cardBill);
      final off = _scan(seed, [rapidoBill], features: const Features(pairCardBills: false));
      expect([...off.convert, ...off.created], isEmpty);
      expect(off.skipped.single.reason, SmsSkip.cardBill);
    });
  });

  group('own transfers', () {
    final out25k = _hdfc(
      'Rs.25,000.00 debited from HDFC Bank A/c XX4821 on 24-09-26 for self transfer to A/c XX9911 (IMPS Ref No '
      '628712345602). Avl bal: Rs.20,276.50',
      24,
    );
    final in25k = _sms(
      'VM-ICICIB-S',
      'ICICI Bank Acct XX9911 credited with Rs 25,000.00 on 24-Sep-26 by self transfer from HDFC Bank A/c XX4821. '
          'IMPS:628712345602.',
      24,
      minute: 1,
    );

    test('pair with the other half in the same read: both are made, in their accounts', () {
      final out = _scan(seed, [out25k, in25k]);
      final outId = smsEntryId(me, out25k, (parseSms(out25k) as SmsParsed).txn);
      final inId = smsEntryId(me, in25k, (parseSms(in25k) as SmsParsed).txn);
      final icici = smsAccountId(me, 'ICICI ··9911');
      expect(out.newAccounts.single.id, icici);
      expect(
        [for (final (id, t) in out.created) (id, t.type, t.direction, t.accountId, t.transferGroupId, t.description)],
        [
          (
            outId,
            PersonalTxnInTypeEnum.transfer,
            PersonalTxnInDirectionEnum.out_,
            _accountId(seed, 'HDFC ··4821'),
            transferGroupIdFor(outId, inId),
            'Self transfer',
          ),
          (
            inId,
            PersonalTxnInTypeEnum.transfer,
            PersonalTxnInDirectionEnum.in_,
            icici,
            transferGroupIdFor(outId, inId),
            'Self transfer',
          ),
        ],
      );
    });

    test('pair with an entry here (it becomes the other half), the nearest first', () {
      final salary = _sms(
        'VM-ICICIB-S',
        'Rs.85,000.00 debited from ICICI Bank Acct XX123 on 01-Sep-26 for self transfer to A/c XX4821. IMPS Ref No '
            '624400000001.',
        1,
        hour: 9,
        minute: 10, // 03:40 UTC, ten minutes after the salary came in
      );
      final out = _scan(seed, [salary]);
      final id = smsEntryId(me, salary, (parseSms(salary) as SmsParsed).txn);
      expect(out.convert, [
        (id: _salary, version: 1, flow: MoneyFlow.inflow, groupId: transferGroupIdFor(id, _salary)),
      ]);
      expect(
        (out.created.single.$2.direction, out.created.single.$2.accountId),
        (PersonalTxnInDirectionEnum.out_, smsAccountId(me, 'ICICI ··123')),
      );
      // A plain income read in the same read, nearer in time, is the other half instead.
      final nearer = _sms(
        'VM-ICICIB-S',
        'Dear Customer, Acct XX9911 is credited with Rs 85,000.00 on 01-Sep-26 from JOHN D. UPI:624400000002-ICICI Bank.',
        1,
        hour: 9,
        minute: 12,
      );
      final both = _scan(seed, [salary, nearer]);
      expect(both.convert, isEmpty);
      expect(
        [for (final (_, t) in both.created) t.type],
        [PersonalTxnInTypeEnum.transfer, PersonalTxnInTypeEnum.transfer],
      );
    });

    test('with no other half, or the halves too far apart, are skipped', () {
      final alone = _scan(seed, [
        _sms(
          'VM-SBIINB-S',
          'Your A/C XXXXX4821 debited INR 10,000.00 on 24/09/26 transferred to your own A/c XXXXX9911. -SBI',
          24,
        ),
      ]);
      expect([...alone.created, ...alone.newAccounts], isEmpty);
      expect(alone.skipped.single.reason, SmsSkip.ownTransfer);
      final late = RawSms(
        address: in25k.address,
        body: in25k.body,
        receivedAt: in25k.receivedAt.add(const Duration(hours: 1)),
      );
      final apart = _scan(seed, [out25k, late]);
      expect(apart.skipped.map((s) => s.reason), [SmsSkip.ownTransfer, SmsSkip.ownTransfer]);
    });
  });
}

const _swiggyOrder = '7519b197-caab-50b4-83b7-16f72b5b9456';
const _rapidoRide = '51a715d3-f751-52e0-bc5c-0d7422e3ca0d';
const _salary = '2676dd92-8311-501e-8c3c-c03c47f029bd'; // September's, into HDFC at 03:30 UTC

/// John, the seed's user.
final me = _seed().me;

/// The seed's sync snapshot as a Ledger, with the accounts named in [closed] closed and in
/// [deleted] deleted, [patch] applied to accounts by name, and [entries] (personal entries' data)
/// and [accounts] (bank accounts with these labels, each patched by [patch] too) added.
Ledger _seed({
  Set<String> closed = const {},
  Set<String> deleted = const {},
  List<Map<String, dynamic>> entries = const [],
  List<String> accounts = const [],
  Map<String, Map<String, dynamic>> patch = const {},
}) {
  final fixture = jsonDecode(File('test/fixtures/sync/john.json').readAsStringSync()) as Map<String, dynamic>;
  final snapshots = (fixture['snapshots'] as Map).cast<String, dynamic>();
  final user = snapshots.keys.firstWhere((k) => k.startsWith('user:'));
  return Ledger([
    for (final s in snapshots.entries)
      for (final e in ((s.value as Map)['entities'] as List).cast<Map<String, dynamic>>())
        LocalEntity(s.key, e['entity'], e['entity_id'], e['version'], {
          ...(e['data'] as Map).cast<String, dynamic>(),
          if (e['entity'] == 'personal_account' && closed.contains(e['data']['name'])) 'status': 'closed',
          if (e['entity'] == 'personal_account' && deleted.contains(e['data']['name']))
            'deleted_at': '2026-09-24T00:00:00+00:00',
          if (e['entity'] == 'personal_account') ...?patch[e['data']['name']],
        }),
    for (final t in entries) LocalEntity(user, 'personal_transaction', t['id'], 1, t),
    for (final label in accounts)
      LocalEntity(user, 'personal_account', smsAccountId(user.substring(5), label), 1, {
        'id': smsAccountId(user.substring(5), label),
        'user_id': user.substring(5),
        'name': label,
        'type': 'bank',
        'currency': 'INR',
        'opening_balance_minor': 0,
        'sms_label': label,
        'status': 'active',
        'created_at': '2026-09-01T00:00:00+00:00',
        'deleted_at': null,
        ...?patch[label],
      }),
  ]);
}

String _accountId(Ledger l, String label) =>
    l.personalAccountList(deleted: false).firstWhere((a) => a['sms_label'] == label)['id'] as String;

String _accountIdByName(Ledger l, String name) =>
    l.personalAccountList(deleted: false).firstWhere((a) => a['name'] == name)['id'] as String;

SmsScanResult _scan(Ledger ledger, List<RawSms> messages, {Features features = const Features()}) =>
    scanSms(smsScanInput(ledger, messages, features));

/// A message from [sender] that came on [day] September 2026 (local time).
RawSms _sms(String sender, String body, int day, {int hour = 10, int minute = 0}) =>
    RawSms(address: sender, body: body, receivedAt: DateTime(2026, 9, day, hour, minute));

RawSms _hdfc(String body, int day, {int minute = 0}) => _sms('VM-HDFCBK-S', body, day, minute: minute);

RawSms _icici(String body, int day) => _sms('VM-ICICIT-S', body, day);

/// A scan's output as plain JSON, to compare (an account's opening balance is checked on its own).
Object _normal(SmsScanResult r) => jsonDecode(
  jsonEncode({
    'accounts': [
      for (final a in r.newAccounts) [a.id, a.label, a.type.wire],
    ],
    'created': [
      for (final (id, body) in r.created) [id, body.toJson()],
    ],
    'attached': [
      for (final a in r.attached) [a.entryId, a.merchant, a.account, a.channel, a.smsId, a.accountId],
    ],
    'convert': [
      for (final c in r.convert) [c.id, c.version, c.flow.wire, c.groupId],
    ],
    'skipped': [
      for (final s in r.skipped) [s.sms.toJson(), s.reason.name],
    ],
    'bodies': r.bodies,
    'known': r.known,
  }),
);

/// The importer's `_Read` as it was before the scan moved to core/sms/sms_scan.dart, word for
/// word apart from how it's given its input, and with each entry put in the account for its label
/// (an open one with it; none for a closed or deleted one; else the one made for it, smsAccountId):
/// what the scan must keep doing for payments. Give it no refunds, card bills or own transfers.
class _ReferenceRead {
  _ReferenceRead(this.ledger, this.features, this._attachedBefore) : _references = ledger.personalReferences();

  final Ledger ledger;
  final Features features;
  final Set<String> _attachedBefore;
  final Set<String> _references;
  final _ids = <String>{};

  final created = <(String, PersonalTxnIn)>[];

  /// The entry, what the message said, the message's id, and the account it's given.
  final attached = <(PersonalTxnOut, SmsTxn, String, String?)>[];
  final skipped = <({RawSms sms, SmsSkip reason})>[];
  final bodies = <String, Object?>{};
  var known = 0;

  /// Labels with no account, in the order an entry is put in the account made for each.
  final made = <String>[];

  void addAll(List<RawSms> messages) => messages.forEach(add);

  void add(RawSms sms) {
    switch (parseSms(sms)) {
      case SmsSkipped(:final reason):
        // Not kept: codes, and anything not from a bank.
        if (reason != SmsSkip.otp && reason != SmsSkip.notABank) skipped.add((sms: sms, reason: reason));
      case SmsParsed(:final txn):
        expect(txn.kind, SmsKind.payment);
        _payment(sms, txn);
    }
  }

  /// The account an entry with [label] goes in.
  String? _accountFor(String? label, {required bool put}) {
    if (label == null) return null;
    for (final deleted in const [false, true]) {
      for (final a in ledger.personalAccountList(deleted: deleted)) {
        if (a['sms_label'] == label) return !deleted && a['status'] == 'active' ? a['id'] as String : null;
      }
    }
    if (put && !made.contains(label)) made.add(label);
    return smsAccountId(ledger.me, label);
  }

  void _payment(RawSms sms, SmsTxn txn) {
    final id = smsEntryId(ledger.me, sms, txn);
    final type = txn.direction == SmsDirection.spent ? 'expense' : 'income';
    final ref = txn.reference == null ? null : '${txn.reference}|$type';
    // Already here: read before (even if deleted since), or another message about it.
    if (!_ids.add(id) ||
        ledger.rawPersonal(id) != null ||
        _attachedBefore.contains(id) ||
        (ref != null && _references.contains(ref))) {
      known++;
      return;
    }
    if (ref != null) _references.add(ref);
    if (txn.channel == 'atm' && !features.countAtmAsSpending) return;
    // Entered by hand already: give that entry the bank's details instead.
    if (ledger.manualMatch(type, txn.amountMinor, txn.date) case final manual?) {
      final out = PersonalTxnOut.fromJson(manual)!;
      if (!attached.any((a) => a.$1.id == out.id)) {
        attached.add((out, txn, id, out.accountId == null ? _accountFor(txn.account, put: true) : null));
        return;
      }
    }
    final description = smsDescription(txn);
    final income = type == 'income';
    final justIn = sms.receivedAt.isAfter(appClock.now().subtract(Duration(days: features.justInBackfillDays)));
    created.add((
      id,
      PersonalTxnIn(
        type: PersonalTxnInTypeEnum.fromJson(type)!,
        amountMinor: txn.amountMinor,
        description: description,
        date: apiDate(txn.date),
        categoryId: features.suggestCategories
            ? categoryFor(
                ledger,
                description,
                scope: 'personal',
                merchant: txn.merchant,
                income: income,
                learn: features.learnCategories,
                fuzzy: false,
              )
            : null,
        channel: PersonalTxnInChannelEnum.fromJson(txn.channel),
        merchant: txn.merchant,
        account: txn.account,
        accountId: _accountFor(txn.account, put: true),
        direction: income ? PersonalTxnInDirectionEnum.in_ : PersonalTxnInDirectionEnum.out_,
        reference: txn.reference,
        balanceMinor: txn.balanceMinor,
        smsAt: sms.receivedAt.toUtc(),
        source_: PersonalTxnInSource_Enum.sms,
        // A first read going back months: only the last few days are "just in".
        reviewed: !justIn,
      ),
    ));
    bodies['sms.body.$id'] = sms.toJson();
  }

  Object normal() => jsonDecode(
    jsonEncode({
      'accounts': [
        for (final label in made) [smsAccountId(ledger.me, label), label, accountTypeForLabel(label).wire],
      ],
      'created': [
        for (final (id, body) in created) [id, body.toJson()],
      ],
      'attached': [
        for (final (out, txn, id, accountId) in attached)
          [out.id, txn.merchant, txn.account, txn.channel, id, accountId],
      ],
      'convert': [],
      'skipped': [
        for (final s in skipped) [s.sms.toJson(), s.reason.name],
      ],
      'bodies': {for (final MapEntry(:key, :value) in bodies.entries) key.substring('sms.body.'.length): value},
      'known': known,
    }),
  );
}
