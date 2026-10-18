import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/api/api.dart';
import 'package:splitkit/core/finance/finance.dart';
import 'package:splitkit/core/local/ledger.dart';
import 'package:splitkit/core/local/outbox.dart';
import 'package:splitkit/core/local/providers.dart';
import 'package:splitkit/core/local/writes.dart';

import '../fake_backend.dart';

// The personal ledger's writes (core/local/writes_finance.dart) against the seed's sync snapshot,
// offline, so every write stays queued and the test reads what it would send and what it shows.

const pizza = '59424173-0ad9-5fbf-9866-2a081d44a28d'; // Late-night pizza, Goa, ₹1,140, John paid

Ledger _ledger(WidgetTester tester) => appContainer(tester).read(localStoreProvider).value!.ledger;
LocalWrites _writes(WidgetTester tester) => appContainer(tester).read(writesProvider);
List<OutboxOp> _ops(WidgetTester tester) => appContainer(tester).read(outboxProvider);

String _account(Ledger l, String name) => l.personalAccountList().firstWhere((a) => a['name'] == name)['id'] as String;

Json _entry(Ledger l, String description) =>
    (l.personalList(limit: 1 << 20)['items'] as List).cast<Json>().firstWhere((t) => t['description'] == description);

/// A transfer's legs in the seed, out first.
(Json, Json) _legs(Ledger l, String description) {
  final legs = [
    for (final t in (l.personalList(type: 'transfer', limit: 1 << 20)['items'] as List).cast<Json>())
      if (t['description'] == description) t,
  ];
  return legs[0]['direction'] == 'out' ? (legs[0], legs[1]) : (legs[1], legs[0]);
}

List<Json> _items(OutboxOp op) {
  // The request parses as the generated client's model, so its shape can't drift from the API's.
  final parsed = PersonalMixedBatchIn.fromJson(op.body);
  expect(parsed, isNotNull);
  expect(parsed!.items.length, (op.body!['items'] as List).length);
  return (op.body!['items'] as List).cast<Json>();
}

Json _txn(Json item) => (item['transaction'] as Map).cast<String, dynamic>();

LocalEntity _entity(OutboxOp op, String id) => op.entities.firstWhere((e) => e.entityId == id);

/// [write] is refused before anything is queued, with the server's [code] (and [message]).
Future<void> _expectRefused(WidgetTester tester, Future<Object?> write, String code, [Object? message]) async {
  final queued = _ops(tester).length;
  Object? error;
  try {
    await runWrite(tester, write);
  } catch (e) {
    error = e;
  }
  expect(
    error,
    isA<WriteRefused>().having(apiErrorCode, 'code', code).having(apiErrorMessage, 'message', message ?? anything),
  );
  expect(_ops(tester).length, queued);
}

PersonalTxnIn _sms(String description, int amount, {String type = 'expense', String? accountId, String? label}) =>
    PersonalTxnIn(
      type: PersonalTxnInTypeEnum.fromJson(type)!,
      amountMinor: amount,
      description: description,
      date: DateTime.utc(2026, 9, 24),
      accountId: accountId,
      account: label,
      source_: PersonalTxnInSource_Enum.sms,
      reviewed: false,
    );

/// The seed without its allocation rules: these incomes get no plans, and Emergency savings can be
/// closed (plan_writes_test.dart covers both with the rules).
Future<FakeBackend> _offline(WidgetTester tester) async {
  final be = await pumpApp(tester, backend: FakeBackend().withoutAllocationRules());
  be.offline = true;
  return be;
}

void main() {
  test('personalBody keeps the account, the direction and the links', () {
    final item = Map<String, dynamic>.of(((fixture('personal_list') as Map)['items'][0] as Map).cast())
      ..addAll({
        'type': 'transfer',
        'direction': 'in',
        'account_id': 'a0000000-0000-4000-8000-000000000001',
        'transfer_group_id': 'a0000000-0000-4000-8000-000000000002',
        'refund_of_id': 'a0000000-0000-4000-8000-000000000003',
        'holding_id': 'a0000000-0000-4000-8000-000000000004',
      });
    final body = personalBody(PersonalTxnOut.fromJson(item)!).toJson();
    expect(
      (
        body['direction'].toString(),
        body['account_id'],
        body['transfer_group_id'],
        body['refund_of_id'],
        body['holding_id'],
      ),
      (
        'in',
        'a0000000-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000002',
        'a0000000-0000-4000-8000-000000000003',
        'a0000000-0000-4000-8000-000000000004',
      ),
    );
  });

  testWidgets('every edit made from an entry keeps its account and links (ISS-090)', (tester) async {
    final be = await _offline(tester);
    final l = _ledger(tester);
    final w = _writes(tester);
    final hdfc = _account(l, 'HDFC ··4821');
    final swiggy = _entry(l, 'Swiggy order');
    expect(swiggy['account_id'], hdfc);

    Json sent() => _ops(tester).last.body!;

    // Looks right.
    await runWrite(tester, w.reviewPersonal(swiggy['id']));
    expect((sent()['account_id'], sent()['direction']), (hdfc, 'out'));
    // A category change.
    final shopping = l.categories(scope: 'personal').firstWhere((c) => c['key'] == 'shopping')['id'];
    await runWrite(
      tester,
      w.updatePersonal(
        swiggy['id'],
        personalBody(PersonalTxnOut.fromJson(_ledger(tester).personalTransaction(swiggy['id']))!)
          ..categoryId = shopping,
      ),
    );
    expect((sent()['account_id'], sent()['category_id']), (hdfc, shopping));
    // Already split, and unlinking it.
    await runWrite(tester, w.linkPersonal(swiggy['id'], expenseId: pizza));
    expect((sent()['account_id'], sent()['expense_id']), (hdfc, pizza));
    await runWrite(tester, w.linkPersonal(swiggy['id']));
    expect((sent()['account_id'], sent()['expense_id']), (hdfc, null));
    // Split it.
    final e = fixture('expense') as Map;
    await runWrite(
      tester,
      w.splitPersonal(
        swiggy['id'],
        be.goa['id'],
        ExpenseIn(
          description: 'Swiggy order',
          amountMinor: 48600,
          payerId: (e['payer'] as Map)['id'],
          date: DateTime.utc(2026, 9, 23),
          split: SplitIn(
            method: 'equal',
            inputs: [for (final s in e['splits'] as List) SplitInputIn(userId: s['user']['id'])],
          ),
        ),
      ),
    );
    expect(sent()['account_id'], hdfc);
    expect(sent()['expense_id'], isNotNull);
    // An SMS attached to the entry.
    final rapido = _entry(_ledger(tester), 'Rapido ride');
    await runWrite(
      tester,
      w.importUnits([
        [
          BatchItem.updateEntry(
            rapido['id'] as String,
            personalBody(PersonalTxnOut.fromJson(rapido)!)..reviewed = false,
          ),
        ],
      ]),
    );
    expect(_txn(_items(_ops(tester).last).single)['account_id'], hdfc);
    // A transfer leg and a refund keep theirs.
    final (out, _) = _legs(_ledger(tester), 'Credit card bill');
    await runWrite(tester, w.reviewPersonal(out['id']));
    expect(
      (sent()['type'], sent()['direction'], sent()['transfer_group_id'], sent()['account_id']),
      ('transfer', 'out', out['transfer_group_id'], hdfc),
    );
    final refund = _entry(_ledger(tester), 'Price drop refund');
    await runWrite(tester, w.reviewPersonal(refund['id']));
    expect((sent()['type'], sent()['refund_of_id']), ('refund', refund['refund_of_id']));
  });

  testWidgets('a transfer is one request to /personal/batch with two legs sharing a group', (tester) async {
    await _offline(tester);
    final l = _ledger(tester);
    final hdfc = _account(l, 'HDFC ··4821'), savings = _account(l, 'Emergency savings');
    final (hdfcBefore, savingsBefore) = (
      l.finance.balanceOf(hdfc)!.balanceMinor,
      l.finance.balanceOf(savings)!.balanceMinor,
    );

    final group = await runWrite(
      tester,
      _writes(tester).createTransfer(
        fromAccountId: hdfc,
        toAccountId: savings,
        amountMinor: 500000,
        date: DateTime(2026, 9, 24),
        description: 'To savings',
        channel: 'bank',
      ),
    );
    final op = _ops(tester).single;
    expect((op.method, op.path), ('POST', '/api/v1/personal/batch'));
    final items = _items(op);
    expect(
      [for (final i in items) (i['kind'], i['op'], i['version'])],
      [('transaction', 'create', null), ('transaction', 'create', null)],
    );
    expect(
      [
        for (final i in items)
          (_txn(i)['type'], _txn(i)['direction'], _txn(i)['account_id'], _txn(i)['transfer_group_id']),
      ],
      [('transfer', 'out', hdfc, group), ('transfer', 'in', savings, group)],
    );
    expect(
      [for (final e in op.entities) (e.entity, e.version, e.data['transfer_group_id'], e.data['channel'])],
      [('personal_transaction', 1, group, 'bank'), ('personal_transaction', 1, group, 'bank')],
    );
    expect(op.entities.map((e) => e.entityId), items.map((i) => i['id']));

    // Shown at once: the money moved, and it's neither spending nor income.
    final now = _ledger(tester);
    expect(now.finance.balanceOf(hdfc)!.balanceMinor, hdfcBefore - 500000);
    expect(now.finance.balanceOf(savings)!.balanceMinor, savingsBefore + 500000);
    expect(now.personalSummary(DateTime(2026, 9))['spent_minor'], l.personalSummary(DateTime(2026, 9))['spent_minor']);

    // What the server would refuse is refused before anything is queued.
    final w = _writes(tester);
    Future<String> transfer({String? to, int amount = 1000}) => w.createTransfer(
      fromAccountId: hdfc,
      toAccountId: to ?? savings,
      amountMinor: amount,
      date: DateTime(2026, 9, 24),
      description: 'Move',
    );
    await _expectRefused(
      tester,
      transfer(to: hdfc),
      'transfer_invalid',
      'A transfer moves money between two different accounts',
    );
    await _expectRefused(tester, transfer(amount: 0), 'invalid_input', 'Enter an amount above zero');
    await runWrite(tester, w.closeAccount(savings));
    await _expectRefused(tester, transfer(), 'account_closed', 'That account is closed');
    expect(_ops(tester).length, 2);
  });

  testWidgets('a lone leg, or an edit to one leg\'s amount, is refused as the server refuses it', (tester) async {
    await _offline(tester);
    final l = _ledger(tester);
    final w = _writes(tester);
    await _expectRefused(
      tester,
      w.createPersonal(
        _sms('Half', 1000, type: 'transfer', accountId: _account(l, 'Cash'))
          ..direction = PersonalTxnInDirectionEnum.in_
          ..transferGroupId = 'a0000000-0000-4000-8000-000000000009',
      ),
      'transfer_unpaired',
    );
    final (out, into) = _legs(l, 'Cash withdrawal');
    await _expectRefused(
      tester,
      w.updatePersonal(out['id'], personalBody(PersonalTxnOut.fromJson(out)!)..amountMinor = 1),
      'transfer_invalid',
      'Both halves of a transfer must be the same amount',
    );
    await _expectRefused(
      tester,
      w.updatePersonal(
        out['id'],
        personalBody(PersonalTxnOut.fromJson(out)!)..transferGroupId = 'a0000000-0000-4000-8000-000000000010',
      ),
      'transfer_unpaired',
      'Change both halves of a transfer together',
    );
    // Its description alone is fine; both legs together are too.
    await runWrite(
      tester,
      w.updatePersonal(out['id'], personalBody(PersonalTxnOut.fromJson(out)!)..description = 'ATM'),
    );
    await runWrite(
      tester,
      w.updateTransfer(out['transfer_group_id'], amountMinor: 250000, date: DateTime(2026, 9, 13)),
    );
    final op = _ops(tester).last;
    final items = _items(op);
    expect(
      [for (final i in items) (i['op'], i['id'], i['version'], _txn(i)['amount_minor'], _txn(i)['date'])],
      [('update', out['id'], 2, 250000, '2026-09-13'), ('update', into['id'], 1, 250000, '2026-09-13')],
    );
    expect([for (final e in op.entities) e.version], [3, 2]);
    expect(_txn(items[0])['description'], 'ATM');
  });

  testWidgets('deleting a transfer deletes both legs at once; restoring either brings both back', (tester) async {
    await _offline(tester);
    final (out, into) = _legs(_ledger(tester), 'Cash withdrawal');
    final w = _writes(tester);

    // The cash leg went into the Ladakh trip's jar: that contribution goes and comes back with it.
    final jar = _ledger(tester).rawContributionsOf(entryId: into['id']).single['id'];
    await runWrite(tester, w.deleteTransfer(out['transfer_group_id']));
    var op = _ops(tester).single;
    expect((op.method, op.path, op.query['version']), ('DELETE', '/api/v1/personal/transactions/${out['id']}', '1'));
    expect([for (final e in op.entities) (e.entityId, e.version)], [(out['id'], 2), (into['id'], 2), (jar, 2)]);
    expect(op.entities[0].data['deleted_at'], isNotNull);
    expect(op.entities[1].data['deleted_at'], op.entities[0].data['deleted_at']);
    expect(op.entities[2].data['deleted_at'], op.entities[0].data['deleted_at']);
    var l = _ledger(tester);
    expect([
      l.rawPersonal(out['id'])!['deleted_at'],
      l.rawPersonal(into['id'])!['deleted_at'],
    ], everyElement(isNotNull));

    // Undo from either leg.
    await runWrite(tester, w.restorePersonal(into['id']));
    op = _ops(tester).last;
    expect(
      (op.method, op.path, op.query['version']),
      ('POST', '/api/v1/personal/transactions/${into['id']}/restore', '2'),
    );
    expect(
      [for (final e in op.entities) (e.entityId, e.version, e.data['deleted_at'])],
      [(into['id'], 3, null), (jar, 3, null), (out['id'], 3, null)],
    );
    l = _ledger(tester);
    expect(l.finance.partnerLeg(out['id'])?.id, into['id']);
  });

  testWidgets('pairing a spend and an income as a transfer, then unpairing it', (tester) async {
    await _offline(tester);
    var l = _ledger(tester);
    final w = _writes(tester);
    final hdfc = _account(l, 'HDFC ··4821'), savings = _account(l, 'Emergency savings');
    final spend = await runWrite(tester, w.createPersonal(_sms('Sent to savings', 300000, accountId: hdfc)));
    final income = await runWrite(
      tester,
      w.createPersonal(_sms('From HDFC', 300000, type: 'income', accountId: savings)..categoryId = null),
    );
    final other = await runWrite(
      tester,
      w.createPersonal(_sms('Odd amount', 299999, type: 'income', accountId: savings)),
    );
    await _expectRefused(
      tester,
      w.pairAsTransfer(spend, other),
      'transfer_invalid',
      'Both halves of a transfer must be the same amount',
    );
    await _expectRefused(
      tester,
      w.pairAsTransfer(income, spend),
      'transfer_invalid',
      'One half goes out and the other comes in',
    );

    final group = await runWrite(tester, w.pairAsTransfer(spend, income));
    expect(group, transferGroupIdFor(spend, income));
    var op = _ops(tester).last;
    expect(
      [for (final i in _items(op)) (i['op'], i['id'], i['version'], _txn(i)['type'], _txn(i)['direction'])],
      [('update', spend, 1, 'transfer', 'out'), ('update', income, 1, 'transfer', 'in')],
    );
    expect([
      for (final i in _items(op)) (_txn(i)['category_id'], _txn(i)['transfer_group_id']),
    ], everyElement((null, group)));
    l = _ledger(tester);
    expect(l.finance.partnerLeg(spend)?.id, income);

    // Both legs came from SMS: both are a spend and an income again, in one request.
    await runWrite(tester, w.unpairTransfer(group, keepId: spend));
    op = _ops(tester).last;
    expect(
      [for (final i in _items(op)) (i['op'], i['id'], i['version'], _txn(i)['type'], _txn(i)['transfer_group_id'])],
      [('update', spend, 2, 'expense', null), ('update', income, 2, 'income', null)],
    );
    l = _ledger(tester);
    expect([l.rawPersonal(spend)!['type'], l.rawPersonal(income)!['type']], ['expense', 'income']);
  });

  testWidgets('unpairing deletes a leg the app made, in the same request', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    var l = _ledger(tester);

    // Made by hand: the kept leg becomes a spend, the other is deleted (after, so it goes alone).
    final (out, into) = _legs(l, 'Cash withdrawal');
    await runWrite(tester, w.unpairTransfer(out['transfer_group_id'], keepId: out['id']));
    var op = _ops(tester).last;
    expect(
      [for (final i in _items(op)) (i['op'], i['id'], i['version'])],
      [('update', out['id'], 1), ('delete', into['id'], 1)],
    );
    expect(_items(op)[1]['transaction'], isNull);
    expect(
      [for (final e in op.entities) (e.entityId, e.version, e.data['type'], e.data['deleted_at'] != null)],
      [
        (out['id'], 2, 'expense', false),
        (into['id'], 2, 'transfer', true),
        // The Ladakh trip's jar contribution goes with the deleted leg.
        (l.rawContributionsOf(entryId: into['id']).single['id'], 2, null, true),
      ],
    );

    // Read from an SMS, with the cash half the app made for it (pairedLegId): that half goes.
    final hdfc = _account(l, 'HDFC ··4821'), cash = _account(l, 'Cash');
    const atm = 'a0000000-0000-5000-8000-0000000000a1';
    final group = transferGroupIdFor(atm);
    await runWrite(
      tester,
      w.importUnits([
        [
          BatchItem.createEntry(
            atm,
            _sms('Cash withdrawal', 100000, type: 'transfer', accountId: hdfc)
              ..direction = PersonalTxnInDirectionEnum.out_
              ..transferGroupId = group,
          ),
          BatchItem.createEntry(
            pairedLegId(atm),
            _sms('Cash withdrawal', 100000, type: 'transfer', accountId: cash)
              ..direction = PersonalTxnInDirectionEnum.in_
              ..transferGroupId = group,
          ),
        ],
      ]),
    );
    await runWrite(tester, w.unpairTransfer(group, keepId: atm));
    op = _ops(tester).last;
    expect([for (final i in _items(op)) (i['op'], i['id'])], [('update', atm), ('delete', pairedLegId(atm))]);
    l = _ledger(tester);
    expect(l.rawPersonal(atm)!['type'], 'expense');
    expect(l.rawPersonal(pairedLegId(atm))!['deleted_at'], isNotNull);
  });

  testWidgets('converting an entry: the new leg is pairedLegId(entry), the group transferGroupIdFor(entry)', (
    tester,
  ) async {
    await _offline(tester);
    var l = _ledger(tester);
    final w = _writes(tester);
    final hdfc = _account(l, 'HDFC ··4821'), cash = _account(l, 'Cash');
    final rapido = _entry(l, 'Rapido ride');
    expect(rapido['account_id'], hdfc);
    expect(rapido['category'], isNotNull);

    final group = await runWrite(tester, w.convertToTransfer(rapido['id'], otherAccountId: cash));
    expect(group, transferGroupIdFor(rapido['id']));
    var items = _items(_ops(tester).last);
    expect(
      [for (final i in items) (i['op'], i['id'], i['version'])],
      [('update', rapido['id'], 1), ('create', pairedLegId(rapido['id']), null)],
    );
    expect(
      [for (final i in items) (_txn(i)['type'], _txn(i)['direction'], _txn(i)['account_id'], _txn(i)['category_id'])],
      [('transfer', 'out', hdfc, null), ('transfer', 'in', cash, null)],
    );
    expect([
      for (final i in items) (_txn(i)['amount_minor'], _txn(i)['transfer_group_id']),
    ], everyElement((40000, group)));

    // Unpaired (the cash leg is deleted) and converted again: those ids are taken, so fresh ones.
    await runWrite(tester, w.unpairTransfer(group, keepId: rapido['id']));
    final again = await runWrite(tester, w.convertToTransfer(rapido['id'], otherAccountId: cash));
    items = _items(_ops(tester).last);
    final leg = items[1]['id'] as String;
    expect(leg, isNot(pairedLegId(rapido['id'])));
    expect(again, transferGroupIdFor(rapido['id'], leg));
    expect(items[0]['version'], 3);

    // What can't become a transfer.
    l = _ledger(tester);
    await _expectRefused(
      tester,
      w.convertToTransfer(_entry(l, 'Uber to airport')['id'], otherAccountId: cash),
      'link_invalid',
      'Only spending and income can be linked to Split',
    );
    await _expectRefused(
      tester,
      w.convertToTransfer(_entry(l, 'House rent')['id'], otherAccountId: cash),
      'transfer_invalid',
      'A transfer needs an account on each side',
    );
  });

  testWidgets('a cash withdrawal goes to your Cash account, or to one made in the same request', (tester) async {
    await _offline(tester);
    var l = _ledger(tester);
    final w = _writes(tester);
    final cash = _account(l, 'Cash');
    final rapido = _entry(l, 'Rapido ride')['id'] as String;

    await runWrite(tester, w.trackCash(rapido));
    var items = _items(_ops(tester).last);
    expect(
      [for (final i in items) (i['kind'], i['op'], i['id'])],
      [('transaction', 'update', rapido), ('transaction', 'create', pairedLegId(rapido))],
    );
    expect(_txn(items[1])['account_id'], cash);

    // No open Cash account: one is made first, and the cash leg goes into it.
    await runWrite(tester, w.closeAccount(cash));
    final swiggy = _entry(_ledger(tester), 'Swiggy order')['id'] as String;
    await runWrite(tester, w.trackCash(swiggy));
    final op = _ops(tester).last;
    items = _items(op);
    expect(
      [for (final i in items) (i['kind'], i['op'])],
      [('account', 'create'), ('transaction', 'update'), ('transaction', 'create')],
    );
    final made = items[0]['id'];
    expect(((items[0]['account'] as Map)['name'], (items[0]['account'] as Map)['type']), ('Cash', 'cash'));
    expect((_txn(items[2])['account_id'], _txn(items[2])['direction']), (made, 'in'));
    expect(_entity(op, made).data['status'], 'active');
    l = _ledger(tester);
    expect(l.finance.firstActiveCash()?.id, made);
    expect(l.finance.balanceOf(made)!.balanceMinor, 48600);
  });

  testWidgets('Reconcile: an asset and a liability, at a report or now, and nothing with no gap', (tester) async {
    await _offline(tester);
    var l = _ledger(tester);
    final w = _writes(tester);
    final hdfc = _account(l, 'HDFC ··4821'), card = _account(l, 'ICICI Credit card ··9012');

    // At the balance the bank last reported: dated that day, measured there.
    final report = l.finance.balanceOf(hdfc)!.lastReported!;
    await runWrite(tester, w.reconcile(hdfc, bankSaysMinor: report.derivedMinor + 7000, checkpointDay: report.day));
    var op = _ops(tester).last;
    expect((op.method, op.path), ('POST', '/api/v1/personal/transactions'));
    final day =
        '${report.day ~/ 10000}-${'${report.day ~/ 100 % 100}'.padLeft(2, '0')}-${'${report.day % 100}'.padLeft(2, '0')}';
    expect(
      (op.body!['type'], op.body!['direction'], op.body!['amount_minor'], op.body!['account_id'], op.body!['date']),
      ('adjustment', 'in', 7000, hdfc, day),
    );
    expect(op.body!['category_id'], isNull);
    l = _ledger(tester);
    expect(l.finance.balanceOf(hdfc)!.lastReported!.derivedMinor, report.derivedMinor + 7000);

    // An asset now: more money than the entries say is money in, less is money out.
    final balance = l.finance.balanceOf(hdfc)!.balanceMinor;
    await runWrite(tester, w.reconcile(hdfc, bankSaysMinor: balance - 2000));
    op = _ops(tester).last;
    expect((op.body!['direction'], op.body!['amount_minor'], op.body!['date']), ('out', 2000, '2026-09-25'));
    expect(_ledger(tester).finance.balanceOf(hdfc)!.balanceMinor, balance - 2000);

    // A card: owing more is money out of it, owing less is money in.
    final owed = _ledger(tester).finance.balanceOf(card)!.balanceMinor;
    await runWrite(tester, w.reconcile(card, bankSaysMinor: owed + 1000));
    expect((_ops(tester).last.body!['direction'], _ops(tester).last.body!['amount_minor']), ('out', 1000));
    await runWrite(tester, w.reconcile(card, bankSaysMinor: owed - 500));
    expect((_ops(tester).last.body!['direction'], _ops(tester).last.body!['amount_minor']), ('in', 1500));
    expect(_ledger(tester).finance.balanceOf(card)!.balanceMinor, owed - 500);

    // No gap: nothing to record.
    final count = _ops(tester).length;
    expect(await runWrite(tester, w.reconcile(card, bankSaysMinor: owed - 500)), isNull);
    expect(_ops(tester).length, count);
  });

  testWidgets('closing an account, at zero first: one request, the correction then the account', (tester) async {
    await _offline(tester);
    var l = _ledger(tester);
    final w = _writes(tester);
    final cash = _account(l, 'Cash'), savings = _account(l, 'Emergency savings');
    final balance = l.finance.balanceOf(cash)!.balanceMinor;
    expect(balance, greaterThan(0));

    await runWrite(tester, w.closeAccount(cash, zeroFirst: true));
    var op = _ops(tester).last;
    final items = _items(op);
    expect(
      [for (final i in items) (i['kind'], i['op'], i['version'])],
      [('transaction', 'create', null), ('account', 'update', 1)],
    );
    expect(
      (_txn(items[0])['type'], _txn(items[0])['direction'], _txn(items[0])['amount_minor']),
      ('adjustment', 'out', balance),
    );
    expect((items[1]['account'] as Map)['status'], 'closed');
    expect((_entity(op, cash).version, _entity(op, cash).data['status']), (2, 'closed'));
    l = _ledger(tester);
    expect(l.finance.balanceOf(cash)!.balanceMinor, 0);

    // Without: a PUT of the account as it is, closed. Reopening is the same.
    await runWrite(tester, w.closeAccount(savings));
    op = _ops(tester).last;
    expect(
      (op.method, op.path, op.body!['status'], op.body!['version'], op.body!['name']),
      ('PUT', '/api/v1/personal/accounts/$savings', 'closed', 1, 'Emergency savings'),
    );
    await runWrite(tester, w.reopenAccount(savings));
    expect((_ops(tester).last.body!['status'], _ops(tester).last.body!['version']), ('active', 2));
  });

  testWidgets('an account with a label takes in your entries with that label and no account', (tester) async {
    await _offline(tester);
    final w = _writes(tester);
    const label = 'SBI ··1111';
    final live = await runWrite(tester, w.createPersonal(_sms('Chai', 2000, label: label)));
    final gone = await runWrite(tester, w.createPersonal(_sms('Snacks', 3000, label: label)));
    await runWrite(tester, w.deletePersonal(gone));
    final elsewhere = await runWrite(tester, w.createPersonal(_sms('Fuel', 4000, label: 'SBI ··2222')));

    final id = await runWrite(tester, w.createAccount(name: 'SBI', type: AccountType.bank, smsLabel: label));
    final op = _ops(tester).last;
    expect(
      (op.method, op.path, op.body!['id'], op.body!['sms_label']),
      ('POST', '/api/v1/personal/accounts', id, label),
    );
    expect(PersonalAccountIn.fromJson(op.body), isNotNull);
    expect(
      [for (final e in op.entities) (e.entity, e.entityId, e.version)],
      [('personal_account', id, 1), ('personal_transaction', live, 2), ('personal_transaction', gone, 3)],
    );
    final l = _ledger(tester);
    expect([l.rawPersonal(live)!['account_id'], l.rawPersonal(gone)!['account_id']], [id, id]);
    expect(l.rawPersonal(elsewhere)!['account_id'], isNull);
    expect(l.rawAccount(id)!['currency'], 'INR');

    // One account per label, deleted ones included.
    await _expectRefused(
      tester,
      w.createAccount(name: 'HDFC again', type: AccountType.bank, smsLabel: 'HDFC ··4821'),
      'label_taken',
      'HDFC ··4821 already has that label',
    );
    // Relabelling takes in the new label's entries.
    await runWrite(tester, w.updateAccount(id, smsLabel: 'SBI ··2222'));
    final edit = _ops(tester).last;
    expect((edit.method, edit.body!['sms_label'], edit.body!['version']), ('PUT', 'SBI ··2222', 1));
    expect([for (final e in edit.entities) (e.entityId, e.version)], [(id, 2), (elsewhere, 2)]);
    // Nothing changed, nothing queued.
    final count = _ops(tester).length;
    await runWrite(tester, w.updateAccount(id, name: 'SBI'));
    expect(_ops(tester).length, count);
  });

  testWidgets('deleting an account: refused while entries use it; restore brings it back', (tester) async {
    await _offline(tester);
    final l = _ledger(tester);
    final w = _writes(tester);
    await _expectRefused(
      tester,
      w.deleteAccount(_account(l, 'HDFC ··4821')),
      'account_in_use',
      "This account has entries, so it can't be deleted. Close it instead",
    );
    final zerodha = _account(l, 'Zerodha');
    // Its holdings go first, the SIP that names one before them (holding_writes_test.dart).
    await runWrite(tester, w.deletePersonal(_entry(l, 'Index fund SIP')['id'] as String));
    for (final h in l.finance.holdings) {
      await runWrite(tester, w.deleteHolding(h.id));
    }
    await runWrite(tester, w.deleteAccount(zerodha));
    var op = _ops(tester).last;
    expect((op.method, op.path, op.query['version']), ('DELETE', '/api/v1/personal/accounts/$zerodha', '1'));
    expect(_ledger(tester).personalAccountList().map((a) => a['name']), isNot(contains('Zerodha')));
    await runWrite(tester, w.restoreAccount(zerodha));
    op = _ops(tester).last;
    expect((op.method, op.path, op.query['version']), ('POST', '/api/v1/personal/accounts/$zerodha/restore', '2'));
    expect(_ledger(tester).personalAccountList().map((a) => a['name']), contains('Zerodha'));
  });

  testWidgets('a refund takes the spend\'s account and category, and never more than is left', (tester) async {
    await _offline(tester);
    final l = _ledger(tester);
    final w = _writes(tester);
    final coffee = _entry(l, 'Blue Tokai coffee');
    expect(coffee['account_id'], _account(l, 'ICICI Credit card ··9012'));

    await runWrite(
      tester,
      w.recordRefund(
        amountMinor: 10000,
        date: DateTime(2026, 9, 24),
        description: 'Coffee refund',
        refundOfId: coffee['id'],
      ),
    );
    final op = _ops(tester).last;
    expect((op.method, op.path), ('POST', '/api/v1/personal/transactions'));
    expect((op.body!['type'], op.body!['refund_of_id']), ('refund', coffee['id']));
    expect(op.entities.single.data['direction'], 'in');
    expect(
      (op.body!['account_id'], op.body!['category_id']),
      (coffee['account_id'], (coffee['category'] as Map)['id']),
    );
    expect(op.entities.map((e) => e.entity), ['personal_transaction'], reason: 'a refund teaches no category');

    // ₹1,490 of the headphones were refunded already: ₹7,000 is left.
    final headphones = _entry(l, 'New headphones')['id'];
    await _expectRefused(
      tester,
      w.recordRefund(amountMinor: 700001, date: DateTime(2026, 9, 24), description: 'More', refundOfId: headphones),
      'refund_too_large',
      'Only ₹7,000 of this spend is left to refund',
    );
    await _expectRefused(
      tester,
      w.recordRefund(amountMinor: 900000, date: DateTime(2026, 9, 24), description: 'More', refundOfId: headphones),
      'refund_too_large',
      "A refund can't be more than the spend",
    );
    await runWrite(
      tester,
      w.recordRefund(amountMinor: 700000, date: DateTime(2026, 9, 24), description: 'Rest', refundOfId: headphones),
    );
    expect(_ops(tester).last.body!['account_id'], isNull);
    await _expectRefused(
      tester,
      w.recordRefund(
        amountMinor: 100,
        date: DateTime(2026, 9, 24),
        description: 'Of income?',
        refundOfId: _entry(l, 'Salary')['id'],
      ),
      'unknown_refund_target',
      "That spend isn't available",
    );
  });

  testWidgets('the importer\'s requests: accounts first, units whole, at most a chunk each, one rebuild', (
    tester,
  ) async {
    await _offline(tester);
    final l = _ledger(tester);
    final w = _writes(tester);
    final hdfc = _account(l, 'HDFC ··4821'), cash = _account(l, 'Cash');
    final rapido = _entry(l, 'Rapido ride')['id'] as String;
    String id(int n) => 'b0000000-0000-5000-8000-${'$n'.padLeft(12, '0')}';
    final axis = smsAccountId(l.me, 'Axis ··2222');
    PersonalTxnIn leg(String accountId, PersonalTxnInDirectionEnum direction, String group) =>
        _sms('Own transfer', 5000, type: 'transfer', accountId: accountId)
          ..direction = direction
          ..transferGroupId = group;
    final units = [
      [BatchItem.createEntry(id(1), _sms('One', 100, accountId: hdfc))],
      [
        BatchItem.createEntry(id(2), leg(hdfc, PersonalTxnInDirectionEnum.out_, transferGroupIdFor(id(2)))),
        BatchItem.createEntry(id(3), leg(cash, PersonalTxnInDirectionEnum.in_, transferGroupIdFor(id(2)))),
      ],
      [BatchItem.createEntry(id(4), _sms('Two', 200, accountId: hdfc))],
      [
        BatchItem.updateEntry(
          rapido,
          personalBody(PersonalTxnOut.fromJson(l.personalTransaction(rapido))!)
            ..type = PersonalTxnInTypeEnum.transfer
            ..categoryId = null
            ..transferGroupId = transferGroupIdFor(rapido),
        ),
        BatchItem.createEntry(
          pairedLegId(rapido),
          _sms('Rapido ride', 40000, type: 'transfer', accountId: cash)
            ..direction = PersonalTxnInDirectionEnum.in_
            ..transferGroupId = transferGroupIdFor(rapido),
        ),
      ],
      [BatchItem.createEntry(id(5), _sms('On the new card', 300, accountId: axis))],
      // Last in, first out: accounts go first.
      [
        BatchItem.createAccount(
          axis,
          PersonalAccountIn(name: 'Axis ··2222', type: PersonalAccountInTypeEnum.bank, smsLabel: 'Axis ··2222'),
        ),
      ],
    ];

    final store = appContainer(tester).read(localStoreProvider).value!;
    store.ledger; // built, so the count starts from here
    final builds = store.ledgerBuilds;
    await runWrite(tester, w.importUnits(units, chunk: 3));
    expect(store.ledgerBuilds - builds, 1);

    final ops = _ops(tester);
    final sent = [for (final op in ops) _items(op).map((i) => i['id']).toList()];
    expect(sent, [
      [axis, id(1)],
      [id(2), id(3), id(4)],
      [rapido, pairedLegId(rapido), id(5)],
    ]);
    expect(ops.every((op) => op.path == '/api/v1/personal/batch'), isTrue);
    expect(
      [for (final op in ops) op.label],
      ['Added 1 entry and 1 account from bank SMS', 'Added 3 entries from bank SMS', 'Added 2 entries from bank SMS'],
    );
    // Each request's entities: everything it changes, at the version it leaves.
    expect(
      [for (final e in ops[2].entities) (e.entityId, e.version)],
      [(rapido, 2), (pairedLegId(rapido), 1), (id(5), 1)],
    );
    expect(_ledger(tester).finance.balanceOf(axis)!.balanceMinor, -300);

    // A unit that would be refused stops the whole import before anything is queued.
    await _expectRefused(
      tester,
      w.importUnits([
        [BatchItem.createEntry(id(6), _sms('Fine', 100, accountId: hdfc))],
        [BatchItem.createEntry(id(7), leg(hdfc, PersonalTxnInDirectionEnum.out_, transferGroupIdFor(id(7))))],
      ]),
      'transfer_unpaired',
    );
    expect(_ops(tester).length, 3);
  });

  testWidgets('with onRefused, a refused unit and the units that need it are left out, the rest queued at once', (
    tester,
  ) async {
    await _offline(tester);
    final l = _ledger(tester);
    final w = _writes(tester);
    final hdfc = _account(l, 'HDFC ··4821'), cash = _account(l, 'Cash');
    String id(int n) => 'c0000000-0000-5000-8000-${'$n'.padLeft(12, '0')}';
    final again = smsAccountId(l.me, 'HDFC again');
    PersonalTxnIn leg(String accountId, PersonalTxnInDirectionEnum direction, int amount) =>
        _sms('Own transfer', amount, type: 'transfer', accountId: accountId)
          ..direction = direction
          ..transferGroupId = transferGroupIdFor(id(3), id(4));
    final units = [
      [BatchItem.createEntry(id(1), _sms('Fine', 100, accountId: hdfc))],
      // An account with a label another one has, and an entry in it.
      [
        BatchItem.createAccount(
          again,
          PersonalAccountIn(name: 'HDFC again', type: PersonalAccountInTypeEnum.bank, smsLabel: 'HDFC ··4821'),
        ),
      ],
      [BatchItem.createEntry(id(2), _sms('In that account', 200, accountId: again))],
      // Halves of different amounts: refused whole, the first half too.
      [
        BatchItem.createEntry(id(3), leg(hdfc, PersonalTxnInDirectionEnum.out_, 500)),
        BatchItem.createEntry(id(4), leg(cash, PersonalTxnInDirectionEnum.in_, 600)),
      ],
      [BatchItem.createEntry(id(5), _sms('Also fine', 300, accountId: hdfc))],
      // An entry that isn't here.
      [BatchItem.updateEntry(id(9), _sms('Gone', 100, accountId: hdfc))],
    ];

    final store = appContainer(tester).read(localStoreProvider).value!;
    store.ledger; // built, so the count starts from here
    final builds = store.ledgerBuilds;
    final before = _ops(tester).length;
    final refused = <(String, String?)>[];
    await runWrite(
      tester,
      w.importUnits(units, onRefused: (unit, why) => refused.add((unit.first.id, apiErrorCode(why)))),
    );
    expect(refused, [(again, 'label_taken'), (id(2), 'unknown_account'), (id(3), 'transfer_invalid'), (id(9), null)]);
    final ops = _ops(tester).sublist(before);
    expect(ops.length, 1);
    expect(_items(ops.single).map((i) => i['id']), [id(1), id(5)]);
    expect([for (final e in ops.single.entities) e.entityId], [id(1), id(5)]);
    expect(store.ledgerBuilds - builds, 1);
    expect([_ledger(tester).rawPersonal(id(3)), _ledger(tester).rawAccount(again)], [null, null]);

    // Nothing left to queue: nothing is.
    await runWrite(tester, w.importUnits([units[3]], onRefused: (_, _) {}));
    expect(_ops(tester).length, before + 1);
  });

  testWidgets('an entry an account claims is changed in the next request, at the claimed version and account', (
    tester,
  ) async {
    await _offline(tester);
    final w = _writes(tester);
    const label = 'Axis ··3333';
    final entry = await runWrite(tester, w.createPersonal(_sms('Before the account', 1500, label: label)));
    final l = _ledger(tester);
    final axis = smsAccountId(l.me, label);
    final before = _ops(tester).length;
    await runWrite(
      tester,
      w.importUnits([
        [
          BatchItem.updateEntry(
            entry,
            personalBody(PersonalTxnOut.fromJson(l.personalTransaction(entry))!)..reviewed = true,
          ),
        ],
        [
          BatchItem.createAccount(
            axis,
            PersonalAccountIn(name: label, type: PersonalAccountInTypeEnum.bank, smsLabel: label),
          ),
        ],
      ]),
    );
    final ops = _ops(tester).sublist(before);
    expect(
      [for (final op in ops) _items(op).map((i) => (i['id'], i['version'])).toList()],
      [
        [(axis, null)],
        [(entry, 2)],
      ],
    );
    expect(
      [for (final e in ops[0].entities) (e.entityId, e.version, e.data['account_id'])],
      [(axis, 1, null), (entry, 2, axis)],
    );
    expect([for (final e in ops[1].entities) (e.entityId, e.version, e.data['account_id'])], [(entry, 3, axis)]);
    // Its body was made before the claim; it keeps the account all the same.
    expect(_txn(_items(ops[1]).single)['account_id'], axis);
  });

  testWidgets('keep mine on a transfer edit sends both legs again at the server\'s versions', (tester) async {
    final be = await pumpApp(tester);
    final (out, into) = _legs(_ledger(tester), 'Credit card bill');
    be.postResponses['/api/v1/personal/batch'] = (
      409,
      {
        'error': {'code': 'version_conflict', 'message': 'Someone changed this', 'item': 0},
      },
    );
    await runWrite(tester, _writes(tester).updateTransfer(out['transfer_group_id'], description: 'Card bill'));
    await tester.pumpAndSettle();
    final rejected = _ops(tester).single;
    expect((rejected.status, rejected.isConflict), (OutboxStatus.rejected, true));

    be.offline = true;
    await runWrite(tester, _writes(tester).keepMine(rejected));
    final retry = _ops(tester).single;
    expect(retry.status, OutboxStatus.pending);
    expect([for (final i in _items(retry)) (i['id'], i['version'])], [(out['id'], 1), (into['id'], 1)]);
    expect([for (final e in retry.entities) (e.entityId, e.version)], [(out['id'], 2), (into['id'], 2)]);
  });

  testWidgets('keep mine on a batch that starts with a create re-versions only what it changes', (tester) async {
    final be = await pumpApp(tester);
    final cash = _account(_ledger(tester), 'Cash');
    be.postResponses['/api/v1/personal/batch'] = (
      409,
      {
        'error': {'code': 'version_conflict', 'message': 'Someone changed this', 'item': 1},
      },
    );
    await runWrite(tester, _writes(tester).closeAccount(cash, zeroFirst: true));
    await tester.pumpAndSettle();
    final rejected = _ops(tester).single;
    expect(rejected.isConflict, isTrue);

    be.offline = true;
    await runWrite(tester, _writes(tester).keepMine(rejected));
    final retry = _ops(tester).single;
    expect(
      [for (final i in _items(retry)) (i['kind'], i['op'], i['version'])],
      [('transaction', 'create', null), ('account', 'update', 1)],
    );
    expect(
      [for (final e in retry.entities) (e.entity, e.version)],
      [('personal_transaction', 1), ('personal_account', 2)],
    );
  });
}
