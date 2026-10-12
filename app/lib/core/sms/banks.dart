/// Indian business SMS headers: an optional two-letter operator and circle prefix, the header
/// itself, and since 2024 a category suffix (-S service, -T transactional, -P promotional,
/// -G government). Phone numbers aren't headers, so messages from people never match.
final senderHeader = RegExp(r'^(?:[A-Z]{2}-)?([A-Z0-9]{3,11})(?:-([PSTG]))?$');

/// [senderHeader] for the phone's SMS reader (Android matches senders with it before handing
/// messages over, so messages from people never reach the app).
const senderPattern = r'^(?:[A-Za-z]{2}-)?[A-Za-z0-9]{3,11}(?:-[PSTGpstg])?$';

/// A bank: its name in labels ("HDFC ··4821"), the headers it sends from, and how its
/// messages name it.
class Bank {
  const Bank(this.name, this.headers, this.mentions);
  final String name;
  final List<String> headers;
  final List<String> mentions;
}

/// Tuned for HDFC, ICICI and SBI; the others are read with the same grammar.
const banks = [
  Bank('HDFC', ['HDFCBK', 'HDFCBN', 'HDFCCC', 'HDFCBANK'], ['hdfc']),
  Bank('ICICI', ['ICICIB', 'ICICIT', 'ICICIO', 'ICICIBANK'], ['icici']),
  Bank('SBI', ['SBIINB', 'SBIUPI', 'SBIPSG', 'CBSSBI', 'ATMSBI', 'SBICRD', 'SBIBNK', 'SBMSMS', 'SBICARD'], [
    'sbi',
    'state bank',
  ]),
  Bank('Axis', ['AXISBK', 'AXISBN'], ['axis bank']),
  Bank('Kotak', ['KOTAKB', 'KOTAKM'], ['kotak']),
  Bank('Yes', ['YESBNK'], ['yes bank']),
  Bank('IDFC First', ['IDFCFB'], ['idfc']),
  Bank('IndusInd', ['INDUSB'], ['indusind']),
  Bank('PNB', ['PNBSMS'], ['punjab national', 'pnb']),
  Bank('BoB', ['BOBTXN', 'BOBSMS'], ['bank of baroda']),
  Bank('Canara', ['CANBNK'], ['canara']),
  Bank('Union', ['UNIONB'], ['union bank']),
  Bank('Federal', ['FEDBNK'], ['federal bank']),
  Bank('RBL', ['RBLBNK'], ['rbl bank']),
  Bank('AU', ['AUBANK'], ['au small finance', 'au bank']),
  Bank('Paytm', ['PAYTMB'], ['paytm payments bank']),
  Bank('Airtel', ['AIRBNK'], ['airtel payments bank']),
];

/// Cards that are always credit cards (their issuers send only those).
const creditCardHeaders = {'SBICRD', 'SBICARD', 'HDFCCC'};

/// The bank behind a message: by its header, else by how the message names it.
Bank? bankFor(String? header, String lowerBody) {
  for (final b in banks) {
    if (header != null && b.headers.contains(header)) return b;
  }
  for (final b in banks) {
    if (b.mentions.any((m) => RegExp('\\b${RegExp.escape(m)}\\b').hasMatch(lowerBody))) return b;
  }
  return null;
}
