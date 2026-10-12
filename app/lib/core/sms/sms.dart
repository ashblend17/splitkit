/// A text message as the phone's inbox has it.
class RawSms {
  const RawSms({required this.address, required this.body, required this.receivedAt});

  /// The sender: a business header ("VM-HDFCBK-S", "AD-ICICIT") or a phone number.
  final String address;
  final String body;
  final DateTime receivedAt;

  Map<String, Object?> toJson() => {'address': address, 'body': body, 'received_at': receivedAt.toUtc().toIso8601String()};

  static RawSms fromJson(Map<String, Object?> j) => RawSms(
    address: j['address']! as String,
    body: j['body']! as String,
    receivedAt: DateTime.parse(j['received_at']! as String),
  );
}

enum SmsDirection { spent, received }

/// A payment a bank told you about.
class SmsTxn {
  const SmsTxn({
    required this.direction,
    required this.amountMinor,
    required this.channel,
    required this.date,
    this.bank,
    this.account,
    this.merchant,
    this.reference,
    this.balanceMinor,
  });

  final SmsDirection direction;

  /// In paise. Messages in other currencies are skipped.
  final int amountMinor;

  /// upi, card, bank (a transfer), atm or other: personal_transactions.channel.
  final String channel;

  /// The day it happened, as the message says (else the day it arrived).
  final DateTime date;

  /// "HDFC", "ICICI", "SBI", …
  final String? bank;

  /// "HDFC ··4821", "ICICI Credit card ··9012": the label the app keeps per account.
  final String? account;

  /// Who was paid, or paid you, as the bank wrote it: "SWIGGY", "RAHUL SHARMA",
  /// "zomato.payu@axisbank". merchant_names.dart makes it readable.
  final String? merchant;

  /// The bank's reference: a UPI or IMPS number, an NEFT UTR.
  final String? reference;

  /// The account balance the message reported after this, if it did (cards report a limit).
  final int? balanceMinor;

  @override
  String toString() =>
      'SmsTxn(${direction.name} $amountMinor $channel ${date.toIso8601String().substring(0, 10)} '
      'account: $account, merchant: $merchant, reference: $reference, balance: $balanceMinor)';
}

/// Why a message isn't a payment to add.
enum SmsSkip {
  /// From a phone number or a sender that isn't a bank.
  notABank,

  /// A promotional (-P) sender.
  promotional,

  /// A one-time password. Never stored, not even on the phone.
  otp,

  /// Something that will happen, or is asked for: "will be debited", a due date, a collect
  /// request.
  notYet,
  failed,

  /// Refunds and reversals (not netted against the spend yet: ISSUES.md).
  refund,
  statement,

  /// Paying off a credit card: the spending was already counted, card spend by card spend.
  cardBill,

  /// Between your own accounts.
  ownTransfer,

  /// In a currency other than rupees.
  foreignCurrency,

  /// From a bank, but no money moved (a balance alert, an offer).
  noTransaction,
}

sealed class SmsVerdict {
  const SmsVerdict();
}

final class SmsParsed extends SmsVerdict {
  const SmsParsed(this.txn);
  final SmsTxn txn;
}

final class SmsSkipped extends SmsVerdict {
  const SmsSkipped(this.reason);
  final SmsSkip reason;
}
