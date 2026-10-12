import 'sms.dart';

/// Brands named the way people write them, by the words banks use. Two-word ones first.
const _brands = {
  'amazon pay': 'Amazon Pay',
  'swiggy instamart': 'Swiggy Instamart',
  'blue tokai': 'Blue Tokai',
  'tata play': 'Tata Play',
  'amazon': 'Amazon',
  'swiggy': 'Swiggy',
  'zomato': 'Zomato',
  'flipkart': 'Flipkart',
  'myntra': 'Myntra',
  'bigbasket': 'BigBasket',
  'blinkit': 'Blinkit',
  'zepto': 'Zepto',
  'dmart': 'DMart',
  'uber': 'Uber',
  'rapido': 'Rapido',
  'irctc': 'IRCTC',
  'netflix': 'Netflix',
  'spotify': 'Spotify',
  'hotstar': 'Hotstar',
  'bookmyshow': 'BookMyShow',
  'starbucks': 'Starbucks',
  'airtel': 'Airtel',
  'jio': 'Jio',
  'jiomobility': 'Jio',
  'phonepe': 'PhonePe',
  'paytm': 'Paytm',
  'makemytrip': 'MakeMyTrip',
  'nykaa': 'Nykaa',
  'decathlon': 'Decathlon',
};

/// Words that say what a company is, not who.
final _legalWords = RegExp(
  r'\b(?:pvt|private|ltd|limited|llp|inc|india|technologies|technology|services|solutions|retail|online|payments?|stores?|com|in|payu|razorpay|cashfree|billdesk)\b\.?',
  caseSensitive: false,
);

/// A readable name for a merchant as a bank wrote it, or null when it says nothing:
/// "AMAZON PAY INDIA PRIVATE LIMITED" is Amazon Pay, "zomato.payu@axisbank" is Zomato,
/// "RAHUL SHARMA" is Rahul Sharma, and "9876543210@ybl" is nothing.
String? merchantName(String raw) {
  var name = raw.trim();
  final vpa = RegExp(r'^([a-z0-9.\-_]+)@[a-z0-9.]+$', caseSensitive: false).firstMatch(name);
  if (vpa != null) {
    name = vpa.group(1)!.split(RegExp(r'[.\-_0-9]+')).where((w) => w.length > 1).join(' ');
  }
  final lower = name.toLowerCase();
  for (final MapEntry(key: words, value: brand) in _brands.entries) {
    if (RegExp('\\b${RegExp.escape(words)}\\b').hasMatch(lower)) return brand;
  }
  final words = name.replaceAll(_legalWords, ' ').split(RegExp(r'[\s*/]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty || !words.any((w) => RegExp('[A-Za-z]{2}').hasMatch(w))) return null;
  // Short all-caps words are initials (PVR, KFC); the rest is shouted, so title-case it.
  return [
    for (final w in words)
      w.length <= 3 && w == w.toUpperCase() ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
  ].join(' ');
}

/// What an entry read from an SMS is called: who was paid, else what kind of payment it was.
String smsDescription(SmsTxn txn) {
  if (txn.merchant case final m? when merchantName(m) != null) return merchantName(m)!;
  if (txn.direction == SmsDirection.received) return 'Money received';
  return switch (txn.channel) {
    'atm' => 'Cash withdrawal',
    'upi' => 'UPI payment',
    'card' => 'Card payment',
    'bank' => 'Bank transfer',
    _ => 'Payment',
  };
}
