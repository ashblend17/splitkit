import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one place to tune how the app's two halves, Split and Personal, behave.
///
/// [Integrations] are the links between them: each is one flag, so a link can be tuned or cut
/// without touching the screens, and with every flag off the two share nothing but your
/// account. [PersonalFeatures] tunes Personal on its own.
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

/// Personal on its own.
class PersonalFeatures {
  const PersonalFeatures({this.justInLimit = 5});

  /// How many unchecked bank SMS entries Overview's "Just in" shows at once.
  final int justInLimit;
}

final integrationsProvider = Provider<Integrations>((_) => const Integrations());
final personalFeaturesProvider = Provider<PersonalFeatures>((_) => const PersonalFeatures());
