import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/integrations.dart';
import '../../core/local/ledger.dart';
import '../../core/local/providers.dart';
import '../../core/local/store.dart';
import '../../core/local/writes.dart';
import '../../core/session/session.dart';
import '../../core/sms/banks.dart';
import '../../core/sms/sms.dart';
import '../../core/sms/sms_ids.dart';
import '../../core/sms/sms_parser.dart';
import '../../core/sms/sms_scan.dart';
import 'sms_source.dart';

export '../../core/sms/sms_scan.dart' show SkippedSms;

/// This phone's bank SMS settings for the signed-in user (in the device store, so another
/// phone or the web never reads anything).
class SmsSettings {
  const SmsSettings({required this.since, this.notify = true});

  /// Messages from this day on are read: the range picked when it was turned on.
  final DateTime since;

  /// A notification when a bank SMS arrives with the app closed (features/sms/notifications).
  final bool notify;

  Map<String, Object?> toJson() => {'since': since.toIso8601String(), 'notify': notify};

  static SmsSettings fromJson(Map<Object?, Object?> j) =>
      SmsSettings(since: DateTime.parse(j['since']! as String), notify: j['notify'] as bool? ?? true);
}

/// What one read of the inbox did.
class SmsScan {
  const SmsScan({this.added = 0, this.attached = 0, this.skipped = 0, this.known = 0});
  static const none = SmsScan();

  /// New entries.
  final int added;

  /// Entries you'd made by hand that a message was about: they got its account and merchant.
  final int attached;

  /// Bank messages that weren't payments (or that the app couldn't read).
  final int skipped;

  /// Payments already here, from an earlier read or another message about the same one.
  final int known;
}

/// Device-store keys.
abstract final class SmsKeys {
  static const settings = 'sms.settings';
  static const cursor = 'sms.cursor';
  static const skipped = 'sms.skipped';
  static const promptDismissed = 'sms.prompt_dismissed';

  /// Ids of messages that were about an entry made by hand (which got their details), so a
  /// later read doesn't add them again.
  static const attached = 'sms.attached';
  static String body(String entryId) => 'sms.body.$entryId';
}

/// Reads the bank SMS on this phone into Personal: each payment once (its id comes from the
/// message), categorised as you would, with the account, mode, merchant, reference and
/// balance the bank gave. Only the parsed fields are uploaded; the message itself stays here.
///
/// Reads nothing when it's off, in view-as (it would be someone else's account), before the
/// first sync (what's already here must be known), or when your currency isn't rupees.
class SmsImporter {
  SmsImporter(this._ref);
  final Ref _ref;
  Future<SmsScan>? _running;

  static const _page = 500;
  static const _keepSkipped = 100;

  /// The sender pattern the phone filters by: bank headers, plus the emulator's test sender.
  static String get senderPatternWithTests =>
      AppConfig.smsTestSender.isEmpty ? senderPattern : '(?:$senderPattern)|^\\+?${RegExp.escape(AppConfig.smsTestSender)}\$';

  static Set<String> get _testSenders => {if (AppConfig.smsTestSender.isNotEmpty) AppConfig.smsTestSender};

  Future<LocalStore> get _store => _ref.read(localStoreProvider.future);

  Future<SmsSettings?> settings() async {
    final j = await (await _store).deviceValue(SmsKeys.settings);
    return j is Map ? SmsSettings.fromJson(j) : null;
  }

  /// Turns reading on from [since] (and reads), or off with null. Turning off keeps the
  /// entries already added.
  Future<SmsScan> setUp(DateTime? since, {bool notify = true}) async {
    final store = await _store;
    if (since == null) {
      await store.setDeviceValues({SmsKeys.settings: null, SmsKeys.cursor: null});
      await configureNotifications();
      return SmsScan.none;
    }
    await store.setDeviceValues({SmsKeys.settings: SmsSettings(since: since, notify: notify).toJson(), SmsKeys.cursor: null});
    await configureNotifications();
    return scan();
  }

  /// Notifications on or off (while reading is on).
  Future<void> setNotify(bool notify) async {
    final settings = await this.settings();
    if (settings == null) return;
    await (await _store).setDeviceValue(SmsKeys.settings, SmsSettings(since: settings.since, notify: notify).toJson());
    await configureNotifications();
  }

  /// Tells the phone whether to notify (reading and notifications on, signed in as yourself),
  /// whether to offer Split, and which senders are banks. [off] after signing out.
  Future<void> configureNotifications({bool off = false}) async {
    final source = _ref.read(smsSourceProvider);
    if (!source.available) return;
    final session = _ref.read(sessionProvider).value;
    final settings = off || session == null || session.isViewAs ? null : await this.settings();
    final links = _ref.read(integrationsProvider);
    await source.configure(
      notify: settings != null && settings.notify && _ref.read(featuresProvider).smsNotifications,
      split: links.notificationSplitAction && links.splitFromTransaction,
      senderPattern: senderPatternWithTests,
    );
  }

  /// A tapped notification's message: reads the inbox (where it is by now) and returns the
  /// entry it became, or null if it's not one (an entry you'd made, when it was matched, is).
  Future<String?> importOne(RawSms sms) async {
    await scan();
    final verdict = parseSms(sms, testSenders: _testSenders);
    if (verdict is! SmsParsed) return null;
    final ledger = (await _store).ledger;
    if (ledger.isEmpty) return null;
    final txn = verdict.txn;
    final id = smsEntryId(ledger.me, sms, txn);
    if (ledger.rawPersonal(id) != null) return id;
    final type = txn.direction == SmsDirection.spent ? 'expense' : 'income';
    // Known by its reference (another message about it), or matched to an entry made by hand.
    if (txn.reference case final reference?) {
      if (ledger.personalWithReference(reference, type) case final known?) return known;
    }
    return ledger.personalPaid(type: type, amount: txn.amountMinor, account: txn.account, merchant: txn.merchant);
  }

  /// Reads what arrived since the last read (a few days before, in case a message was stored
  /// late), or with [fromStart] everything since reading was turned on. One read at a time.
  Future<SmsScan> scan({bool fromStart = false}) => _running ??= _scan(fromStart).whenComplete(() => _running = null);

  Future<SmsScan> _scan(bool fromStart) async {
    final features = _ref.read(featuresProvider);
    final source = _ref.read(smsSourceProvider);
    final session = _ref.read(sessionProvider).value;
    if (!features.smsImport || !source.available || session == null || session.isViewAs || session.readOnly) {
      return SmsScan.none;
    }
    final store = await _store;
    final settings = await this.settings();
    await configureNotifications();
    if (settings == null || !await source.hasAccess()) return SmsScan.none;
    await _ref.read(ledgerProvider.future); // the first sync, if this device hasn't had one
    final ledger = store.ledger;
    if (ledger.isEmpty || ledger.userOut()['currency'] != 'INR') return SmsScan.none;

    final cursor = fromStart ? null : await store.deviceValue(SmsKeys.cursor) as String?;
    var since = cursor == null ? settings.since : DateTime.parse(cursor).subtract(const Duration(days: 3));
    if (since.isBefore(settings.since)) since = settings.since;

    final attachedBefore = ((await store.deviceValue(SmsKeys.attached)) as List?)?.cast<String>() ?? const <String>[];
    final messages = <RawSms>[];
    while (true) {
      final page = await source.inbox(since: since, senderPattern: senderPatternWithTests, limit: _page);
      messages.addAll(page);
      if (page.length < _page) break;
      since = page.last.receivedAt; // inclusive: the overlap is known by its ids
    }
    final read = await runSmsScan(smsScanInput(ledger, messages, features, attachedBefore: attachedBefore.toSet()));

    // Everything read is queued together: one rebuild however many entries.
    await _ref.read(writesProvider).importSms(read.created, [
      for (final a in read.attached)
        (
          a.entryId,
          personalBody(PersonalTxnOut.fromJson(ledger.personalTransaction(a.entryId))!)
            ..merchant = a.merchant
            ..account = a.account
            ..channel ??= PersonalTxnInChannelEnum.fromJson(a.channel),
        ),
    ], chunk: features.importChunk);
    final kept = ((await store.deviceValue(SmsKeys.skipped)) as List?)?.cast<Map<Object?, Object?>>() ?? const [];
    final skipped = [
      for (final s in read.skipped) {...s.sms.toJson(), 'reason': s.reason.name},
      ...kept,
    ];
    final seen = <String>{};
    final last = read.last;
    await store.setDeviceValues({
      for (final MapEntry(:key, :value) in read.bodies.entries) SmsKeys.body(key): value,
      SmsKeys.skipped: [
        for (final s in skipped)
          if (seen.add('${s['address']}|${s['body']}')) s,
      ].take(_keepSkipped).toList(),
      if (last != null) SmsKeys.cursor: last.toIso8601String(),
      if (read.attached.isNotEmpty) SmsKeys.attached: [...attachedBefore, for (final a in read.attached) a.smsId],
    });
    return SmsScan(added: read.created.length, attached: read.attached.length, skipped: read.skipped.length, known: read.known);
  }

  /// What was skipped, newest first.
  Future<List<SkippedSms>> skipped() async {
    final kept = ((await (await _store).deviceValue(SmsKeys.skipped)) as List?) ?? const [];
    return [
      for (final j in kept.cast<Map<Object?, Object?>>())
        (sms: RawSms.fromJson(j.cast()), reason: SmsSkip.values.byName(j['reason']! as String)),
    ];
  }

  /// The message an entry was read from, if this phone read it.
  Future<RawSms?> messageFor(String entryId) async {
    final j = await (await _store).deviceValue(SmsKeys.body(entryId));
    return j is Map ? RawSms.fromJson(j.cast()) : null;
  }
}

/// What a read of [messages] needs from [ledger] (core/sms/sms_scan.dart), taken now.
SmsScanInput smsScanInput(
  Ledger ledger,
  List<RawSms> messages,
  Features features, {
  Set<String> attachedBefore = const {},
}) => SmsScanInput(
  messages: messages,
  userId: ledger.me,
  knownIds: ledger.personalIds(),
  references: ledger.personalReferences(),
  attachedBefore: attachedBefore,
  manual: ledger.manualCandidates(),
  categories: features.suggestCategories ? ledger.learnedCategories('personal') : null,
  features: features,
  now: appClock.now(),
  testSenders: SmsImporter._testSenders,
);

/// Messages up to which a read runs on the UI isolate; more go to another isolate, so a first
/// read of months of SMS doesn't freeze the screen. The web has no isolates (nor SMS).
const smsScanInlineUpTo = 40;

/// Runs [scanSms] on [input], on another isolate when there are many messages.
Future<SmsScanResult> runSmsScan(SmsScanInput input) async =>
    kIsWeb || input.messages.length <= smsScanInlineUpTo ? scanSms(input) : await Isolate.run(() => scanSms(input));

final smsImporterProvider = Provider<SmsImporter>((ref) {
  final importer = SmsImporter(ref);
  // Signed out: the phone stops notifying (it would open an app with no one in it).
  ref.listen(sessionProvider, (previous, next) {
    if (previous?.value != null && next.hasValue && next.value == null) {
      importer.configureNotifications(off: true).ignore();
    }
  });
  return importer;
});
