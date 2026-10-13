import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/categorise/category_guesser.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/integrations.dart';
import '../../core/local/ledger.dart';
import '../../core/local/providers.dart';
import '../../core/local/store.dart';
import '../../core/local/writes.dart';
import '../../core/session/session.dart';
import '../../core/sms/banks.dart';
import '../../core/sms/merchant_names.dart';
import '../../core/sms/sms.dart';
import '../../core/sms/sms_ids.dart';
import '../../core/sms/sms_parser.dart';
import 'sms_source.dart';

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

/// A message from a bank sender that wasn't added, and why (shown on "Messages we skipped").
/// OTPs are never kept.
typedef SkippedSms = ({RawSms sms, SmsSkip reason});

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
      return SmsScan.none;
    }
    await store.setDeviceValues({SmsKeys.settings: SmsSettings(since: since, notify: notify).toJson(), SmsKeys.cursor: null});
    return scan();
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
    if (settings == null || !await source.hasAccess()) return SmsScan.none;
    await _ref.read(ledgerProvider.future); // the first sync, if this device hasn't had one
    final ledger = store.ledger;
    if (ledger.isEmpty || ledger.userOut()['currency'] != 'INR') return SmsScan.none;

    final cursor = fromStart ? null : await store.deviceValue(SmsKeys.cursor) as String?;
    var since = cursor == null ? settings.since : DateTime.parse(cursor).subtract(const Duration(days: 3));
    if (since.isBefore(settings.since)) since = settings.since;

    final attachedBefore = ((await store.deviceValue(SmsKeys.attached)) as List?)?.cast<String>() ?? const <String>[];
    final read = _Read(ledger, features, attachedBefore.toSet());
    DateTime? last;
    while (true) {
      final page = await source.inbox(since: since, senderPattern: senderPatternWithTests, limit: _page);
      page.forEach(read.add);
      if (page.isNotEmpty) last = page.last.receivedAt;
      if (page.length < _page) break;
      since = page.last.receivedAt; // inclusive: the overlap is known by its ids
    }

    final writes = _ref.read(writesProvider);
    await writes.importPersonal(read.created, chunk: features.importChunk);
    for (final (txn, sms, _) in read.attached) {
      await writes.updatePersonal(
        txn.id,
        personalBody(txn)
          ..merchant = sms.merchant
          ..account = sms.account
          ..channel ??= PersonalTxnInChannelEnum.fromJson(sms.channel),
      );
    }
    final kept = ((await store.deviceValue(SmsKeys.skipped)) as List?)?.cast<Map<Object?, Object?>>() ?? const [];
    final skipped = [
      for (final s in read.skipped) {...s.sms.toJson(), 'reason': s.reason.name},
      ...kept,
    ];
    final seen = <String>{};
    await store.setDeviceValues({
      ...read.bodies,
      SmsKeys.skipped: [
        for (final s in skipped)
          if (seen.add('${s['address']}|${s['body']}')) s,
      ].take(_keepSkipped).toList(),
      if (last != null) SmsKeys.cursor: last.toIso8601String(),
      if (read.attached.isNotEmpty) SmsKeys.attached: [...attachedBefore, for (final a in read.attached) a.$3],
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

/// One read's decisions, message by message.
class _Read {
  _Read(this.ledger, this.features, this._attachedBefore) : _references = ledger.personalReferences();

  final Ledger ledger;
  final Features features;
  final Set<String> _attachedBefore;
  final Set<String> _references;
  final _ids = <String>{};

  final created = <(String, PersonalTxnIn)>[];

  /// The entry, what the message said, and the message's id.
  final attached = <(PersonalTxnOut, SmsTxn, String)>[];
  final skipped = <SkippedSms>[];
  final bodies = <String, Object?>{};
  var known = 0;

  void add(RawSms sms) {
    switch (parseSms(sms, testSenders: SmsImporter._testSenders)) {
      case SmsSkipped(:final reason):
        // Not kept: codes, and anything not from a bank.
        if (reason != SmsSkip.otp && reason != SmsSkip.notABank) skipped.add((sms: sms, reason: reason));
      case SmsParsed(:final txn):
        _payment(sms, txn);
    }
  }

  void _payment(RawSms sms, SmsTxn txn) {
    final id = smsEntryId(ledger.me, sms, txn);
    final type = txn.direction == SmsDirection.spent ? 'expense' : 'income';
    final ref = txn.reference == null ? null : '${txn.reference}|$type';
    // Already here: read before (even if deleted since), or another message about it.
    if (!_ids.add(id) ||
        ledger.rawPersonal(id) != null ||
        _attachedBefore.contains(id) ||
        (ref != null && _references.contains(ref))) {
      known++;
      return;
    }
    if (ref != null) _references.add(ref);
    if (txn.channel == 'atm' && !features.countAtmAsSpending) return;
    // Entered by hand already: give that entry the bank's details instead.
    if (ledger.manualMatch(type, txn.amountMinor, txn.date) case final manual?) {
      final out = PersonalTxnOut.fromJson(manual)!;
      if (!attached.any((a) => a.$1.id == out.id)) {
        attached.add((out, txn, id));
        return;
      }
    }
    final description = smsDescription(txn);
    final income = type == 'income';
    final justIn = sms.receivedAt.isAfter(appClock.now().subtract(Duration(days: features.justInBackfillDays)));
    created.add((
      id,
      PersonalTxnIn(
        type: PersonalTxnInTypeEnum.fromJson(type)!,
        amountMinor: txn.amountMinor,
        description: description,
        date: apiDate(txn.date),
        categoryId: features.suggestCategories
            ? categoryFor(
                ledger,
                description,
                scope: 'personal',
                merchant: txn.merchant,
                income: income,
                learn: features.learnCategories,
                fuzzy: false,
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
    bodies[SmsKeys.body(id)] = sms.toJson();
  }
}

final smsImporterProvider = Provider<SmsImporter>((ref) => SmsImporter(ref));
