import 'dart:isolate';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/categorise/category_rules.dart' show merchantKey;
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/finance/finance.dart' show AccountType, MoneyFlow, TxnType, accountTypeFromWire, addDays;
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
  const SmsSettings({required this.since, this.notify = true, this.lockScreenAmounts = false});

  /// Messages from this day on are read: the range picked when it was turned on.
  final DateTime since;

  /// A notification when a bank SMS arrives with the app closed (features/sms/notifications).
  final bool notify;

  /// Whether a locked phone shows what the notification says ("₹450 at Swiggy"). Off, it
  /// shows "A payment from your bank" until the phone is unlocked (spec §5.7).
  final bool lockScreenAmounts;

  SmsSettings copyWith({bool? notify, bool? lockScreenAmounts}) => SmsSettings(
    since: since,
    notify: notify ?? this.notify,
    lockScreenAmounts: lockScreenAmounts ?? this.lockScreenAmounts,
  );

  Map<String, Object?> toJson() => {
    'since': since.toIso8601String(),
    'notify': notify,
    'lock_screen_amounts': lockScreenAmounts,
  };

  static SmsSettings fromJson(Map<Object?, Object?> j) => SmsSettings(
    since: DateTime.parse(j['since']! as String),
    notify: j['notify'] as bool? ?? true,
    lockScreenAmounts: j['lock_screen_amounts'] as bool? ?? false,
  );
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

  /// Messages whose entries the device wouldn't queue (a check refused them), each with how many
  /// reads have tried: read again by the next read, wherever the cursor is.
  static const retry = 'sms.retry';
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

  /// Reads that try a message whose entries are refused before it's listed as skipped.
  static const retries = 3;

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
      await store.setDeviceValues({SmsKeys.settings: null, SmsKeys.cursor: null, SmsKeys.retry: null});
      await configureNotifications();
      return SmsScan.none;
    }
    await store.setDeviceValues({
      SmsKeys.settings: SmsSettings(since: since, notify: notify).toJson(),
      SmsKeys.cursor: null,
      SmsKeys.retry: null,
    });
    await configureNotifications();
    return scan();
  }

  /// Notifications on or off (while reading is on).
  Future<void> setNotify(bool notify) => _change((s) => s.copyWith(notify: notify));

  /// Whether a locked phone shows what a notification says.
  Future<void> setLockScreenAmounts(bool show) => _change((s) => s.copyWith(lockScreenAmounts: show));

  Future<void> _change(SmsSettings Function(SmsSettings) change) async {
    final settings = await this.settings();
    if (settings == null) return;
    await (await _store).setDeviceValue(SmsKeys.settings, change(settings).toJson());
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
      lockScreenAmounts: settings?.lockScreenAmounts ?? false,
      senderPattern: senderPatternWithTests,
    );
  }

  /// A tapped notification's message: reads the inbox (where it is by now) and returns the
  /// entry it became, or null if it's not one (an entry you'd made, when it was matched, is).
  /// Looked up by id, reference, then amount through the Ledger's indexes.
  Future<String?> importOne(RawSms sms) async {
    await scan();
    final verdict = parseSms(sms, testSenders: _testSenders);
    if (verdict is! SmsParsed) return null;
    final ledger = (await _store).ledger;
    if (ledger.isEmpty) return null;
    final txn = verdict.txn;
    final id = smsEntryId(ledger.me, sms, txn);
    if (ledger.rawPersonal(id) != null) return id;
    // An own transfer or a card bill is an entry only once it's paired (no notification has one).
    if (txn.kind == SmsKind.ownTransfer || txn.kind == SmsKind.cardBill) return null;
    final paid = txn.direction == SmsDirection.spent ? 'expense' : 'income';
    final type = txn.kind == SmsKind.refund ? 'refund' : paid;
    // Known by its reference (another message about it: a refund may have been read as income),
    // or matched to an entry made by hand.
    if (txn.reference case final reference?) {
      for (final t in {type, paid}) {
        if (ledger.personalWithReference(reference, t) case final known?) return known;
      }
    }
    return ledger.personalPaid(type: type, amount: txn.amountMinor, account: txn.account, merchant: txn.merchant);
  }

  /// Whether entry [id] is a spend: what Split on a notification can split.
  Future<bool> isSpend(String id) async => (await _store).ledger.rawPersonal(id)?['type'] == 'expense';

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
    final last = messages.isEmpty ? null : messages.last.receivedAt;
    // Messages whose entries were refused before, however long ago they came: read with the rest.
    final tries = <String, int>{};
    final inWindow = {for (final m in messages) _keyOf(m)};
    final retry = [
      for (final j in ((await store.deviceValue(SmsKeys.retry)) as List?)?.cast<Map<Object?, Object?>>() ?? const [])
        (RawSms.fromJson(j.cast<String, Object?>()), j['tries'] as int? ?? 1),
    ];
    for (final (sms, n) in retry) {
      tries[_keyOf(sms)] = n;
      if (inWindow.add(_keyOf(sms))) messages.add(sms);
    }
    if (retry.isNotEmpty) {
      final order = {for (final (i, m) in messages.indexed) m: i};
      messages.sort((a, b) {
        final c = a.receivedAt.compareTo(b.receivedAt);
        return c != 0 ? c : order[a]!.compareTo(order[b]!);
      });
    }

    Future<SmsScanResult> readOn(Ledger l) =>
        runSmsScan(smsScanInput(l, messages, features, attachedBefore: attachedBefore.toSet()));
    var found = await readOn(ledger);
    // A sync changed your entries while it ran: decide again on what's here now.
    if (!_sameEntries(store.ledger, ledger)) found = await readOn(store.ledger);

    // Everything read is queued together, in `POST /personal/batch` requests: one rebuild however
    // many entries. A unit the device refuses (with those that need it) is left out, and the rest
    // queued: its messages are read again next time.
    final refused = <String>{};
    await _ref
        .read(writesProvider)
        .importUnits(
          smsImportUnits(store.ledger, found),
          chunk: features.importChunk,
          onRefused: (unit, why) {
            refused.addAll(unit.map((i) => i.id));
            debugPrint('Bank SMS: not queued (${apiErrorCode(why) ?? why}): ${unit.join(', ')}');
          },
        );
    final notAdded = _refusedMessages(found, messages, refused, store.ledger.me);
    final bodies = {
      for (final MapEntry(:key, :value) in found.bodies.entries)
        if (!refused.contains(key)) key: value,
    };
    final attached = [
      for (final a in found.attached)
        if (!refused.contains(a.entryId)) a,
    ];
    final kept = ((await store.deviceValue(SmsKeys.skipped)) as List?)?.cast<Map<Object?, Object?>>() ?? const [];
    final listed = {for (final s in kept) '${s['address']}|${s['body']}'};
    // Tried enough: listed as skipped, so it stops coming back (one listed already stays so).
    final givenUp = <SkippedSms>[];
    final again = <Map<String, Object?>>[];
    for (final sms in notAdded) {
      if (listed.contains(_keyOf(sms))) continue;
      final n = (tries[_keyOf(sms)] ?? 0) + 1;
      if (n < retries) {
        again.add({...sms.toJson(), 'tries': n});
        continue;
      }
      debugPrint('Bank SMS: a message from ${sms.address} was refused on $n reads; listed as skipped');
      givenUp.add((sms: sms, reason: _skipFor(sms)));
    }

    // A message skipped before (a card bill whose payment hadn't come yet) and added now.
    final added = {for (final b in bodies.values) '${b['address']}|${b['body']}'};
    final skipped = [
      for (final s in [...found.skipped, ...givenUp]) {...s.sms.toJson(), 'reason': s.reason.name},
      for (final s in kept)
        if (!added.contains('${s['address']}|${s['body']}')) s,
    ];
    final seen = <String>{};
    await store.setDeviceValues({
      for (final MapEntry(:key, :value) in bodies.entries) SmsKeys.body(key): value,
      SmsKeys.skipped: [
        for (final s in skipped)
          if (seen.add('${s['address']}|${s['body']}')) s,
      ].take(_keepSkipped).toList(),
      if (last != null) SmsKeys.cursor: last.toIso8601String(),
      if (attached.isNotEmpty) SmsKeys.attached: [...attachedBefore, for (final a in attached) a.smsId],
      if (retry.isNotEmpty || again.isNotEmpty) SmsKeys.retry: again.isEmpty ? null : again,
    });
    // Each message that became an entry counts once (a cash withdrawal's cash half doesn't).
    return SmsScan(
      added: bodies.length,
      attached: attached.length,
      skipped: found.skipped.length + givenUp.length,
      known: found.known,
    );
  }

  /// A message as "Messages we skipped" and the retry list tell them apart.
  static String _keyOf(RawSms sms) => '${sms.address}|${sms.body}';

  /// The messages of [messages] behind the [refused] entries of [found] (new entries, entries
  /// you'd made that a message was about, and so the halves made with them), oldest first.
  static List<RawSms> _refusedMessages(SmsScanResult found, List<RawSms> messages, Set<String> refused, String me) {
    if (refused.isEmpty) return const [];
    final out = <String, RawSms>{
      for (final id in refused)
        if (found.bodies[id] case final body?) _keyOf(RawSms.fromJson(body)): RawSms.fromJson(body),
    };
    final smsIds = {
      for (final a in found.attached)
        if (refused.contains(a.entryId)) a.smsId,
    };
    if (smsIds.isNotEmpty) {
      for (final m in messages) {
        final verdict = parseSms(m, testSenders: _testSenders);
        if (verdict case SmsParsed(:final txn) when smsIds.contains(smsEntryId(me, m, txn))) {
          out[_keyOf(m)] = m;
        }
      }
    }
    return out.values.toList()..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
  }

  /// What a message whose entries kept being refused is listed under in "Messages we skipped".
  static SmsSkip _skipFor(RawSms sms) => switch (parseSms(sms, testSenders: _testSenders)) {
    SmsParsed(txn: SmsTxn(kind: SmsKind.refund)) => SmsSkip.refund,
    SmsParsed(txn: SmsTxn(kind: SmsKind.cardBill)) => SmsSkip.cardBill,
    SmsParsed(txn: SmsTxn(kind: SmsKind.ownTransfer)) => SmsSkip.ownTransfer,
    _ => SmsSkip.noTransaction,
  };

  /// Whether [a] and [b] have the same personal entries, groups and profile (what a read decides
  /// from).
  static bool _sameEntries(Ledger a, Ledger b) {
    if (identical(a, b)) return true;
    final (x, y) = (a.revisions, b.revisions);
    return x.store != 0 &&
        x.store == y.store &&
        x.personal == y.personal &&
        x.groups == y.groups &&
        x[LedgerDomain.profile] == y[LedgerDomain.profile];
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

/// What a read of [messages] needs from [ledger] (core/sms/sms_scan.dart), taken now: plain data,
/// so it can go to another isolate.
SmsScanInput smsScanInput(
  Ledger ledger,
  List<RawSms> messages,
  Features features, {
  Set<String> attachedBefore = const {},
}) {
  final finance = ledger.finance;
  final currency = ledger.userOut()['currency'];
  // An account linked to another counts as that one: its type, and open only while it is.
  SmsAccount sms(Map<String, dynamic> a, {required bool deleted}) {
    final type = accountTypeFromWire(a['type'] as String?);
    final whole = deleted ? null : finance.wholeOf(a['id'] as String);
    return (
      id: a['id'] as String,
      type: whole?.type ?? type ?? AccountType.otherAsset,
      active:
          !deleted && a['status'] == 'active' && a['currency'] == currency && type != null && !(whole?.closed ?? false),
      deleted: deleted,
    );
  }

  // A live account wins over a deleted one with the same label.
  final accountsByLabel = <String, SmsAccount>{
    for (final deleted in const [true, false])
      for (final a in ledger.personalAccountList(deleted: deleted))
        if (a['sms_label'] case final String label) label: sms(a, deleted: deleted),
  };
  final accountsById = <String, SmsAccount>{
    for (final a in ledger.personalAccountList()) a['id'] as String: sms(a, deleted: false),
  };
  final references = ledger.personalReferences();
  final refunds = <SmsRefundCandidate>[];
  final transfers = <SmsTransferCandidate>[];
  final unlinked = <SmsUnlinked>[];
  final manualWithAccount = <String>{};
  if (messages.isNotEmpty) {
    var first = messages.first.receivedAt;
    for (final m in messages) {
      if (m.receivedAt.isBefore(first)) first = m.receivedAt;
    }
    // A message can be about a day up to 10 days before it came (sms_parser.dart _date).
    final from = first.subtract(const Duration(days: 10));
    final fromDay = from.year * 10000 + from.month * 100 + from.day;
    final refundFrom = addDays(fromDay, -features.refundMatchDays), pairFrom = addDays(fromDay, -3);
    final notCounted = ledger.notCounted;
    final keys = <String?, String>{};
    for (final t in ledger.personalRows) {
      // A refund or a transfer half read from a message is known by its reference as the income
      // or the spend it was read as.
      if (t.reference case final ref? when t.type != 'expense' && t.type != 'income') {
        references.add('$ref|${t.flow == MoneyFlow.inflow ? 'income' : 'expense'}');
      }
      // An entry you made that's in an account, or in another currency, keeps its account.
      if (t.source == 'manual' && t.account == null && (t.accountId != null || t.currency != currency)) {
        manualWithAccount.add(t.id);
      }
      // What a read adds is in your currency, and so is what it points at or pairs with.
      if (t.deleted || t.currency != currency) continue;
      final type = t.txnType;
      if (type == TxnType.expense && t.day >= refundFrom) {
        refunds.add((
          id: t.id,
          merchantKey: keys[t.merchant] ??= merchantKey(t.merchant),
          reference: t.reference,
          amount: t.amount,
          refundable: finance.refundableMinor(t),
          accountId: t.accountId,
          categoryId: t.categoryId,
          day: t.day,
          atMicros: t.atMicros,
          createdMicros: t.createdMicros,
        ));
      }
      // A cash withdrawal is no other half (atmToCash pairs it with Cash).
      if ((type == TxnType.expense || type == TxnType.income) &&
          t.channel != 'atm' &&
          t.day >= pairFrom &&
          t.transferGroupId == null &&
          t.expenseId == null &&
          t.settlementId == null &&
          !notCounted.contains(t.id) &&
          (type == TxnType.income || finance.refundableMinor(t) == t.amount)) {
        if (t.accountId case final id?) {
          if (finance.account(id) case final a? when !a.deleted && !a.closed) {
            transfers.add((
              id: t.id,
              flow: t.flow,
              amount: t.amount,
              accountId: id,
              accountType: finance.wholeOf(id)?.type ?? a.type,
              day: t.day,
              atMicros: t.atMicros,
              version: t.raw['version'] as int,
            ));
          }
        }
      }
      if (t.accountId == null && t.account != null && !accountsByLabel.containsKey(t.account)) {
        unlinked.add((
          id: t.id,
          label: t.account!,
          type: t.type,
          flow: t.flow,
          amount: t.amount,
          day: t.day,
          atMicros: t.atMicros,
          createdMicros: t.createdMicros,
          balance: t.balance,
        ));
      }
    }
  }
  return SmsScanInput(
    messages: messages,
    userId: ledger.me,
    knownIds: ledger.personalIds(),
    references: references,
    attachedBefore: attachedBefore,
    manual: ledger.manualCandidates(),
    manualWithAccount: manualWithAccount,
    categories: features.suggestCategories ? ledger.learnedCategories('personal') : null,
    features: features,
    now: appClock.now(),
    testSenders: SmsImporter._testSenders,
    accountsByLabel: accountsByLabel,
    accounts: finance.accounts,
    accountsById: accountsById,
    firstActiveCashId: switch (finance.firstActiveCash()) {
      final cash? when cash.currency == currency => cash.id,
      _ => null,
    },
    refundCandidates: refunds,
    transferCandidates: transfers,
    unlinked: unlinked,
  );
}

/// What [read] found, as the units of `POST /personal/batch` items it's queued in
/// (FinanceWrites.importUnits): an account made; an entry made; a transfer's two halves, made, or
/// one already here changed and the other made; an entry you'd made by hand, given what the
/// message says. Bodies of entries already here start from [ledger] (what's on the device now): a
/// transfer half that changed since the read saw it is left out with its other half, and so is
/// an entry you'd made that's gone, so the next read decides again.
///
/// An income goes with the plans your allocation rules make for it (entryCreateUnit), in its
/// unit, which is never split; an entry changed goes with what that does to its plans
/// (entryUpdateUnit: an income turned into a transfer half deletes its plans first). Worked out
/// here, on the main isolate, from what the read found: a few incomes times a few rules. Old SMS
/// get no plans, since a rule applies only to incomes recorded after it.
List<List<BatchItem>> smsImportUnits(Ledger ledger, SmsScanResult read) {
  final units = <List<BatchItem>>[
    for (final a in read.newAccounts)
      [
        BatchItem.createAccount(
          a.id,
          PersonalAccountIn(
            name: a.label,
            type: PersonalAccountInTypeEnum.fromJson(a.type.wire)!,
            openingBalanceMinor: a.openingMinor,
            smsLabel: a.label,
          ),
        ),
      ],
  ];
  PersonalTxnIn bodyOf(String id) => personalBody(PersonalTxnOut.fromJson(ledger.personalTransaction(id))!);
  final transfers = <String, List<BatchItem>>{};
  final stale = <String>{};
  void add(String? group, BatchItem item) {
    if (group == null) return units.add([item]);
    transfers.putIfAbsent(group, () => (units..add([])).last).add(item);
  }

  // The entry changed into a half goes before the half made with it, as convertToTransfer does.
  for (final c in read.convert) {
    final t = ledger.rawPersonal(c.id);
    if (t == null || t['version'] != c.version || t['deleted_at'] != null) {
      stale.add(c.groupId);
      continue;
    }
    final changed = entryUpdateUnit(
      ledger,
      c.id,
      bodyOf(c.id)
        ..type = PersonalTxnInTypeEnum.transfer
        ..direction = PersonalTxnInDirectionEnum.fromJson(c.flow.wire)
        ..categoryId = null
        ..transferGroupId = c.groupId
        ..refundOfId = null
        ..holdingId = null,
    );
    for (final item in changed) {
      add(c.groupId, item);
    }
  }
  for (final (id, body) in read.created) {
    if (body.transferGroupId case final group?) {
      add(group, BatchItem.createEntry(id, body));
    } else {
      units.add(entryCreateUnit(ledger, id, body));
    }
  }
  for (final a in read.attached) {
    final t = ledger.rawPersonal(a.entryId);
    if (t == null || t['deleted_at'] != null) continue;
    final body = bodyOf(a.entryId)
      ..merchant = a.merchant
      ..account = a.account
      ..channel ??= PersonalTxnInChannelEnum.fromJson(a.channel);
    body.accountId ??= a.accountId;
    units.add(entryUpdateUnit(ledger, a.entryId, body));
  }
  for (final group in stale) {
    units.remove(transfers[group]);
  }
  return units;
}

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
