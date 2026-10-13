import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one place to tune how the app's two halves, Split and Personal, behave.
///
/// [Integrations] are the links between them: each is one flag, so a link can be tuned or cut
/// without touching the screens, and with every flag off the two share nothing but your
/// account. [Features] tunes each half on its own.
///
/// The server never reads these: it stores and returns everything, and the app decides what
/// to show. Tests override the providers to check each flag.
class Integrations {
  const Integrations({
    this.groupShareInPersonal = true,
    this.splitFromTransaction = true,
    this.linkToExistingSplit = true,
    this.paymentFromTransaction = true,
    this.carryCategoryToSplit = true,
    this.personalNoteOnSplit = true,
    this.linkWindowDays = 3,
  });

  /// Personal shows your share of group expenses next to your own spending: a line on
  /// Overview and the "Personal vs group" card in Insights.
  final bool groupShareInPersonal;

  /// A spend in Personal offers "Split it": Add split opens with it filled in, and the split
  /// is linked to the entry (which then stops counting in Personal; your share counts).
  final bool splitFromTransaction;

  /// A spend offers "Already split" when a split you paid has the same amount and is dated
  /// within [linkWindowDays], so it's counted once.
  final bool linkToExistingSplit;

  /// A spend (or income) can be recorded as a settle-up payment to (or from) a friend you owe
  /// (or who owes you), linked to the entry.
  final bool paymentFromTransaction;

  /// "Split it" keeps the entry's category when groups have it too.
  final bool carryCategoryToSplit;

  /// A split made from your entry tells you, and only you, which account paid for it.
  final bool personalNoteOnSplit;

  final int linkWindowDays;
}

/// Each half on its own.
class Features {
  const Features({
    this.justInLimit = 5,
    this.suggestCategories = true,
    this.learnCategories = true,
    this.accountBalances = true,
    this.breakdownFilters = true,
    this.smsImport = true,
    this.justInBackfillDays = 2,
    this.countAtmAsSpending = true,
    this.importChunk = 50,
  });

  /// How many unchecked bank SMS entries Overview's "Just in" shows at once.
  final int justInLimit;

  /// Personal entries and splits get a category from their words as you type (until you pick
  /// one), and entries read from bank SMS get one too (core/categorise).
  final bool suggestCategories;

  /// Suggestions start from what you chose before for the same merchant or words, before
  /// the built-in keywords.
  final bool learnCategories;

  /// Overview lists your accounts with the latest balance their bank reported.
  final bool accountBalances;

  /// Transactions filter by account and by payment mode, not just dates, type and category.
  final bool breakdownFilters;

  /// On Android, Personal can read bank SMS on the phone and add the payments it finds
  /// (features/sms). Off: no setup, no reading.
  final bool smsImport;

  /// Of a first read going back months, only the last few days land in "Just in"; the rest
  /// arrive already looked at.
  final int justInBackfillDays;

  /// A cash withdrawal counts as spending (else it's left out, as a move between your own
  /// money).
  final bool countAtmAsSpending;

  /// Entries per request when sending what was read (POST /personal/transactions/batch).
  final int importChunk;
}

final integrationsProvider = Provider<Integrations>((_) => const Integrations());
final featuresProvider = Provider<Features>((_) => const Features());
