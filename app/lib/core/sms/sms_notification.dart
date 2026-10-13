import '../copy/copy.dart';
import '../money/money.dart';
import 'merchant_names.dart';
import 'sms.dart';
import 'sms_parser.dart';

/// What a bank SMS notification says, or null when the message isn't a payment to add.
/// Title "₹450 at Swiggy" or "₹2,500 from Rahul Sharma", text "HDFC ··4821 · UPI"; [split]
/// for spending (it can be split).
({String title, String text, bool split})? describeForNotification(RawSms sms, {Set<String> testSenders = const {}}) {
  final verdict = parseSms(sms, testSenders: testSenders);
  if (verdict is! SmsParsed) return null;
  final txn = verdict.txn;
  final amount = formatMinor(txn.amountMinor, currency: 'INR');
  final who = txn.merchant == null ? null : merchantName(txn.merchant!);
  final spent = txn.direction == SmsDirection.spent;
  return (
    title: spent
        ? (who == null ? '$amount · ${smsDescription(txn)}' : '$amount at $who')
        : (who == null ? '$amount received' : '$amount from $who'),
    text: [?txn.account, ?channelLabels[txn.channel]].join(' · '),
    split: spent,
  );
}
