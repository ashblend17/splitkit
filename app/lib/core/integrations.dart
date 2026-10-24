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
    this.notificationSplitAction = true,
    this.linkWindowDays = 3,
    this.groupShareInCashFlow = true,
    this.splitInNetWorth = true,
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

  /// A bank SMS notification for a spend has "Split", which opens Add split with it.
  final bool notificationSplitAction;

  final int linkWindowDays;

  /// Cash flow counts your share of group expenses as spending: it's what you used, so it comes
  /// off what's left over and the savings rate. Insights' spending cards (the trend, categories,
  /// daily average, needs and wants, savings rate) count it the same way (`group_share`). Only
  /// while [groupShareInPersonal] is on too; off, the share can still show next to your
  /// spending, but isn't part of it.
  final bool groupShareInCashFlow;

  /// Net worth adds what friends owe you in Split, net (or takes away what you owe them), as a
  /// line of its own next to your accounts.
  final bool splitInNetWorth;
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
    this.smsNotifications = true,
    this.justInBackfillDays = 2,
    this.countAtmAsSpending = true,
    this.importChunk = 50,
    this.accounts = true,
    this.transfers = true,
    this.refunds = true,
    this.investmentTypes = true,
    this.transferSuggestions = true,
    this.transferSuggestionMinutes = 30,
    this.atmToCash = true,
    this.pairCardBills = true,
    this.refundMatchDays = 60,
    this.goals = true,
    this.allocationRules = true,
    this.holdings = true,
    this.deadlineNearDays = 30,
    this.behindGraceDays = 7,
    this.staleValuationDays = 30,
  });

  /// How many unchecked bank SMS entries Overview's "Just in" shows at once.
  final int justInLimit;

  /// Personal entries and splits get a category from their words as you type (until you pick
  /// one), and entries read from bank SMS get one too (core/categorise).
  final bool suggestCategories;

  /// Suggestions start from what you chose before for the same merchant or words, before
  /// the built-in keywords.
  final bool learnCategories;

  /// Accounts show the latest balance their bank reported next to the one worked out from your
  /// entries, and offer Reconcile to set one to what the bank says.
  final bool accountBalances;

  /// Transactions filter by account and by payment mode, not just dates, type and category.
  final bool breakdownFilters;

  /// On Android, Personal can read bank SMS on the phone and add the payments it finds
  /// (features/sms). Off: no setup, no reading.
  final bool smsImport;

  /// A notification when a bank SMS arrives with the app closed (you can turn it off on the
  /// setup page).
  final bool smsNotifications;

  /// Of a first read going back months, only the last few days land in "Just in"; the rest
  /// arrive already looked at.
  final int justInBackfillDays;

  /// With no Cash account, a cash withdrawal counts as spending (else it's left out, as a move
  /// between your own money). With one, [atmToCash] decides.
  final bool countAtmAsSpending;

  /// Items per request when sending what a read of bank SMS found (POST /personal/batch, at most
  /// 100): accounts, entries and transfer halves (a transfer's two halves always go together).
  final int importChunk;

  /// Personal keeps your accounts (bank, cash, cards, loans, investments): each entry names the
  /// one it went through, each account has a balance, and net worth adds them up.
  final bool accounts;

  /// An entry can be a transfer between two of your accounts: money moves between them, and it's
  /// neither spending nor income.
  final bool transfers;

  /// An entry can be a refund of a spend: it comes off spending, in the spend's category.
  final bool refunds;

  /// The entry sheet offers Invested and Withdrew: money put into or taken out of investments,
  /// which cash flow shows apart from spending.
  final bool investmentTypes;

  /// A spend and an income read from bank SMS, of the same amount on two of your accounts and at
  /// most [transferSuggestionMinutes] apart, are offered as one transfer (until you say they
  /// aren't, on this device).
  final bool transferSuggestions;

  final int transferSuggestionMinutes;

  /// A cash withdrawal read from bank SMS becomes a transfer to your Cash account, when you have
  /// one.
  final bool atmToCash;

  /// A card bill paid from your bank account, read from bank SMS, becomes a transfer from the
  /// account to the card when both messages are found.
  final bool pairCardBills;

  /// A refund read from bank SMS is matched to a spend from the same merchant up to this many
  /// days before it.
  final int refundMatchDays;

  /// Personal has goals: what you're saving towards, with progress from contributions, an
  /// account's balance or a figure you type, what's needed each month and whether you're behind.
  final bool goals;

  /// Allocation rules: a share of each income planned for a goal or an account, with what's been
  /// set aside against what was planned.
  final bool allocationRules;

  /// Investment accounts keep their holdings (funds, shares, gold) with the value you last gave
  /// each, and net worth counts them.
  final bool holdings;

  /// A goal whose target date is at most this many days away is due soon.
  final int deadlineNearDays;

  /// A goal can be behind only once it's this many days old, so a new one isn't behind on its
  /// second day.
  final int behindGraceDays;

  /// A holding's value is out of date once it's this many days old.
  final int staleValuationDays;
}

final integrationsProvider = Provider<Integrations>((_) => const Integrations());
final featuresProvider = Provider<Features>((_) => const Features());
