/// One read of the bank SMS on this phone, decided without the app: for each message, whether
/// it's a new entry (in which account, and whether it's a refund or one half of a transfer), an
/// entry you'd made by hand, a payment already here, or skipped. Pure: everything in and out can
/// go to another isolate, so a big first read runs off the UI (features/sms/sms_importer.dart
/// takes the input from the device's data and queues the output).
///
/// The input and output are records of plain data, so later reads add fields here, not another
/// pass.
///
/// After the checks for a payment already here, each message is read in order (design §5.2):
/// 1. Its account: your open account with the message's label; none when that account is closed
///    or deleted (the entry keeps the label); else the one account the label's digits say it is
///    (its full number ends in them, or it's the same card labelled another way:
///    account_links.dart accountForNewLabel); else a new account for the label, which starts
///    reconciled (its opening balance comes from the first balance its messages report). An
///    account linked to another counts as that one: its type, and closed when that one is.
/// 2. A refund is money back into the account, for the spend it matches ([refundTarget]'s rules,
///    counting what earlier refunds took back), in that spend's category.
/// 3. A cash withdrawal, when you keep a Cash account, is a transfer into it.
/// 4. A card bill pairs with the one payment of its amount out of a bank or cash account within 3
///    days of it: that payment becomes the transfer's other half.
/// 5. An own transfer pairs with the nearest money going the other way, of its amount, in another
///    account, within [Features.transferSuggestionMinutes].
///
/// Card bills and own transfers are paired once every message is read, so the other half may come
/// later in the inbox. One whose other half isn't found is skipped, and read again by the next read
/// (which goes back a few days). Plain payments are never paired here: the finance engine's
/// transfer suggestions offer that, and you decide.
library;

import '../api/api.dart';
import '../categorise/category_guesser.dart' show keywordCategory;
import '../categorise/category_rules.dart';
import '../finance/finance.dart';
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
/// the message's own id (so a later read knows it). [accountId] is the account the message names,
/// for an entry with none yet (null: it keeps its own).
typedef SmsAttachment = ({
  String entryId,
  String? merchant,
  String? account,
  String channel,
  String smsId,
  String? accountId,
});

/// One of your accounts: whether a message's entry can go in it ([active]: open, not deleted, in
/// your currency, and the account it's linked to open too), and the type its entries count as
/// (the linked-to account's). A closed or deleted account keeps its label.
typedef SmsAccount = ({String id, AccountType type, bool active, bool deleted});

/// A live spend a refund could be for, as refundTarget (core/finance/refunds.dart) compares them,
/// with what's left to refund of it ([refundable]).
typedef SmsRefundCandidate = ({
  String id,
  String merchantKey,
  String? reference,
  int amount,
  int refundable,
  String? accountId,
  String? categoryId,
  int day,
  int atMicros,
  int createdMicros,
});

/// A live spend or income in your currency, in one of your open accounts, counted, and neither a
/// transfer leg, refunded nor a cash withdrawal: the other half an own transfer or a card bill can
/// pair with.
typedef SmsTransferCandidate = ({
  String id,
  MoneyFlow flow,
  int amount,
  String accountId,
  AccountType accountType,
  int day,
  int atMicros,
  int version,
});

/// A live entry with a bank label no account has: the account a read makes for that label takes
/// it in (as the server does), so its opening balance counts it.
typedef SmsUnlinked = ({
  String id,
  String label,
  String type,
  MoneyFlow flow,
  int amount,
  int day,
  int atMicros,
  int createdMicros,
  int? balance,
});

/// An account a read makes for a bank label: smsAccountId of you and the label, so another phone
/// (or the server's backfill) makes the same one.
typedef SmsNewAccount = ({String id, String label, AccountType type, int openingMinor});

/// An entry already here that becomes one half of transfer [groupId], going [flow]. [version] is
/// the one the read saw.
typedef SmsConversion = ({String id, int version, MoneyFlow flow, String groupId});

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
    this.accountsByLabel = const {},
    this.accounts = const [],
    this.accountsById = const {},
    this.firstActiveCashId,
    this.refundCandidates = const [],
    this.transferCandidates = const [],
    this.unlinked = const [],
    this.manualWithAccount = const {},
  });

  /// Oldest first, as the inbox gives them.
  final List<RawSms> messages;
  final String userId;

  /// The id of every personal entry here, deleted ones too (Ledger.personalIds).
  final Set<String> knownIds;

  /// "reference|type" of every entry with a bank reference, deleted ones too
  /// (Ledger.personalReferences); a transfer leg or a refund as the spend or income it was.
  final Set<String> references;

  /// Ids of messages that were about an entry made by hand, in an earlier read.
  final Set<String> attachedBefore;

  /// Entries made by hand with no label yet: by type and amount, (id, dayKey) in the API's
  /// order (Ledger.manualCandidates).
  final Map<(String, int), List<(String, int)>> manual;

  /// Those of [manual] that keep their account: in one already, or in another currency.
  final Set<String> manualWithAccount;

  /// Personal's learned categories (Ledger.learnedCategories), or null when suggestions are off.
  final LearnedCategories? categories;
  final Features features;

  /// For what's "just in".
  final DateTime now;

  /// Senders read as banks when testing on an emulator.
  final Set<String> testSenders;

  /// Your accounts with a label, by label (the live one, should a deleted one have it too).
  final Map<String, SmsAccount> accountsByLabel;

  /// Your live accounts (closed ones too), which a label no account has may still be
  /// (accountForNewLabel), and each of them as [SmsAccount], by id.
  final List<FinAccount> accounts;
  final Map<String, SmsAccount> accountsById;

  /// Where a cash withdrawal goes: your oldest open cash account (FinanceEngine.firstActiveCash).
  final String? firstActiveCashId;

  /// Spends from [Features.refundMatchDays] before the first message on.
  final List<SmsRefundCandidate> refundCandidates;

  /// From 3 days before the first message on.
  final List<SmsTransferCandidate> transferCandidates;

  final List<SmsUnlinked> unlinked;
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
    this.newAccounts = const [],
    this.convert = const [],
  });

  /// Accounts to make first, for labels with none.
  final List<SmsNewAccount> newAccounts;

  /// New entries, in the order read, with the id each gets: a message's own id, or for the cash
  /// half of a withdrawal, pairedLegId of it. Each has its account, type, direction, category and,
  /// as fits, the spend it refunds or its transfer group (both halves share one).
  final List<(String, PersonalTxnIn)> created;
  final List<SmsAttachment> attached;

  /// Entries already here that become a transfer's other half (its group is in [created]).
  final List<SmsConversion> convert;
  final List<SkippedSms> skipped;

  /// The message each new entry came from, by entry id (kept on this phone only).
  final Map<String, Map<String, Object?>> bodies;

  /// Payments already here: from an earlier read, or another message about the same one.
  final int known;

  /// When the newest message arrived (where the next read starts), or null with none.
  final DateTime? last;
}

/// Reads [input]'s messages in order.
SmsScanResult scanSms(SmsScanInput input) => _Read(input).run();

/// A spend a refund can be for: one already here, or one this read adds.
final class _Spend {
  _Spend({
    required this.id,
    required this.amount,
    required this.left,
    required this.reference,
    required this.merchant,
    required this.accountId,
    required this.categoryId,
    required this.day,
    required this.atMicros,
    required this.createdMicros,
    this.key,
  });

  final String id;
  final int amount;

  /// What's left to refund of it.
  int left;
  final String? reference;
  final String? merchant;
  final String? accountId;
  final String? categoryId;
  final int day;
  final int atMicros;
  final int createdMicros;

  /// merchantKey of [merchant], worked out when a refund first looks.
  String? key;
}

/// An entry a transfer can pair with: one already here ([version]), or one this read adds ([body]).
final class _Half {
  _Half({
    required this.id,
    required this.flow,
    required this.amount,
    required this.accountId,
    required this.accountType,
    required this.day,
    required this.atMicros,
    this.version,
    this.body,
  });

  final String id;
  final MoneyFlow flow;
  final int amount;
  final String accountId;
  final AccountType accountType;
  final int day;
  final int atMicros;
  final int? version;
  final PersonalTxnIn? body;
}

/// An account an entry goes in.
typedef _Account = ({String id, AccountType type});

/// An own transfer or a card bill, paired once every message is read.
final class _Pending {
  _Pending(this.index, this.sms, this.txn, this.id, this.account, this.justIn);

  final int index;
  final RawSms sms;
  final SmsTxn txn;
  final String id;
  final _Account? account;
  final bool justIn;
  bool paired = false;

  MoneyFlow get flow => txn.direction == SmsDirection.spent ? MoneyFlow.outflow : MoneyFlow.inflow;
  int get atMicros => sms.receivedAt.microsecondsSinceEpoch;
}

class _Read {
  _Read(this.input) : f = input.features, _references = {...input.references};

  final SmsScanInput input;
  final Features f;
  final Set<String> _references;
  final _ids = <String>{};

  final _created = <(String, PersonalTxnIn)>[];
  final _attached = <SmsAttachment>[];
  final _convert = <SmsConversion>[];
  final _skipped = <(int, SkippedSms)>[];
  final _bodies = <String, Map<String, Object?>>{};
  var _known = 0;

  /// Entries made by hand that a message in this read is about.
  final _attachedIds = <String>{};

  /// Entries that can't be a transfer's other half any more: attached, refunded or paired in this
  /// read.
  final _used = <String>{};

  /// The accounts this read makes, by label, and the entries it puts in each (for its opening
  /// balance).
  final _made = <String, _Account>{};
  final _onMade = <String, List<FinEntry>>{};

  /// Spends a refund can be for (those here first, then this read's), and, once a refund looks,
  /// by reference and by merchant key.
  late final List<_Spend> _spends = [
    for (final c in input.refundCandidates)
      _Spend(
        id: c.id,
        amount: c.amount,
        left: c.refundable,
        reference: c.reference,
        merchant: null,
        key: c.merchantKey,
        accountId: c.accountId,
        categoryId: c.categoryId,
        day: c.day,
        atMicros: c.atMicros,
        createdMicros: c.createdMicros,
      ),
  ];
  Map<String, List<_Spend>>? _byReference, _byMerchant;

  /// Halves a transfer can pair with, by amount: those here, then this read's spends and incomes.
  late final Map<int, List<_Half>> _halves = () {
    final out = <int, List<_Half>>{};
    for (final c in input.transferCandidates) {
      (out[c.amount] ??= []).add(
        _Half(
          id: c.id,
          flow: c.flow,
          amount: c.amount,
          accountId: c.accountId,
          accountType: c.accountType,
          day: c.day,
          atMicros: c.atMicros,
          version: c.version,
        ),
      );
    }
    return out;
  }();

  final _pending = <_Pending>[];

  /// This read's entries are made after everything already here.
  late final int _nowMicros = input.now.microsecondsSinceEpoch;

  SmsScanResult run() {
    for (final (i, sms) in input.messages.indexed) {
      switch (parseSms(sms, testSenders: input.testSenders)) {
        case SmsSkipped(:final reason):
          // Not kept: codes, and anything not from a bank.
          if (reason != SmsSkip.otp && reason != SmsSkip.notABank) _skip(i, sms, reason);
        case SmsParsed(:final txn):
          _read(i, sms, txn);
      }
    }
    for (final p in _pending) {
      if (!p.paired) _pair(p);
    }
    _skipped.sort((a, b) => a.$1.compareTo(b.$1));
    final unlinked = <String, List<FinEntry>>{};
    if (_made.isNotEmpty) {
      for (final u in input.unlinked) {
        if (!_made.containsKey(u.label)) continue;
        (unlinked[u.label] ??= []).add(
          _row(
            u.id,
            type: u.type,
            flow: u.flow,
            amount: u.amount,
            day: u.day,
            atMicros: u.atMicros,
            createdMicros: u.createdMicros,
            balance: u.balance,
          ),
        );
      }
    }
    return SmsScanResult(
      newAccounts: [
        for (final MapEntry(key: label, value: a) in _made.entries)
          (
            id: a.id,
            label: label,
            type: a.type,
            openingMinor: openingFromFirstReport([...?_onMade[label], ...?unlinked[label]], a.type),
          ),
      ],
      created: _created,
      attached: _attached,
      convert: _convert,
      skipped: [for (final (_, s) in _skipped) s],
      bodies: _bodies,
      known: _known,
      last: input.messages.isEmpty ? null : input.messages.last.receivedAt,
    );
  }

  void _skip(int index, RawSms sms, SmsSkip reason) => _skipped.add((index, (sms: sms, reason: reason)));

  void _read(int index, RawSms sms, SmsTxn txn) {
    final id = smsEntryId(input.userId, sms, txn);
    final type = txn.direction == SmsDirection.spent ? 'expense' : 'income';
    final ref = txn.reference == null ? null : '${txn.reference}|$type';
    // Already here: read before (even if deleted since), or another message about it.
    if (!_ids.add(id) ||
        input.knownIds.contains(id) ||
        input.attachedBefore.contains(id) ||
        (ref != null && _references.contains(ref))) {
      _known++;
      return;
    }
    if (ref != null) _references.add(ref);
    // A first read going back months: only the last few days are "just in".
    final justIn = sms.receivedAt.isAfter(input.now.subtract(Duration(days: f.justInBackfillDays)));
    final account = _accountFor(txn.account);
    switch (txn.kind) {
      case SmsKind.payment:
        _payment(sms, txn, id, type, account, justIn);
      case SmsKind.refund:
        _refund(index, sms, txn, id, account, justIn);
      case SmsKind.cardBill when !f.transfers || !f.pairCardBills:
        _skip(index, sms, SmsSkip.cardBill);
      case SmsKind.ownTransfer when !f.transfers:
        _skip(index, sms, SmsSkip.ownTransfer);
      case SmsKind.cardBill || SmsKind.ownTransfer:
        _pending.add(_Pending(index, sms, txn, id, account, justIn));
    }
  }

  /// The account an entry with [label] goes in: your open account with that label, none if the
  /// account is closed or deleted, the one account the label's digits say it is (none if that one
  /// isn't open), else the one this read makes for it ([_put] notes it).
  _Account? _accountFor(String? label) {
    if (label == null) return null;
    if (input.accountsByLabel[label] case final a?) return a.active ? (id: a.id, type: a.type) : null;
    if (_made[label] case final made?) return made;
    if (_matched.containsKey(label)) return _matched[label];
    if (accountForNewLabel(label, input.accounts) case final found?) {
      final a = input.accountsById[found.id];
      return _matched[label] = a != null && a.active ? (id: a.id, type: a.type) : null;
    }
    return (id: smsAccountId(input.userId, label), type: accountTypeForLabel(label));
  }

  /// Labels no account has that are an account already here (accountForNewLabel), or null when
  /// that one isn't open.
  final _matched = <String, _Account?>{};

  /// Notes that [row] goes in [account] (the account for [label]): an account with no label yet
  /// is made, and its opening balance counts the entry.
  void _put(String? label, _Account? account, FinEntry Function() row) {
    if (label == null || account == null || input.accountsByLabel.containsKey(label) || _matched.containsKey(label)) {
      return;
    }
    _made[label] ??= account;
    (_onMade[label] ??= []).add(row());
  }

  void _payment(RawSms sms, SmsTxn txn, String id, String type, _Account? account, bool justIn) {
    final cash = input.firstActiveCashId;
    // A cash withdrawal, with a Cash account to put it in: money moved, not spent. (Not when its
    // cash half was made before, and is gone: that pair was undone.)
    final toCash =
        txn.channel == 'atm' &&
        txn.direction == SmsDirection.spent &&
        f.transfers &&
        f.atmToCash &&
        cash != null &&
        account != null &&
        account.id != cash &&
        !input.knownIds.contains(pairedLegId(id));
    if (txn.channel == 'atm' && !toCash && !f.countAtmAsSpending) return;
    // Entered by hand already: give that entry the bank's details instead.
    if (_attach(sms, txn, id, type, account)) return;
    final description = smsDescription(txn);
    if (toCash) {
      final group = transferGroupIdFor(id);
      const withdrawal = 'Cash withdrawal';
      _add(
        sms,
        txn,
        id,
        _entry(sms, txn, 'transfer', MoneyFlow.outflow, withdrawal, account, justIn: justIn, group: group),
        account,
      );
      _created.add((
        pairedLegId(id),
        PersonalTxnIn(
          type: PersonalTxnInTypeEnum.transfer,
          amountMinor: txn.amountMinor,
          description: withdrawal,
          date: apiDate(txn.date),
          channel: PersonalTxnInChannelEnum.fromJson(txn.channel),
          accountId: cash,
          direction: PersonalTxnInDirectionEnum.in_,
          transferGroupId: group,
          source_: PersonalTxnInSource_Enum.manual,
        ),
      ));
      return;
    }
    final flow = type == 'income' ? MoneyFlow.inflow : MoneyFlow.outflow;
    final body = _entry(
      sms,
      txn,
      type,
      flow,
      description,
      account,
      justIn: justIn,
      category: _guess(description, txn.merchant, income: flow == MoneyFlow.inflow),
    );
    _add(sms, txn, id, body, account);
    final day = _day(txn.date);
    if (flow == MoneyFlow.outflow) {
      _addSpend(
        _Spend(
          id: id,
          amount: txn.amountMinor,
          left: txn.amountMinor,
          reference: txn.reference,
          merchant: txn.merchant,
          accountId: account?.id,
          categoryId: body.categoryId,
          day: day,
          atMicros: sms.receivedAt.microsecondsSinceEpoch,
          createdMicros: _nowMicros,
        ),
      );
    }
    // A cash withdrawal counted as spending is no transfer's other half.
    if (account != null && txn.channel != 'atm') {
      (_halves[txn.amountMinor] ??= []).add(
        _Half(
          id: id,
          flow: flow,
          amount: txn.amountMinor,
          accountId: account.id,
          accountType: account.type,
          day: day,
          atMicros: sms.receivedAt.microsecondsSinceEpoch,
          body: body,
        ),
      );
    }
  }

  /// A message about an entry you'd made by hand, of [type]: true when it's attached to it.
  bool _attach(RawSms sms, SmsTxn txn, String id, String type, _Account? account) {
    final match = _manualMatch(input.manual, type, txn.amountMinor, txn.date);
    if (match == null || !_attachedIds.add(match.$1)) return false;
    final entryId = match.$1;
    final accountId = input.manualWithAccount.contains(entryId) ? null : account?.id;
    _attached.add((
      entryId: entryId,
      merchant: txn.merchant,
      account: txn.account,
      channel: txn.channel,
      smsId: id,
      accountId: accountId,
    ));
    _used.add(entryId);
    if (accountId != null) {
      // When it was made isn't known here: when the message came is near enough.
      _put(
        txn.account,
        account,
        () => _row(
          entryId,
          type: type,
          flow: type == 'expense' ? MoneyFlow.outflow : MoneyFlow.inflow,
          amount: txn.amountMinor,
          day: match.$2,
          atMicros: sms.receivedAt.microsecondsSinceEpoch,
        ),
      );
    }
    return true;
  }

  void _refund(int index, RawSms sms, SmsTxn txn, String id, _Account? account, bool justIn) {
    if (!f.refunds) return _skip(index, sms, SmsSkip.refund);
    if (_attach(sms, txn, id, 'refund', account)) return;
    final description = smsDescription(txn);
    final target = _refundTarget(
      txn.amountMinor,
      _day(txn.date),
      txn.reference,
      merchantKey(txn.merchant),
      account?.id,
    );
    if (target != null) {
      target.left -= txn.amountMinor;
      _used.add(target.id);
    }
    _add(
      sms,
      txn,
      id,
      _entry(
        sms,
        txn,
        'refund',
        MoneyFlow.inflow,
        description,
        account,
        justIn: justIn,
        // Off spending where the spend went; for an unknown spend, as a spend there would be.
        category: target != null ? target.categoryId : _guess(description, txn.merchant, income: false),
        refundOf: target?.id,
      ),
      account,
    );
  }

  /// refundTarget (core/finance/refunds.dart) over [_spends]: a spend with the same bank
  /// [reference], else from the same merchant ([key]) up to [Features.refundMatchDays] before
  /// [day]; either way with at least [amount] left to refund. Of several, the one in the same
  /// account, then of exactly [amount], then the newest, then by id.
  _Spend? _refundTarget(int amount, int day, String? reference, String key, String? accountId) {
    if (_byReference == null) {
      _byReference = {};
      _byMerchant = {};
      _spends.forEach(_index);
    }
    final ref = reference == null || reference.isEmpty ? null : reference;
    _Spend? best(Iterable<_Spend> found) {
      _Spend? pick;
      for (final s in found) {
        if (s.left < amount) continue;
        if (pick == null || _prefer(s, pick, amount, accountId) < 0) pick = s;
      }
      return pick;
    }

    final from = addDays(day, -f.refundMatchDays);
    final byReference = ref == null ? null : best(_byReference![ref] ?? const []);
    if (byReference != null || key.isEmpty) return byReference;
    return best([
      for (final s in _byMerchant![key] ?? const <_Spend>[])
        if (s.reference != ref || ref == null)
          if (s.day >= from && s.day <= day) s,
    ]);
  }

  void _addSpend(_Spend s) {
    _spends.add(s);
    if (_byReference != null) _index(s);
  }

  void _index(_Spend s) {
    if (s.reference case final ref? when ref.isNotEmpty) (_byReference![ref] ??= []).add(s);
    final key = s.key ??= merchantKey(s.merchant);
    if (key.isNotEmpty) (_byMerchant![key] ??= []).add(s);
  }

  /// A card bill or an own transfer, with every message read: paired, or skipped.
  void _pair(_Pending p) {
    final bill = p.txn.kind == SmsKind.cardBill;
    final account = p.account;
    if (account == null) return _skip(p.index, p.sms, bill ? SmsSkip.cardBill : SmsSkip.ownTransfer);
    if (bill) {
      // The one payment of the bill out of a bank or cash account, within 3 days of it.
      final day = _day(p.txn.date);
      final from = addDays(day, -3), to = addDays(day, 3);
      final found = [
        for (final h in _halves[p.txn.amountMinor] ?? const <_Half>[])
          if (h.flow == MoneyFlow.outflow &&
              (h.accountType == AccountType.bank || h.accountType == AccountType.cash) &&
              h.accountId != account.id &&
              h.day >= from &&
              h.day <= to &&
              !_used.contains(h.id))
            h,
      ];
      if (found.length != 1) return _skip(p.index, p.sms, SmsSkip.cardBill);
      final group = transferGroupIdFor(p.id);
      const bill = 'Credit card bill';
      _join(found.single, group, bill);
      _leg(p, group, bill);
      return;
    }
    // The nearest money the other way, of the same amount, in another account: an entry, or
    // another own transfer's message.
    final span = f.transferSuggestionMinutes * Duration.microsecondsPerMinute;
    final want = p.flow.opposite;
    (int, String, Object)? best;
    void consider(String id, int atMicros, Object half) {
      final apart = (atMicros - p.atMicros).abs();
      if (apart > span) return;
      // Nearer than the best so far, or as near with a smaller id.
      if (best case (final was, final wasId, _) when was < apart || (was == apart && wasId.compareTo(id) <= 0)) return;
      best = (apart, id, half);
    }

    for (final h in _halves[p.txn.amountMinor] ?? const <_Half>[]) {
      if (h.flow == want && h.accountId != account.id && !_used.contains(h.id)) consider(h.id, h.atMicros, h);
    }
    for (final q in _pending) {
      if (q != p &&
          !q.paired &&
          q.txn.kind == SmsKind.ownTransfer &&
          q.flow == want &&
          q.txn.amountMinor == p.txn.amountMinor &&
          q.account != null &&
          q.account!.id != account.id) {
        consider(q.id, q.atMicros, q);
      }
    }
    final other = best?.$3;
    if (other == null) return _skip(p.index, p.sms, SmsSkip.ownTransfer);
    const self = 'Self transfer';
    switch (other) {
      case _Pending q:
        final group = transferGroupIdFor(p.id, q.id);
        q.paired = true;
        _leg(p, group, self);
        _leg(q, group, self);
      case _Half h:
        final group = transferGroupIdFor(p.id, h.id);
        _join(h, group, self);
        _leg(p, group, self);
    }
  }

  /// [h] becomes the other half of transfer [group]: an entry here is changed, one this read adds
  /// is made as a leg, called [description].
  void _join(_Half h, String group, String description) {
    _used.add(h.id);
    if (h.body case final body?) {
      body
        ..type = PersonalTxnInTypeEnum.transfer
        ..direction = PersonalTxnInDirectionEnum.fromJson(h.flow.wire)
        ..description = description
        ..categoryId = null
        ..transferGroupId = group;
    } else {
      _convert.add((id: h.id, version: h.version!, flow: h.flow, groupId: group));
    }
  }

  /// [p]'s own half of transfer [group].
  void _leg(_Pending p, String group, String description) {
    p.paired = true;
    _add(
      p.sms,
      p.txn,
      p.id,
      _entry(p.sms, p.txn, 'transfer', p.flow, description, p.account, justIn: p.justIn, group: group),
      p.account,
    );
  }

  /// A new entry from [sms], in [account].
  void _add(RawSms sms, SmsTxn txn, String id, PersonalTxnIn body, _Account? account) {
    _created.add((id, body));
    _bodies[id] = sms.toJson();
    _put(
      txn.account,
      account,
      () => _row(
        id,
        type: body.type.value,
        flow: body.direction?.value == 'in' ? MoneyFlow.inflow : MoneyFlow.outflow,
        amount: txn.amountMinor,
        day: _day(txn.date),
        atMicros: sms.receivedAt.microsecondsSinceEpoch,
        createdMicros: _nowMicros,
        balance: txn.balanceMinor,
      ),
    );
  }

  PersonalTxnIn _entry(
    RawSms sms,
    SmsTxn txn,
    String type,
    MoneyFlow flow,
    String description,
    _Account? account, {
    required bool justIn,
    String? category,
    String? refundOf,
    String? group,
  }) => PersonalTxnIn(
    type: PersonalTxnInTypeEnum.fromJson(type)!,
    amountMinor: txn.amountMinor,
    description: description,
    date: apiDate(txn.date),
    categoryId: category,
    channel: PersonalTxnInChannelEnum.fromJson(txn.channel),
    merchant: txn.merchant,
    account: txn.account,
    accountId: account?.id,
    direction: PersonalTxnInDirectionEnum.fromJson(flow.wire),
    transferGroupId: group,
    refundOfId: refundOf,
    reference: txn.reference,
    balanceMinor: txn.balanceMinor,
    smsAt: sms.receivedAt.toUtc(),
    source_: PersonalTxnInSource_Enum.sms,
    reviewed: !justIn,
  );

  /// The category an entry read from an SMS gets, if suggestions are on.
  String? _guess(String description, String? merchant, {required bool income}) {
    final categories = input.categories;
    if (!f.suggestCategories || categories == null) return null;
    return personalCategory(categories, description, merchant: merchant, income: income, learn: f.learnCategories);
  }
}

/// Below zero when [a] is the better refund target than [b] (refunds.dart's _prefer).
int _prefer(_Spend a, _Spend b, int amount, String? accountId) {
  if (accountId != null) {
    final aSame = a.accountId == accountId, bSame = b.accountId == accountId;
    if (aSame != bSame) return aSame ? -1 : 1;
  }
  final aExact = a.amount == amount, bExact = b.amount == amount;
  if (aExact != bExact) return aExact ? -1 : 1;
  var c = b.day.compareTo(a.day);
  if (c != 0) return c;
  c = b.atMicros.compareTo(a.atMicros);
  if (c != 0) return c;
  c = b.createdMicros.compareTo(a.createdMicros);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// [d]'s day key (20260924).
int _day(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// An entry as the finance maths reads it, for an opening balance (openingFromFirstReport).
FinEntry _row(
  String id, {
  required String type,
  required MoneyFlow flow,
  required int amount,
  required int day,
  required int atMicros,
  int createdMicros = 0,
  int? balance,
}) => FinEntry({
  'id': id,
  'type': type,
  'direction': flow.wire,
  'amount_minor': amount,
  'currency': '',
  'date': '${day ~/ 10000}-${_two(day ~/ 100 % 100)}-${_two(day % 100)}',
  'created_at': DateTime.fromMicrosecondsSinceEpoch(createdMicros, isUtc: true).toIso8601String(),
  'sms_at': DateTime.fromMicrosecondsSinceEpoch(atMicros, isUtc: true).toIso8601String(),
  'balance_minor': balance,
});

String _two(int n) => n.toString().padLeft(2, '0');

/// Ledger.manualMatch over [manual]: the newest entry made by hand (no label yet) of [type] and
/// [amount] dated within a day of [day], as (id, its day key).
(String, int)? _manualMatch(Map<(String, int), List<(String, int)>> manual, String type, int amount, DateTime day) {
  final target = DateTime(day.year, day.month, day.day);
  for (final (id, entryDay) in manual[(type, amount)] ?? const <(String, int)>[]) {
    if (localDay(entryDay).difference(target).inDays.abs() <= 1) return (id, entryDay);
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
