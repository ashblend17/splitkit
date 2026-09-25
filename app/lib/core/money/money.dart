/// Money display, mirroring api/app/core/money.py exactly (same inputs, same strings).
/// Amounts are always integer minor units (paise) plus a currency code.
library;

const _currencies = <String, (int, String)>{'INR': (2, '₹'), 'USD': (2, r'$'), 'EUR': (2, '€')};

/// Currencies the API accepts, with names for pickers.
const supportedCurrencies = <String, String>{'INR': 'Indian rupee', 'USD': 'US dollar', 'EUR': 'Euro'};

const minus = '−'; // typographic minus, as in "−₹850"

(int, String) _currency(String code) {
  final c = _currencies[code];
  if (c == null) throw ArgumentError('Unsupported currency: $code');
  return c;
}

String currencySymbol(String code) => _currency(code).$2;

int minorUnitsPerMajor(String code) {
  var factor = 1;
  for (var i = 0; i < _currency(code).$1; i++) {
    factor *= 10;
  }
  return factor;
}

/// 1234567 -> "12,34,567" (lakh/crore grouping).
String groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  var head = digits.substring(0, digits.length - 3);
  final tail = digits.substring(digits.length - 3);
  final pairs = <String>[];
  while (head.length > 2) {
    pairs.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  return [head, ...pairs, tail].join(',');
}

/// 1234567 -> "1,234,567".
String groupThousands(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// 155000 -> "₹1,550", 153333 -> "₹1,533.33", -85000 -> "−₹850".
/// Whole amounts drop the decimals; anything else always shows two places. INR uses lakh
/// grouping (₹1,50,000); other currencies group in thousands ($150,000).
String formatMinor(int amountMinor, {String currency = 'INR', bool signed = false}) {
  final (exponent, symbol) = _currency(currency);
  final unit = minorUnitsPerMajor(currency);
  final abs = amountMinor.abs();
  final major = abs ~/ unit;
  final minor = abs % unit;
  var text = currency == 'INR' ? groupIndian('$major') : groupThousands('$major');
  if (minor != 0) text += '.${'$minor'.padLeft(exponent, '0')}';
  final sign = amountMinor < 0 ? minus : (signed && amountMinor > 0 ? '+' : '');
  return '$sign$symbol$text';
}

/// "600.5" -> 60050. Accepts grouping commas and a leading symbol. Returns null if the text
/// is not an amount or has more decimals than the currency allows.
int? parseMinor(String text, {String currency = 'INR'}) {
  final (exponent, symbol) = _currency(currency);
  var cleaned = text.trim().replaceAll(',', '');
  if (cleaned.startsWith(symbol)) cleaned = cleaned.substring(symbol.length);
  final match = RegExp(r'^(\d+)(?:\.(\d*))?$').firstMatch(cleaned);
  if (match == null) return null;
  final fraction = match.group(2) ?? '';
  if (fraction.length > exponent) return null;
  final minor = fraction.padRight(exponent, '0');
  return int.parse(match.group(1)!) * minorUnitsPerMajor(currency) + (minor.isEmpty ? 0 : int.parse(minor));
}
