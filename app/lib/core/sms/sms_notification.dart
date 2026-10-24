import '../copy/copy.dart';
import '../money/money.dart';
import 'merchant_names.dart';
import 'sms.dart';
import 'sms_parser.dart';

/// What a bank SMS notification says, or null when the message isn't a payment to add (nor
/// a refund: own transfers and card bills move money you already have).
/// Title "₹450 at Swiggy", "₹2,500 from Rahul Sharma" or "₹450 refund from Swiggy", text
/// "HDFC ··4821 · UPI"; [split] for spending (it can be split).
({String title, String text, bool split})? describeForNotification(RawSms sms, {Set<String> testSenders = const {}}) {
  final verdict = parseSms(sms, testSenders: testSenders);
  if (verdict is! SmsParsed) return null;
  final txn = verdict.txn;
  if (txn.kind == SmsKind.ownTransfer || txn.kind == SmsKind.cardBill) return null;
  final amount = formatMinor(txn.amountMinor, currency: 'INR');
  final who = txn.merchant == null ? null : merchantName(txn.merchant!);
  final spent = txn.direction == SmsDirection.spent;
  return (
    title: txn.kind == SmsKind.refund
        ? (who == null ? '$amount refund' : '$amount refund from $who')
        : spent
        ? (who == null ? '$amount · ${smsDescription(txn)}' : '$amount at $who')
        : (who == null ? '$amount received' : '$amount from $who'),
    text: [?txn.account, ?channelLabels[txn.channel]].join(' · '),
    split: spent,
  );
}
