import 'banks.dart';
import 'sms.dart';

/// Reads a bank SMS: whether money moved, which way, how much, through which account, to or
/// from whom, and what else the bank said (reference, balance, date). One grammar for every
/// bank, tuned against HDFC, ICICI and SBI messages (test/fixtures/sms/corpus.json); what it
/// doesn't recognise is skipped, never guessed.
///
/// [testSenders] are accepted although they aren't business headers (the emulator sends from
/// a number).
SmsVerdict parseSms(RawSms sms, {Set<String> testSenders = const {}}) {
  final address = sms.address.trim().toUpperCase();
  final header = senderHeader.firstMatch(address);
  if (header == null && !testSenders.contains(address)) return const SmsSkipped(SmsSkip.notABank);
  if (header?.group(2) == 'P') return const SmsSkipped(SmsSkip.promotional);

  final text = sms.body.replaceAll(RegExp(r'\s+'), ' ').trim();
  final lower = text.toLowerCase();
  // What it isn't, before reading anything: an OTP mentions an amount too. The first pattern
  // that matches decides: a skip, or a refund, card bill or own transfer, read on as that kind
  // (and skipped as it when it can't be read). A message that matches none reads as it always did.
  var (kind, unread) = (SmsKind.payment, SmsSkip.noTransaction);
  for (final (pattern, reason) in _skips) {
    if (!pattern.hasMatch(lower)) continue;
    final readAs = _kinds[reason];
    if (readAs == null) return SmsSkipped(reason);
    (kind, unread) = (readAs, reason);
    break;
  }
  if (_foreign.hasMatch(lower)) return const SmsSkipped(SmsSkip.foreignCurrency);
  if (kind == SmsKind.refund && _refundPending.hasMatch(lower)) return const SmsSkipped(SmsSkip.notYet);

  // Money back, and a card bill as the card's bank tells it, are always money in.
  final direction = kind == SmsKind.refund || kind == SmsKind.cardBill ? SmsDirection.received : _direction(lower);
  final amount = _amount(text);
  final bank = bankFor(header?.group(1), lower);
  // A card bill is about the card, even when it names the account it was paid from first.
  final account = _account(text, lower, bank, header?.group(1), cardOnly: kind == SmsKind.cardBill);
  // A bank message names an account or card; a shop's "your order of Rs 486" doesn't.
  if (direction == null || amount == null || account == null) return SmsSkipped(unread);

  final reference = _reference(text);
  final channel = _channel(lower, card: account.card, reference: reference);
  final names = kind == SmsKind.refund ? _refunders : (direction == SmsDirection.spent ? _payees : _payers);
  return SmsParsed(
    SmsTxn(
      direction: direction,
      amountMinor: amount,
      channel: channel,
      date: _date(lower, sms.receivedAt),
      bank: bank?.name,
      account: account.label,
      merchant: channel == 'atm' ? null : _merchant(text, names),
      reference: reference,
      balanceMinor: _balance(text),
      kind: kind,
      counterpartDigits: kind == SmsKind.ownTransfer ? _counterpart(text, account) : null,
    ),
  );
}

RegExp _re(String pattern, {bool caseSensitive = false}) => RegExp(pattern, caseSensitive: caseSensitive);

const _money = r'(?:rs\.?|inr|₹)\s*';
const _number = r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)';

final _skips = [
  // A code next to "OTP" (debit alerts say "never share your OTP" without one).
  (
    _re(
      r'\b(?:otp|one[\s-]?time[\s-]?password|verification code)\b[^.]{0,40}?\b\d{4,8}\b'
      r'|\b\d{4,8}\b[^.]{0,20}?\b(?:otp|one[\s-]?time[\s-]?password)\b',
    ),
    SmsSkip.otp,
  ),
  (
    _re(
      r'\bwill be (?:auto[\s-]?)?(?:debited|deducted|charged)\b|\bis due\b|\bdue (?:on|date|by)\b'
      r'|\brequested\b|\bcollect request\b|\bpayment request\b|\bscheduled\b|\bupcoming\b|\breminder\b',
    ),
    SmsSkip.notYet,
  ),
  (
    _re(
      r'\b(?:declined|failed|unsuccessful|rejected|insufficient (?:funds|balance))\b'
      r'|\bcould not be (?:processed|completed)\b|\bwas not successful\b',
    ),
    SmsSkip.failed,
  ),
  (_re(r'\b(?:refund(?:ed)?|reversed|reversal|cashback|chargeback)\b'), SmsSkip.refund),
  (
    _re(
      '\\bpayment of $_money[0-9,.]+ (?:has been |is )?received (?:on|towards|for) your [a-z ]*card\\b'
      '|\\breceived (?:your )?payment of $_money[0-9,.]+ towards your\\b|\\bthank you for (?:the |your )?payment\\b',
    ),
    SmsSkip.cardBill,
  ),
  (
    _re(r'\bstatement\b|\btotal (?:amt |amount )?due\b|\bmin(?:imum)?\.? (?:amt |amount )?due\b|\bbill (?:of|generated)\b'),
    SmsSkip.statement,
  ),
  (
    _re(r'\bto (?:your )?own (?:a/c|account)\b|\bself[\s-]transfer\b|\btransfer(?:red)? to self\b'),
    SmsSkip.ownTransfer,
  ),
];

/// The [_skips] that aren't skipped but read, as these kinds of payment.
const _kinds = {
  SmsSkip.refund: SmsKind.refund,
  SmsSkip.cardBill: SmsKind.cardBill,
  SmsSkip.ownTransfer: SmsKind.ownTransfer,
};

/// A refund on its way, not here yet: "has been initiated and will be credited in 5-7 days".
final _refundPending = _re(r'\binitiated\b|\bwill (?:be )?(?:credited|refunded|reversed|processed|reflect(?:ed)?)\b');

final _foreign = _re(r'\b(?:usd|eur|gbp|aed|sgd|aud|cad|jpy|chf|thb|myr)\s?[0-9][0-9,]*(?:\.[0-9]+)?\b|\$\s?[0-9]');

final _debit = _re(
  r'\b(?:debited|spent|sent|paid|withdrawn|purchased?|deducted|charged|transferred to|trf to)\b',
);
final _credit = _re(r'\b(?:credited|received|deposited|added to)\b');

/// Whichever comes first: ICICI's "Acct XX123 debited for Rs 450; SWIGGY credited" is a spend.
SmsDirection? _direction(String lower) {
  final d = _debit.firstMatch(lower)?.start, c = _credit.firstMatch(lower)?.start;
  if (d == null && c == null) return null;
  if (c == null || (d != null && d < c)) return SmsDirection.spent;
  return SmsDirection.received;
}

int _minor(String digits) {
  final [whole, ...fraction] = digits.replaceAll(',', '').split('.');
  final paise = fraction.isEmpty ? 0 : int.parse(fraction.first.padRight(2, '0').substring(0, 2));
  return int.parse(whole) * 100 + paise;
}

final _amounts = [
  _re('$_money$_number'),
  // SBI's "debited by 450.0", with no currency.
  _re('\\b(?:debited|credited)\\s+(?:by|for|with)\\s+(?:$_money)?$_number'),
];
final _isBalance = _re(r'\b(?:bal(?:ance)?|limit|lmt|avl)\b[^0-9]{0,15}$');

/// The first amount that isn't a balance or a limit.
int? _amount(String text) {
  final found = <(int, int)>[];
  for (final pattern in _amounts) {
    for (final m in pattern.allMatches(text)) {
      final before = text.substring(m.start < 25 ? 0 : m.start - 25, m.start);
      if (!_isBalance.hasMatch(before)) found.add((m.start, _minor(m.group(1)!)));
    }
  }
  if (found.isEmpty) return null;
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return found.first.$2 == 0 ? null : found.first.$2;
}

final _balanceAmount = _re('(?:avl\\.?\\s*bal(?:ance)?|available\\s+bal(?:ance)?|\\bbal(?:ance)?)\\s*(?:is|:|-|of)?\\s*(?:$_money)?$_number');

int? _balance(String text) {
  final m = _balanceAmount.firstMatch(text);
  return m == null ? null : _minor(m.group(1)!);
}

final _card = _re(
  r'\b(credit|debit)?\s*card(?:\s+(?:no\.?|number|account))?(?:\s+ending(?:\s+(?:with|in))?)?[\s:\-]*(?:[0-9]?[x*.]+)?\s*(\d{4})\b',
);
final _accountNumber = _re(r'\b(?:a/c|ac|acct|account)(?:\s*no\.?)?[\s:\-]*(?:[x*.]+)?\s*(\d{3,6})\b');
final _hasLimit = _re(r'\b(?:avl\.?\s*lmt|avl(?:ailable)?\.?\s*(?:credit\s*)?limit|credit limit)\b');

typedef _Account = ({String label, bool card, String digits});

/// The account or card the money moved through (the first one named), as a label. With
/// [cardOnly], the first card.
_Account? _account(String text, String lower, Bank? bank, String? header, {bool cardOnly = false}) {
  final card = _card.firstMatch(text), account = cardOnly ? null : _accountNumber.firstMatch(text);
  final name = bank?.name ?? 'Bank';
  if (card != null && (account == null || card.start < account.start)) {
    final kind = card.group(1)?.toLowerCase();
    final credit = kind == 'credit' || (kind == null && (_hasLimit.hasMatch(lower) || creditCardHeaders.contains(header)));
    final type = credit ? 'Credit card' : (kind == 'debit' ? 'Debit card' : 'Card');
    return (label: '$name $type ··${card.group(2)}', card: true, digits: card.group(2)!);
  }
  if (account != null) return (label: '$name ··${account.group(1)}', card: false, digits: account.group(1)!);
  return null;
}

/// The other account or card a message names besides [account] (the first other one), as its
/// digits: an own transfer's other half.
String? _counterpart(String text, _Account account) {
  final numbers = [
    for (final m in _card.allMatches(text)) (m.start, m.group(2)!),
    for (final m in _accountNumber.allMatches(text)) (m.start, m.group(1)!),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  for (final (_, digits) in numbers) {
    if (digits != account.digits) return digits;
  }
  return null;
}

String _channel(String lower, {required bool card, String? reference}) {
  if (_re(r'\batm\b|\bwithdrawn\b|\bcash withdrawal\b').hasMatch(lower)) return 'atm';
  if (_re(r'\bupi\b|\bvpa\b|[a-z0-9]@[a-z]{2,}').hasMatch(lower)) return 'upi';
  if (card) return 'card';
  if (_re(r'\b(?:neft|imps|rtgs|net ?banking|nach|ecs|transfer(?:red)?)\b').hasMatch(lower)) return 'bank';
  // A 12-digit reference with nothing else said is a UPI one (IMPS says IMPS): HDFC's
  // "Sent Rs.450 … To SWIGGY … Ref 627812345678".
  if (reference != null && RegExp(r'^\d{12}$').hasMatch(reference)) return 'upi';
  return 'other';
}

final _references = [
  _re(r'\bupi/p2[ma]/(\d{9,18})\b'),
  _re(
    r'\b(?:upi\s*ref(?:erence)?(?:\s*no\.?)?|ref(?:erence)?(?:\s*no\.?)?|refno|rrn|utr(?:\s*no\.?)?|imps(?:\s*ref(?:\s*no\.?)?)?|upi)\s*[:.\-#]?\s*(\d{9,18})\b',
  ),
  // An NEFT UTR: the bank's four letters, a letter, then digits (not an IFSC, whose fifth is 0).
  _re(r'\b([A-Z]{4}[A-Z]\d{10,})\b', caseSensitive: true),
];

String? _reference(String text) {
  for (final pattern in _references) {
    if (pattern.firstMatch(text) case final m?) return m.group(1);
  }
  return null;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};
final _dates = [
  (_re(r'\b(\d{4})-(\d{2})-(\d{2})\b'), (Match m) => (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!))),
  (_re(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b'), (Match m) => (_year(m[3]!), int.parse(m[2]!), int.parse(m[1]!))),
  (
    _re(r'\b(\d{1,2})[-\s]?(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[-\s,]*(\d{2,4})\b'),
    (Match m) => (_year(m[3]!), _months[m[2]!]!, int.parse(m[1]!)),
  ),
];

int _year(String y) => y.length == 2 ? 2000 + int.parse(y) : int.parse(y);

/// The first date the message gives, if it's a sensible one for when it arrived (a few days
/// before at most); else the day it arrived.
DateTime _date(String lower, DateTime received) {
  final arrived = DateTime(received.year, received.month, received.day);
  (int, DateTime)? first;
  for (final (pattern, parts) in _dates) {
    final m = pattern.firstMatch(lower);
    if (m == null || (first != null && first.$1 < m.start)) continue;
    final (y, mo, d) = parts(m);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) continue;
    first = (m.start, DateTime(y, mo, d));
  }
  final day = first?.$2;
  if (day == null || day.isAfter(arrived.add(const Duration(days: 1))) || day.isBefore(arrived.subtract(const Duration(days: 10)))) {
    return arrived;
  }
  return day;
}

/// Where a name ends: a word that starts the next part, or punctuation.
const _end = r'(?=\s+(?:on|ref|refno|via|using|thru|through|avl|available|upi|info|not|if|call|at|for|and|&)\b|\s*[(.;,]|\s+-|\s*$)';
const _name = r"([A-Za-z][A-Za-z0-9 .&'*\-/]{1,40}?)";
const _vpa = r'([a-z0-9][a-z0-9.\-_]*@[a-z][a-z0-9.]*[a-z])';

final _payees = [
  _re(r'\bupi/p2[ma]/\d+/([^/]+?)(?=/|\.|\s+not\b|$)'), // Axis: UPI/P2M/<ref>/RAPIDO
  _re(";\\s*$_name\\s+credited\\b"), // ICICI: …; SWIGGY credited
  // ICICI cards: … on 19-Oct-26. Info- ZOMATO LIMITE. (before "to": "SMS BLOCK 3232 to …")
  _re('\\binfo\\s*[:\\-]?\\s*(?!(?:upi|neft|imps|rtgs|nach|ach)\\b)$_name$_end'),
  _re('\\btrf to\\s+$_name$_end'), // SBI
  _re('\\btransferred to\\s+(?:(?:mr|mrs|ms|dr)\\.?\\s+)?$_name$_end'), // SBI
  _re('\\bto\\s+(?:vpa\\s+)?$_vpa'),
  _re('\\bto\\s+(?!(?:a/c|ac|acct|account|your|you)\\b)$_name$_end'), // HDFC: To SWIGGY On 12/10/26
  _re('\\bat\\s+(?!atm\\b)$_name$_end'), // cards: at AMAZON on …
  _re('\\btowards\\s+$_name$_end'),
  _re('\\bfor autopay of\\s+$_name$_end'),
  _re(r"\bon\s+(?!\d)([A-Z][A-Z0-9 .&'*\-]{1,40}?)\.(?:\s|$)", caseSensitive: true), // ICICI cards: on AMAZON.
];
final _payers = [
  _re('\\bvpa\\s+$_vpa'),
  _re("\\bneft\\s*cr-[a-z0-9]+-([a-z][a-z0-9 .&'\\-]{1,40}?)-"), // HDFC: NEFT Cr-<IFSC>-ACME CORP-…
  _re("\\binfo:?\\s*neft-[a-z0-9]+-([a-z][a-z0-9 .&'\\-]{1,40}?)$_end"), // ICICI: Info NEFT-<UTR>-ACME CORP
  _re('\\bby neft from\\s+$_name$_end'), // SBI
  _re('\\bfrom\\s+(?!(?:a/c|ac|acct|account|your|you|hdfc|icici|sbi)\\b)$_name$_end'),
];

/// Where a refund's payer ends: as [_end], or before what happened to the money ("from AMAZON
/// credited to …", "to ZOMATO has been reversed").
final _refundEnd = _end.replaceFirst(
  '(?:',
  '(?:credited|debited|reversed|refunded|has|have|is|was|to|as|towards|against|in|',
);

/// Who a refund came from: the payer patterns, then the payee ones (a reversal names who was
/// paid), ending names at [_refundEnd].
final _refunders = [
  for (final p in [..._payers, ..._payees])
    RegExp(p.pattern.replaceAll(_end, _refundEnd), caseSensitive: p.isCaseSensitive),
];
final _notAName = _re(r'^(?:[x*]+\d+|\d+|.*\b(?:a/c|acct|account)\b.*|atm.*)$');

/// Who was paid (a spend: [_payees]) or who paid (income: [_payers]; a refund: [_refunders]),
/// as the bank wrote it.
String? _merchant(String text, List<RegExp> patterns) {
  for (final pattern in patterns) {
    for (final m in pattern.allMatches(text)) {
      final name = m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').replaceFirst(RegExp(r'^vpa\s+', caseSensitive: false), '').trim();
      if (name.length >= 2 && !_notAName.hasMatch(name.toLowerCase())) return name;
    }
  }
  return null;
}
