import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/sms/merchant_names.dart';
import 'package:splitkit/core/sms/sms.dart';
import 'package:splitkit/core/sms/sms_ids.dart';
import 'package:splitkit/core/sms/sms_parser.dart';

/// Every message in test/fixtures/sms/corpus.json reads as it says. Only the fields a case
/// lists are checked.
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
        'direction': txn.direction.name,
        'amount_minor': txn.amountMinor,
        'account': txn.account,
        'channel': txn.channel,
        'merchant': txn.merchant,
        'reference': txn.reference,
        'balance_minor': txn.balanceMinor,
        'date': txn.date.toIso8601String().substring(0, 10),
        'description': smsDescription(txn),
      };
      expect({for (final k in expect_.keys) k: read[k]}, expect_, reason: '$txn');
    });
  }

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
