import 'package:fuzzywuzzy/fuzzywuzzy.dart' show ratio;

import '../local/ledger.dart';
import 'category_keywords.dart';

/// How close (fuzzywuzzy's ratio, 0–100) a word must be to a keyword to count as a typo of it:
/// "grocries" is 94 from "groceries", "zomatoo" 92 from "zomato".
///
/// One letter off in a 4-letter word scores 75 whether it's a typo ("ubar" for "uber") or
/// another word ("rice" for "ride", "cart" for "mart"), so short typos aren't caught: they'd
/// put rice under Transport. Words of 3 letters or fewer only match exactly ("bar" isn't "car"),
/// and a typo is at most a letter longer or shorter than the word it's of ("rest" scores 80
/// against "resort").
const fuzzyThreshold = 80;

/// Ordinary words that score [fuzzyThreshold] against a keyword: never read as a typo of it.
const _notTypos = {'price', 'later', 'pride'};

final _categoryOf = {
  for (final MapEntry(:key, :value) in categoryKeywords.entries)
    for (final word in value) word: key,
};

final _fuzzyKeywords = [
  for (final word in _categoryOf.keys)
    if (!word.contains(' ') && word.length >= 4) word,
];

/// Lowercase words, without punctuation: "Uber*Trip, BLR" is uber, trip, blr.
List<String> wordsOf(String text) => [
  for (final w in text.toLowerCase().split(RegExp('[^a-z0-9]+')))
    if (w.isNotEmpty) w,
];

/// The category key [text]'s words suggest, or null. An exact keyword first, in the order the
/// words come (two-word keywords too), then with [fuzzy] the closest keyword a word could be a
/// typo of. Bank SMS name merchants exactly, so the importer leaves [fuzzy] off.
String? keywordCategory(String text, {bool fuzzy = true}) {
  final words = wordsOf(text);
  for (var i = 0; i < words.length; i++) {
    if (i + 1 < words.length) {
      if (_categoryOf['${words[i]} ${words[i + 1]}'] case final key?) return key;
    }
    if (_categoryOf[words[i]] case final key?) return key;
  }
  if (!fuzzy) return null;
  String? best;
  var bestScore = fuzzyThreshold - 1;
  for (final w in words) {
    if (w.length < 4 || _notTypos.contains(w)) continue;
    for (final keyword in _fuzzyKeywords) {
      if ((w.length - keyword.length).abs() > 1) continue;
      final score = ratio(w, keyword);
      if (score > bestScore) {
        bestScore = score;
        best = _categoryOf[keyword];
      }
    }
  }
  return best;
}

/// A category id for a personal entry ([scope] "personal") or a split ("group"), from its
/// [text] and, for entries read from a bank SMS, its [merchant]. Null when nothing fits.
///
/// With [learn], what you chose before for the same merchant or words comes first (your own
/// categories too). Then the keywords' category, if it's offered in [scope]: Personal has no
/// Travel, so flights count as Transport there. Income only ever gets an income category.
String? categoryFor(
  Ledger ledger,
  String text, {
  required String scope,
  String? merchant,
  bool income = false,
  bool learn = true,
  bool fuzzy = true,
}) {
  if (learn) {
    final learned = ledger.learnedCategory(text, merchant: merchant, scope: scope, income: income);
    if (learned != null) return learned;
  }
  var key = keywordCategory('${merchant ?? ''} $text', fuzzy: fuzzy);
  if (income != (key == 'income')) key = income ? 'income' : null;
  if (scope == 'personal' && key == 'travel') key = 'transport';
  if (key == null) return null;
  final offered = ledger.categories(scope: scope);
  // Built-in first: your own category could have the same key.
  return (offered.where((c) => c['key'] == key && c['owner_id'] == null).firstOrNull ??
          offered.where((c) => c['key'] == key).firstOrNull)?['id']
      as String?;
}
