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

/// What a payment was, as far as the message says.
enum SmsKind {
  /// Spending or income.
  payment,

  /// Money back for a spend: a refund, reversal, cashback or chargeback. Always received.
  refund,

  /// Between two of your own accounts ("to your own A/c", "self transfer").
  ownTransfer,

  /// A credit card bill paid, as the card's bank tells it: money received on the card.
  cardBill,
}

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
    this.kind = SmsKind.payment,
    this.counterpartDigits,
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

  /// A payment, unless the message says it's a refund, a card bill or a transfer between your
  /// own accounts.
  final SmsKind kind;

  /// The other account or card an own transfer names, as its digits ("9911"), if it does.
  final String? counterpartDigits;

  @override
  String toString() =>
      'SmsTxn(${kind.name} ${direction.name} $amountMinor $channel ${date.toIso8601String().substring(0, 10)} '
      'account: $account, merchant: $merchant, reference: $reference, balance: $balanceMinor, '
      'counterpart: $counterpartDigits)';
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

  /// A refund or reversal the parser couldn't read (no amount or account). One it can read is
  /// an [SmsKind.refund] payment.
  refund,
  statement,

  /// A credit card bill paid that the parser couldn't read (no amount or card), or whose other
  /// half (the bank's payment) wasn't found. One it can read is an [SmsKind.cardBill] payment.
  cardBill,

  /// Between your own accounts: couldn't be read (no amount, direction or account), or the
  /// other half wasn't found. One it can read is an [SmsKind.ownTransfer] payment.
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
