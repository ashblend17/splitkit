import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/sms/merchant_names.dart';
import 'package:splitkit/core/sms/sms.dart';
import 'package:splitkit/core/sms/sms_ids.dart';
import 'package:splitkit/core/sms/sms_parser.dart';

/// Every message in test/fixtures/sms/corpus.json reads as it says. Only the fields a case
/// lists are checked, and the kind (a payment unless it says otherwise).
void main() {
  final corpus = (jsonDecode(File('test/fixtures/sms/corpus.json').readAsStringSync()) as Map)['messages'] as List;

  for (final c in corpus.cast<Map<String, dynamic>>()) {
    test(c['name'], () {
      final sms = RawSms(address: c['sender'], body: c['body'], receivedAt: DateTime.parse(c['received']).toLocal());
      final verdict = parseSms(sms);
      final expect_ = (c['expect'] as Map).cast<String, dynamic>();
      if (expect_['skip'] case final String reason) {
        expect(verdict, isA<SmsSkipped>().having((s) => s.reason.name, 'reason', reason), reason: '$verdict');
        return;
      }
      expect(verdict, isA<SmsParsed>(), reason: verdict is SmsSkipped ? 'skipped: ${verdict.reason}' : null);
      final txn = (verdict as SmsParsed).txn;
      final read = <String, Object?>{
        'kind': txn.kind.name,
        'direction': txn.direction.name,
        'amount_minor': txn.amountMinor,
        'account': txn.account,
        'channel': txn.channel,
        'merchant': txn.merchant,
        'reference': txn.reference,
        'balance_minor': txn.balanceMinor,
        'date': txn.date.toIso8601String().substring(0, 10),
        'description': smsDescription(txn),
        'counterpart_digits': txn.counterpartDigits,
      };
      final want = {'kind': 'payment', ...expect_};
      expect({for (final k in want.keys) k: read[k]}, want, reason: '$txn');
    });
  }

  test('a message that parsed before refunds, card bills and own transfers were read keeps its id', () {
    // Captured from the corpus with the parser as it was (test/fixtures/sms/ids.json). An id that
    // changes is the same payment added again on every phone that read it.
    final ids = jsonDecode(File('test/fixtures/sms/ids.json').readAsStringSync()) as Map<String, dynamic>;
    final messages = (ids['messages'] as List).cast<Map<String, dynamic>>();
    expect(messages, hasLength(32));
    for (final m in messages) {
      final sms = RawSms(address: m['sender'], body: m['body'], receivedAt: DateTime.parse(m['received']).toLocal());
      final verdict = parseSms(sms);
      expect(verdict, isA<SmsParsed>(), reason: m['name']);
      final txn = (verdict as SmsParsed).txn;
      expect(
        (smsEntryId(ids['user_id'], sms, txn), txn.direction.name, txn.amountMinor, txn.reference, txn.kind),
        (m['id'], m['direction'], m['amount_minor'], m['reference'], SmsKind.payment),
        reason: m['name'],
      );
    }
  });

  group('kinds', () {
    SmsVerdict parse(String sender, String body) =>
        parseSms(RawSms(address: sender, body: body, receivedAt: DateTime(2026, 10, 12, 12)));
    SmsTxn read(String sender, String body) => (parse(sender, body) as SmsParsed).txn;

    test('a skip that comes first in the list still decides', () {
      // Failed comes before refund: "will be refunded" doesn't make it one.
      expect(
        parse('VM-SBIUPI-S', 'Your UPI txn of Rs.500.00 from A/c X4821 has failed. Amount if debited will be refunded.'),
        isA<SmsSkipped>().having((s) => s.reason, 'reason', SmsSkip.failed),
      );
      // A refund that's a statement too is a refund (refund comes first).
      expect(
        parse('VM-HDFCBK-S', 'Refund of Rs.499.00 from AMAZON credited to HDFC Bank Card 5678. It will show on your statement.'),
        isA<SmsParsed>().having((p) => p.txn.kind, 'kind', SmsKind.refund),
      );
    });

    test('a reversal is money in, whatever verb comes first', () {
      final txn = read(
        'VM-HDFCBK-S',
        'Rs.320.00 debited from HDFC Bank A/c XX4821 on 12-10-26 to VPA zomato.payu@axisbank is reversed.',
      );
      expect((txn.kind, txn.direction, txn.amountMinor, txn.merchant), (
        SmsKind.refund,
        SmsDirection.received,
        32000,
        'zomato.payu@axisbank',
      ));
    });

    test('an own transfer naming one account has no counterpart', () {
      final txn = read('VM-SBIINB-S', 'Your A/C XXXXX4821 debited INR 5,000.00 on 12/10/26 as a self transfer. -SBI');
      expect((txn.kind, txn.direction, txn.account, txn.counterpartDigits), (
        SmsKind.ownTransfer,
        SmsDirection.spent,
        'SBI ··4821',
        null,
      ));
    });

    test('a card bill with no card number is one we couldn\'t read', () {
      expect(
        parse('VM-HDFCBK-S', 'Thank you for your payment of Rs.5,000.00 from HDFC Bank A/c XX4821.'),
        isA<SmsSkipped>().having((s) => s.reason, 'reason', SmsSkip.cardBill),
      );
    });
  });

  test('the corpus covers each bank it is tuned for, and what must be skipped', () {
    int count(String prefix) => corpus.where((c) => (c['name'] as String).startsWith(prefix)).length;
    expect([count('HDFC'), count('ICICI'), count('SBI')], everyElement(greaterThanOrEqualTo(15)));
    expect(corpus.where((c) => (c['expect'] as Map).containsKey('skip')).length, greaterThanOrEqualTo(20));
  });

  group('merchant names', () {
    test('readable, from what banks write', () {
      expect(
        [
          for (final raw in [
            'AMAZON PAY INDIA PRIVATE LIMITED',
            'zomato.payu@axisbank',
            'RAHUL SHARMA',
            'swiggy.stores@axb',
            'PVR CINEMAS',
            'ACME CORP',
          ])
            merchantName(raw),
        ],
        ['Amazon Pay', 'Zomato', 'Rahul Sharma', 'Swiggy', 'PVR Cinemas', 'Acme Corp'],
      );
    });

    test('a handle of numbers says nothing', () {
      expect(merchantName('9876543210@ybl'), isNull);
      expect(merchantName('Q12345678@ybl'), isNull);
    });
  });

  group('entry ids', () {
    SmsTxn txn(String? ref) => SmsTxn(
      direction: SmsDirection.spent,
      amountMinor: 45000,
      channel: 'upi',
      date: DateTime(2026, 10, 12),
      reference: ref,
    );
    final at = DateTime(2026, 10, 12, 13, 10);

    test('the same message gets the same id, whenever and however it arrives', () {
      final inbox = RawSms(address: 'VM-HDFCBK-S', body: 'Rs.450 debited  from a/c **4821', receivedAt: at);
      final delivered = RawSms(address: 'AD-HDFCBK', body: 'Rs.450 debited from a/c **4821', receivedAt: at.add(const Duration(seconds: 40)));
      expect(smsEntryId('me', inbox, txn(null)), smsEntryId('me', delivered, txn(null)));
      expect(smsEntryId('me', inbox, txn(null)), isNot(smsEntryId('someone else', inbox, txn(null))));
    });

    test('two messages about one UPI payment are one entry', () {
      final a = RawSms(address: 'JD-SBIUPI-S', body: 'A/C X4821 debited by 450.0 … Refno 627812345679', receivedAt: at);
      final b = RawSms(address: 'VM-SBIINB-S', body: 'Your A/c X4821 is debited Rs 450.00 UPI Ref 627812345679', receivedAt: at);
      expect(smsEntryId('me', a, txn('627812345679')), smsEntryId('me', b, txn('627812345679')));
    });
  });
}
