import 'package:uuid/uuid.dart';

import '../sms/merchant_names.dart';

/// Categories learned from what you chose (api categories/rules.py). A rule says "this merchant
/// (or, without one, this description) goes under that category". The server writes one when
/// you pick a category yourself and syncs it on your user stream; the device lays the same rule
/// over its data straight away (core/local/writes.dart), so it counts before the server answers.

/// Lowercase, with spaces collapsed (rules.py pattern_of).
String rulePattern(String? text) => (text ?? '').toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');

/// The rule's id, the same as the server's (rules.py rule_id).
String ruleId(String userId, {required bool income, required String pattern}) =>
    const Uuid().v5(Namespace.url.value, 'splitkit:category-rule:$userId:${income ? 'income' : 'spend'}:$pattern');

/// What a merchant is called once a bank's spelling is set aside, for matching rules:
/// "ZOMATO LIMITED", "ZOMATO CYBS" and "zomato.payu@axisbank" are all "zomato", "AMAZON PAY IN
/// G" is "amazon pay", "Redbus India Pr" is "redbus".
String merchantKey(String? text) {
  final raw = (text ?? '').trim();
  if (raw.isEmpty) return '';
  final words = [
    for (final w in (merchantName(raw) ?? raw).toLowerCase().split(RegExp('[^a-z0-9]+')))
      if (w.isNotEmpty) w,
  ];
  // Banks cut names short ("JOHN DO"): a word of one or two letters after the first is
  // the cut-off end, or an initial.
  return [
    for (final (i, w) in words.indexed)
      if (i == 0 || w.length > 2) w,
  ].join(' ');
}
