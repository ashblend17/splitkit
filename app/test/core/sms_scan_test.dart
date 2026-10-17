import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/categorise/category_guesser.dart';
import 'package:splitkit/core/clock.dart';
import 'package:splitkit/core/integrations.dart';
import 'package:splitkit/core/local/ledger.dart';
import 'package:splitkit/core/sms/merchant_names.dart';
import 'package:splitkit/core/sms/sms.dart';
import 'package:splitkit/core/sms/sms_ids.dart';
import 'package:splitkit/core/sms/sms_parser.dart';
import 'package:splitkit/core/sms/sms_scan.dart';
import 'package:splitkit/features/sms/sms_importer.dart' show smsScanInput, runSmsScan, smsScanInlineUpTo;

import '../perf/heavy_data.dart';

/// The pure SMS scan (core/sms/sms_scan.dart) against the importer's per-message reading as it
/// was before it moved there ([_ReferenceRead], a copy of the old `_Read`), on the heavy dataset
/// and on the parser's corpus over the seed.
void main() {
  late HeavyData data;
  late Ledger heavy;
  late List<RawSms> heavySmsList;
  late Ledger seed;
  late List<RawSms> corpus;

  setUpAll(() {
    data = buildHeavyData();
    heavy = Ledger(data.entities);
    heavySmsList = heavySms(data);
    final fixture = jsonDecode(File('test/fixtures/sync/john.json').readAsStringSync()) as Map<String, dynamic>;
    seed = Ledger([
      for (final s in (fixture['snapshots'] as Map).entries)
        for (final e in ((s.value as Map)['entities'] as List).cast<Map<String, dynamic>>())
          LocalEntity(s.key, e['entity'], e['entity_id'], e['version'], (e['data'] as Map).cast()),
    ]);
    final messages = (jsonDecode(File('test/fixtures/sms/corpus.json').readAsStringSync()) as Map)['messages'] as List;
    corpus = [
      for (final m in messages.cast<Map<String, dynamic>>())
        RawSms(address: m['sender'], body: m['body'], receivedAt: DateTime.parse(m['received'])),
    ]..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
  });

  /// The scan's output and the reference's, side by side.
  void same(
    Ledger ledger,
    List<RawSms> messages, {
    Features features = const Features(),
    Set<String> before = const {},
  }) {
    final want = _ReferenceRead(ledger, features, before)..addAll(messages);
    final got = scanSms(smsScanInput(ledger, messages, features, attachedBefore: before));
    expect(_normal(got), want.normal());
  }

  test('reads the heavy SMS set as the importer did', () {
    same(heavy, heavySmsList);
    final out = scanSms(smsScanInput(heavy, heavySmsList, const Features()));
    // It meets every case: new, attached, known.
    expect((out.created.length, out.attached.length, out.known), (1719, 81, 200));
  });

  test('with messages attached before, and other settings', () {
    final attached = scanSms(smsScanInput(heavy, heavySmsList, const Features())).attached;
    same(heavy, heavySmsList, before: {for (final a in attached.take(30)) a.smsId});
    same(heavy, heavySmsList, features: const Features(suggestCategories: false));
    same(heavy, heavySmsList, features: const Features(learnCategories: false, justInBackfillDays: 30));
  });

  test('reads the corpus over the seed as the importer did: skips, ATM, manual entries', () {
    same(seed, corpus);
    same(seed, corpus, features: const Features(countAtmAsSpending: false));
    final out = scanSms(smsScanInput(seed, corpus, const Features()));
    expect(
      out.skipped.map((s) => s.reason).toSet(),
      containsAll([SmsSkip.failed, SmsSkip.refund, SmsSkip.promotional]),
    );
    expect(out.skipped.where((s) => s.reason == SmsSkip.otp || s.reason == SmsSkip.notABank), isEmpty);
    expect(out.last, corpus.last.receivedAt);
  });

  test('gives the same on another isolate', () async {
    final input = smsScanInput(heavy, heavySmsList, const Features());
    final inline = _normal(scanSms(input));
    expect(_normal(await Isolate.run(() => scanSms(input))), inline);
    expect(heavySmsList.length, greaterThan(smsScanInlineUpTo)); // so runSmsScan goes to an isolate
    expect(_normal(await runSmsScan(input)), inline);
  });

  test('nothing to read gives nothing', () {
    final out = scanSms(smsScanInput(heavy, const [], const Features()));
    expect([...out.created, ...out.attached, ...out.skipped], isEmpty);
    expect((out.known, out.last), (0, null));
  });
}

/// A scan's output as plain JSON, to compare.
Object _normal(SmsScanResult r) => jsonDecode(
  jsonEncode({
    'created': [
      for (final (id, body) in r.created) [id, body.toJson()],
    ],
    'attached': [
      for (final a in r.attached) [a.entryId, a.merchant, a.account, a.channel, a.smsId],
    ],
    'skipped': [
      for (final s in r.skipped) [s.sms.toJson(), s.reason.name],
    ],
    'bodies': r.bodies,
    'known': r.known,
  }),
);

/// The importer's `_Read` as it was before the scan moved to core/sms/sms_scan.dart, word for
/// word apart from how it's given its input: what the scan must keep doing.
class _ReferenceRead {
  _ReferenceRead(this.ledger, this.features, this._attachedBefore) : _references = ledger.personalReferences();

  final Ledger ledger;
  final Features features;
  final Set<String> _attachedBefore;
  final Set<String> _references;
  final _ids = <String>{};

  final created = <(String, PersonalTxnIn)>[];

  /// The entry, what the message said, and the message's id.
  final attached = <(PersonalTxnOut, SmsTxn, String)>[];
  final skipped = <({RawSms sms, SmsSkip reason})>[];
  final bodies = <String, Object?>{};
  var known = 0;

  void addAll(List<RawSms> messages) => messages.forEach(add);

  void add(RawSms sms) {
    switch (parseSms(sms)) {
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
    bodies['sms.body.$id'] = sms.toJson();
  }

  Object normal() => jsonDecode(
    jsonEncode({
      'created': [
        for (final (id, body) in created) [id, body.toJson()],
      ],
      'attached': [
        for (final (out, txn, id) in attached) [out.id, txn.merchant, txn.account, txn.channel, id],
      ],
      'skipped': [
        for (final s in skipped) [s.sms.toJson(), s.reason.name],
      ],
      'bodies': {for (final MapEntry(:key, :value) in bodies.entries) key.substring('sms.body.'.length): value},
      'known': known,
    }),
  );
}
