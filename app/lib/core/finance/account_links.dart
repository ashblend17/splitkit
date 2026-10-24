/// Which of your accounts a bank SMS label is, beyond the account that has it: one you gave the
/// full number of, or a card whose messages name it two ways. And pairs of accounts that look
/// like one, offered for linking ([FinAccount.linkedAccountId]).
///
/// Labels are what sms_parser.dart writes: "HDFC ··4821" for an account, "ICICI Credit card
/// ··9012", "ICICI Debit card ··4455" or "HDFC Card ··5678" (the message didn't say which kind)
/// for a card.
library;

import '../sms/banks.dart';
import 'balances.dart';
import 'model.dart';

/// A bank SMS label read back.
final class LabelParts {
  const LabelParts({required this.bank, required this.card, required this.digits});

  /// The bank's name as labels give it ("HDFC"), or null when the label says only "Bank".
  final String? bank;

  /// For a card: 'credit', 'debit', or '' when the message didn't say; null for an account.
  final String? card;

  /// The last digits the bank showed.
  final String digits;

  bool get isCard => card != null;
}

final _labelShape = RegExp(r'^(.+?)(?: (Credit card|Debit card|Card))? ··(\d{3,})$');

/// [label]'s parts, or null for a label not in the parser's shape (one typed by hand).
LabelParts? labelParts(String? label) {
  final m = label == null ? null : _labelShape.firstMatch(label);
  if (m == null) return null;
  final bank = m[1]!;
  return LabelParts(
    bank: bank == 'Bank' ? null : bank,
    card: switch (m[2]) {
      'Credit card' => 'credit',
      'Debit card' => 'debit',
      'Card' => '',
      _ => null,
    },
    digits: m[3]!,
  );
}

/// The bank account [a] is with: its label's, else a bank its name names ("SBI savings").
String? bankOf(FinAccount a) {
  if (labelParts(a.smsLabel)?.bank case final bank?) return bank;
  final name = a.name.toLowerCase();
  for (final b in banks) {
    if (RegExp('\\b${RegExp.escape(b.name.toLowerCase())}\\b').hasMatch(name)) return b.name;
  }
  return null;
}

/// Whether [a] is a card: a credit card, or labelled as one.
bool _isCard(FinAccount a) => a.type == AccountType.creditCard || (labelParts(a.smsLabel)?.isCard ?? false);

/// Whether [label] is account [a] by its full number: the label's digits end it, it's the same
/// kind (a card's digits are the card's, not the account's), and of the same bank, or with at
/// least 4 digits when [a]'s bank isn't known.
bool numberMatches(FinAccount a, LabelParts label) {
  final number = a.accountNumber;
  if (number == null || label.isCard != _isCard(a) || !number.endsWith(label.digits)) return false;
  final bank = bankOf(a);
  return bank != null ? bank == label.bank : label.digits.length >= 4;
}

/// Whether [a] and [b] are labelled as the same card of the same bank, worded differently: HDFC's
/// spends say "HDFC Bank Card 5678" and its bills "HDFC Bank Credit Card ending 5678" (ISS-088).
bool _sameCard(LabelParts? a, LabelParts? b) =>
    a != null && b != null && a.isCard && b.isCard && a.bank != null && a.bank == b.bank && a.digits == b.digits;

/// The account a bank SMS [label] no account has goes in, of [accounts] (live ones), or null to
/// make one: the one whose full number its digits end ([numberMatches]), or a card of the same
/// bank with the same digits labelled differently. Only when exactly one account fits.
FinAccount? accountForNewLabel(String label, Iterable<FinAccount> accounts) {
  final parts = labelParts(label);
  if (parts == null) return null;
  final fits = [
    for (final a in accounts)
      if (!a.deleted && (numberMatches(a, parts) || _sameCard(parts, labelParts(a.smsLabel)))) a,
  ];
  return fits.length == 1 ? fits.single : null;
}

/// Two accounts that look like one: [part] could be linked to [whole].
final class SameAccount {
  const SameAccount({required this.whole, required this.part, required this.why});

  final FinAccount whole, part;

  /// Why they look the same, to follow "[part] looks like part of [whole]: ".
  final String why;

  /// The pair, whichever way round: what "Not the same" remembers.
  String get key => ([whole.id, part.id]..sort()).join('|');
}

/// A bank account that a credit card's messages went into (labelled "HDFC Card ··5678", whose
/// bills say "Credit card"): offered as "Make it a credit card".
final class LooksLikeCard {
  const LooksLikeCard(this.account, this.label);

  final FinAccount account;

  /// The credit card label its entries carry.
  final String label;
}

/// The pairs of [balances]' accounts that look like one account, most certain first: the same
/// bank with digits one of which ends the other ("HDFC ··7778" and "HDFC ··787778"), a full
/// number another's label ends, the same card labelled two ways, and a debit card of a bank you
/// have exactly one account with. Only accounts that count on their own, aren't closed or
/// investment accounts, and share a currency; none in [dismissed] (by [SameAccount.key]).
List<SameAccount> sameAccounts(List<AccountBalance> balances, {Set<String> dismissed = const {}}) {
  final open = [
    for (final b in balances)
      if (!b.account.closed && b.account.type != AccountType.investment && b.account.linkedAccountId == null) b,
  ];
  final parts = {for (final b in open) b.account.id: labelParts(b.account.smsLabel)};
  final count = {for (final b in open) b.account.id: b.entryCount};
  // The one to keep: the one with a number, else more entries, else the older (the order given).
  (FinAccount, FinAccount) keepFirst(FinAccount x, FinAccount y) {
    if ((x.accountNumber == null) != (y.accountNumber == null)) return x.accountNumber != null ? (x, y) : (y, x);
    return count[y.id]! > count[x.id]! ? (y, x) : (x, y);
  }

  final out = <SameAccount>[];
  final seen = <String>{};
  void add(FinAccount whole, FinAccount part, String why) {
    final s = SameAccount(whole: whole, part: part, why: why);
    if (dismissed.contains(s.key) || !seen.add(s.key)) return;
    out.add(s);
  }

  for (final (i, bx) in open.indexed) {
    for (final by in open.skip(i + 1)) {
      final x = bx.account, y = by.account;
      if (x.currency != y.currency) continue;
      final px = parts[x.id], py = parts[y.id];
      final xHasY = py != null && numberMatches(x, py), yHasX = px != null && numberMatches(y, px);
      if (xHasY || yHasX) {
        final (whole, part) = xHasY ? (x, y) : (y, x);
        add(whole, part, "${whole.name}'s number ends in ${parts[part.id]!.digits}");
      } else if (px != null && py != null && !px.isCard && !py.isCard && px.bank != null && px.bank == py.bank) {
        final (short, long) = px.digits.length <= py.digits.length ? (px, py) : (py, px);
        if (long.digits.endsWith(short.digits)) {
          final (whole, part) = keepFirst(x, y);
          add(whole, part, 'the same bank, and ${long.digits} ends in ${short.digits}');
        }
      } else if (_sameCard(px, py)) {
        // Keep the credit card: the bills say what it is.
        final xCredit = x.type == AccountType.creditCard || px!.card == 'credit';
        final yCredit = y.type == AccountType.creditCard || py!.card == 'credit';
        final (whole, part) = xCredit == yCredit ? keepFirst(x, y) : (xCredit ? (x, y) : (y, x));
        add(whole, part, 'the same ${px!.bank} card, ending ${px.digits}');
      }
    }
  }
  // A debit card, when its bank has exactly one account here.
  for (final b in open) {
    final p = parts[b.account.id];
    if (p == null || p.card != 'debit' || p.bank == null) continue;
    final accounts = [
      for (final o in open)
        if (o.account.type == AccountType.bank &&
            o.account.currency == b.account.currency &&
            !(parts[o.account.id]?.isCard ?? false) &&
            bankOf(o.account) == p.bank)
          o.account,
    ];
    if (accounts.length == 1) {
      final only = accounts.single;
      add(only, b.account, 'a debit card from ${p.bank}, and ${only.name} is your only ${p.bank} account');
    }
  }
  return out;
}

/// The bank accounts of [balances] that a credit card's messages went into: [cardLabelOf] gives
/// the credit card label an account's entries carry, if any. Offered as "Make it a credit card".
List<LooksLikeCard> looksLikeCards(List<AccountBalance> balances, String? Function(String accountId) cardLabelOf) => [
  for (final b in balances)
    if (b.account.type == AccountType.bank && !b.account.closed)
      if (cardLabelOf(b.account.id) case final label?) LooksLikeCard(b.account, label),
];
