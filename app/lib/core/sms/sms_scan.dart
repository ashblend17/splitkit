/// One read of the bank SMS on this phone, decided without the app: for each message, whether
/// it's a new entry, an entry you'd made by hand, a payment already here, or skipped. Pure:
/// everything in and out can go to another isolate, so a big first read runs off the UI
/// (features/sms/sms_importer.dart takes the input from the device's data and queues the output).
///
/// The input and output are records of plain data, so later reads (accounts by label, refunds,
/// transfers) add fields here, not another pass.
library;

import '../api/api.dart';
import '../categorise/category_guesser.dart' show keywordCategory;
import '../categorise/category_rules.dart';
import '../integrations.dart';
import '../local/ledger.dart';
import '../local/personal_index.dart' show localDay;
import 'merchant_names.dart';
import 'sms.dart';
import 'sms_ids.dart';
import 'sms_parser.dart';

/// A message from a bank sender that wasn't added, and why (shown on "Messages we skipped").
/// OTPs are never kept.
typedef SkippedSms = ({RawSms sms, SmsSkip reason});

/// An entry you'd made by hand that a message was about: its id, what the message adds, and
/// the message's own id (so a later read knows it).
typedef SmsAttachment = ({String entryId, String? merchant, String? account, String channel, String smsId});

/// What a read needs from the device, taken once.
class SmsScanInput {
  const SmsScanInput({
    required this.messages,
    required this.userId,
    required this.knownIds,
    required this.references,
    required this.attachedBefore,
    required this.manual,
    required this.categories,
    required this.features,
    required this.now,
    this.testSenders = const {},
  });

  /// Oldest first, as the inbox gives them.
  final List<RawSms> messages;
  final String userId;

  /// The id of every personal entry here, deleted ones too (Ledger.personalIds).
  final Set<String> knownIds;

  /// "reference|type" of every entry with a bank reference, deleted ones too
  /// (Ledger.personalReferences).
  final Set<String> references;

  /// Ids of messages that were about an entry made by hand, in an earlier read.
  final Set<String> attachedBefore;

  /// Entries made by hand with no account yet: by type and amount, (id, dayKey) in the API's
  /// order (Ledger.manualCandidates).
  final Map<(String, int), List<(String, int)>> manual;

  /// Personal's learned categories (Ledger.learnedCategories), or null when suggestions are off.
  final LearnedCategories? categories;
  final Features features;

  /// For what's "just in".
  final DateTime now;

  /// Senders read as banks when testing on an emulator.
  final Set<String> testSenders;
}

/// What a read found.
class SmsScanResult {
  const SmsScanResult({
    required this.created,
    required this.attached,
    required this.skipped,
    required this.bodies,
    required this.known,
    required this.last,
  });

  /// New entries, with the id each message gives its entry.
  final List<(String, PersonalTxnIn)> created;
  final List<SmsAttachment> attached;
  final List<SkippedSms> skipped;

  /// The message each new entry came from, by entry id (kept on this phone only).
  final Map<String, Map<String, Object?>> bodies;

  /// Payments already here: from an earlier read, or another message about the same one.
  final int known;

  /// When the newest message arrived (where the next read starts), or null with none.
  final DateTime? last;
}

/// Reads [input]'s messages in order.
SmsScanResult scanSms(SmsScanInput input) {
  final f = input.features;
  final references = {...input.references};
  final ids = <String>{};
  final created = <(String, PersonalTxnIn)>[];
  final attached = <SmsAttachment>[];
  final skipped = <SkippedSms>[];
  final bodies = <String, Map<String, Object?>>{};
  var known = 0;

  for (final sms in input.messages) {
    final SmsTxn txn;
    switch (parseSms(sms, testSenders: input.testSenders)) {
      case SmsSkipped(:final reason):
        // Not kept: codes, and anything not from a bank.
        if (reason != SmsSkip.otp && reason != SmsSkip.notABank) skipped.add((sms: sms, reason: reason));
        continue;
      case SmsParsed(txn: final parsed):
        txn = parsed;
    }
    final id = smsEntryId(input.userId, sms, txn);
    final type = txn.direction == SmsDirection.spent ? 'expense' : 'income';
    final ref = txn.reference == null ? null : '${txn.reference}|$type';
    // Already here: read before (even if deleted since), or another message about it.
    if (!ids.add(id) ||
        input.knownIds.contains(id) ||
        input.attachedBefore.contains(id) ||
        (ref != null && references.contains(ref))) {
      known++;
      continue;
    }
    if (ref != null) references.add(ref);
    if (txn.channel == 'atm' && !f.countAtmAsSpending) continue;
    // Entered by hand already: give that entry the bank's details instead.
    if (_manualMatch(input.manual, type, txn.amountMinor, txn.date) case final entryId?) {
      if (!attached.any((a) => a.entryId == entryId)) {
        attached.add((entryId: entryId, merchant: txn.merchant, account: txn.account, channel: txn.channel, smsId: id));
        continue;
      }
    }
    final description = smsDescription(txn);
    final income = type == 'income';
    final justIn = sms.receivedAt.isAfter(input.now.subtract(Duration(days: f.justInBackfillDays)));
    final categories = input.categories;
    created.add((
      id,
      PersonalTxnIn(
        type: PersonalTxnInTypeEnum.fromJson(type)!,
        amountMinor: txn.amountMinor,
        description: description,
        date: apiDate(txn.date),
        categoryId: f.suggestCategories && categories != null
            ? personalCategory(
                categories,
                description,
                merchant: txn.merchant,
                income: income,
                learn: f.learnCategories,
              )
            : null,
        channel: PersonalTxnInChannelEnum.fromJson(txn.channel),
        merchant: txn.merchant,
        account: txn.account,
        reference: txn.reference,
        balanceMinor: txn.balanceMinor,
        smsAt: sms.receivedAt.toUtc(),
        source_: PersonalTxnInSource_Enum.sms,
        // A first read going back months: only the last few days are "just in".
        reviewed: !justIn,
      ),
    ));
    bodies[id] = sms.toJson();
  }
  return SmsScanResult(
    created: created,
    attached: attached,
    skipped: skipped,
    bodies: bodies,
    known: known,
    last: input.messages.isEmpty ? null : input.messages.last.receivedAt,
  );
}

/// Ledger.manualMatch over [manual]: the newest entry made by hand (no account yet) of [type]
/// and [amount] dated within a day of [day].
String? _manualMatch(Map<(String, int), List<(String, int)>> manual, String type, int amount, DateTime day) {
  final target = DateTime(day.year, day.month, day.day);
  for (final (id, entryDay) in manual[(type, amount)] ?? const <(String, int)>[]) {
    if (localDay(entryDay).difference(target).inDays.abs() <= 1) return id;
  }
  return null;
}

/// categoryFor (core/categorise/category_guesser.dart) for an entry read from a bank SMS, in
/// Personal, over [categories]: what you chose before for the merchant or words, else the
/// keywords' category (exact words only: banks name merchants exactly).
String? personalCategory(
  LearnedCategories categories,
  String text, {
  String? merchant,
  bool income = false,
  bool learn = true,
}) {
  if (learn) {
    final keys = {merchantKey(merchant), merchantKey(text)}..remove('');
    if (categories.lookup(keys, income: income) case final id?) return id;
  }
  var key = keywordCategory('${merchant ?? ''} $text', fuzzy: false);
  if (income != (key == 'income')) key = income ? 'income' : null;
  if (key == 'travel') key = 'transport'; // Personal has no Travel
  return key == null ? null : categories.offeredByKey[key];
}
