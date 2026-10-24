import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/api/api.dart';
import 'package:app/core/finance/finance.dart';
import 'package:app/core/local/ledger.dart';
import 'package:app/core/local/outbox.dart';
import 'package:app/core/local/providers.dart';
import 'package:app/core/local/writes.dart';

import '../fake_backend.dart';

// Holdings' writes (core/local/writes_holdings.dart) against the seed's sync snapshot, offline, so
// every write stays queued and the test reads what it would send and what it shows. The seed's
// Zerodha account holds the Nifty fund (valued 15 Aug, named by the 5 Sep SIP from HDFC) and
// Tata shares (valued 20 Sep, no cost basis).

const _today = 20260925;

Ledger _ledger(WidgetTester tester) => appContainer(tester).read(localStoreProvider).value!.ledger;
LocalWrites _writes(WidgetTester tester) => appContainer(tester).read(writesProvider);
List<OutboxOp> _ops(WidgetTester tester) => appContainer(tester).read(outboxProvider);

String _account(Ledger l, String name) => l.personalAccountList().firstWhere((a) => a['name'] == name)['id'] as String;
String _holding(Ledger l, String name) => l.finance.holdings.firstWhere((h) => h.name == name).id;
String _sip(Ledger l) =>
    (l.personalList(limit: 1 << 20)['items'] as List).cast<Json>().firstWhere(
          (t) => t['description'] == 'Index fund SIP',
        )['id']
        as String;

AccountValue _zerodha(WidgetTester tester) {
  final l = _ledger(tester);
  return l.finance.accountValue(_account(l, 'Zerodha'), today: _today)!;
}

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

Future<void> _offline(WidgetTester tester) async {
  final be = await pumpApp(tester);
  be.offline = true;
}

void main() {
  testWidgets('a holding is made in an investment account: one POST, shown at once', (tester) async {
    await _offline(tester);
    final l = _ledger(tester);
    final zerodha = _account(l, 'Zerodha');
    final id = await runWrite(
      tester,
      _writes(tester).createHolding(
        accountId: zerodha,
        name: ' Gold ETF ',
        type: HoldingType.gold,
        marketMinor: 2500000,
        valuationDay: DateTime(2026, 9, 24),
        quantity: ' 10.500 ',
        costBasisMinor: 2400000,
      ),
    );
    final op = _ops(tester).last;
    expect((op.method, op.path, op.label), ('POST', '/api/v1/personal/holdings', 'Added Gold ETF'));
    expect(PersonalHoldingIn.fromJson(op.body), isNotNull);
    expect(
      (op.body!['id'], op.body!['account_id'], op.body!['asset_type'], op.body!['valuation_at'], op.body!['quantity']),
      (id, zerodha, 'gold', '2026-09-24', '10.500'),
    );
    final made = op.entities.single;
    expect((made.entity, made.entityId, made.version), ('personal_holding', id, 1));
    // As the server keeps it: the name trimmed, the quantity normalised, the account's currency.
    expect(
      (made.data['name'], made.data['quantity'], made.data['currency'], made.data['cost_basis_minor']),
      ('Gold ETF', '10.5', 'INR', 2400000),
    );
    expect(_ledger(tester).finance.holdingsOf(zerodha, today: _today).map((h) => h.holding.name), [
      'Nifty 50 index fund',
      'Tata Motors shares',
      'Gold ETF',
    ]);
    // ₹68,450 + ₹12,300 + ₹25,000, with the SIP still at cost.
    expect(_zerodha(tester).valueMinor, 6845000 + 1230000 + 2500000 + 500000);
  });

  testWidgets('a holding is refused as the server refuses it', (tester) async {
    await _offline(tester);
    final l = _ledger(tester);
    final w = _writes(tester);
    final zerodha = _account(l, 'Zerodha');
    Future<String> make({
      String? accountId,
      String name = 'Gold ETF',
      DateTime? day,
      String? quantity,
      int market = 1000,
    }) => w.createHolding(
      accountId: accountId ?? zerodha,
      name: name,
      type: HoldingType.gold,
      marketMinor: market,
      valuationDay: day ?? DateTime(2026, 9, 25),
      quantity: quantity,
    );

    await _expectRefused(
      tester,
      make(accountId: _account(l, 'HDFC ··4821')),
      'not_investment_account',
      'Holdings go in an investment account',
    );
    await _expectRefused(
      tester,
      make(accountId: 'a0000000-0000-4000-8000-000000000001'),
      'unknown_account',
      "That account isn't available",
    );
    await _expectRefused(tester, make(name: '  '), 'invalid_input', "Name can't be empty");
    await _expectRefused(tester, make(market: -1), 'invalid_input');
    await _expectRefused(tester, make(quantity: 'ten'), 'invalid_input', 'Quantity must be a number');
    await _expectRefused(tester, make(quantity: '1.1234567'), 'invalid_input', 'Quantity has too many digits');
    // A day of slack for time zones, as the server allows; not two.
    await _expectRefused(tester, make(day: DateTime(2026, 9, 27)), 'invalid_input', "A value can't be from the future");
    await runWrite(tester, make(day: DateTime(2026, 9, 26)));
    // A closed one takes none. (Zerodha can't be closed while its holdings are worth something.)
    final groww = await runWrite(tester, w.createAccount(name: 'Groww', type: AccountType.investment));
    await runWrite(tester, w.closeAccount(groww));
    await _expectRefused(tester, make(accountId: groww), 'account_closed', 'That account is closed');
  });

  testWidgets('an edit sends the full body, so the cost basis, quantity and account stay', (tester) async {
    await _offline(tester);
    final l = _ledger(tester);
    final w = _writes(tester);
    final zerodha = _account(l, 'Zerodha');
    final nifty = _holding(l, 'Nifty 50 index fund');
    await runWrite(tester, w.updateHolding(nifty, name: 'Nifty index fund'));
    var op = _ops(tester).last;
    expect((op.method, op.path, op.label), ('PUT', '/api/v1/personal/holdings/$nifty', 'Edited Nifty index fund'));
    expect(PersonalHoldingIn.fromJson(op.body), isNotNull);
    expect(
      (
        op.body!['id'],
        op.body!['version'],
        op.body!['account_id'],
        op.body!['quantity'],
        op.body!['cost_basis_minor'],
        op.body!['market_value_minor'],
        op.body!['valuation_at'],
      ),
      (null, 1, zerodha, '412.358', 6000000, 6845000, '2026-08-15'),
    );
    expect((op.entities.single.version, op.entities.single.data['name']), (2, 'Nifty index fund'));
    // Nothing changes, nothing is queued.
    final queued = _ops(tester).length;
    await runWrite(tester, w.updateHolding(nifty, name: 'Nifty index fund'));
    expect(_ops(tester).length, queued);
    // Clearing: '' for the quantity, a flag for the cost basis.
    await runWrite(tester, w.updateHolding(nifty, quantity: '', clearCostBasis: true));
    op = _ops(tester).last;
    expect((op.body!['version'], op.body!['quantity'], op.body!['cost_basis_minor']), (2, null, null));
    expect(_ledger(tester).finance.holdingsOf(zerodha, today: _today).first.gainMinor, isNull);
  });

  testWidgets('Update value: a new value and day, the cost basis only when given', (tester) async {
    await _offline(tester);
    final l = _ledger(tester);
    final w = _writes(tester);
    final nifty = _holding(l, 'Nifty 50 index fund'), tata = _holding(l, 'Tata Motors shares');
    expect(_zerodha(tester).staleCount, 1);
    await runWrite(tester, w.updateValue(nifty, 7000000, DateTime(2026, 9, 25)));
    final op = _ops(tester).last;
    expect((op.method, op.label), ('PUT', 'Updated the value of Nifty 50 index fund'));
    expect(
      (op.body!['market_value_minor'], op.body!['valuation_at'], op.body!['cost_basis_minor']),
      (7000000, '2026-09-25', 6000000),
    );
    // Fresh again, and the 5 Sep SIP is in the new value: no longer added at cost.
    final v = _zerodha(tester);
    expect((v.staleCount, v.addedSinceMinor, v.valueMinor, v.asOfDay), (0, 0, 7000000 + 1230000, 20260920));
    await runWrite(tester, w.updateValue(tata, 1300000, DateTime(2026, 9, 25), costBasisMinor: 1100000));
    final shares = _zerodha(tester).holdings.firstWhere((h) => h.holding.id == tata);
    expect((shares.holding.costBasisMinor, shares.gainMinor), (1100000, 200000));
  });

  testWidgets('deleting a holding: refused while an entry names it; restore brings it back', (tester) async {
    await _offline(tester);
    final l = _ledger(tester);
    final w = _writes(tester);
    final nifty = _holding(l, 'Nifty 50 index fund'), tata = _holding(l, 'Tata Motors shares');
    await _expectRefused(
      tester,
      w.deleteHolding(nifty),
      'holding_in_use',
      'An entry names this holding. Change or delete them first',
    );
    await runWrite(tester, w.deleteHolding(tata));
    var op = _ops(tester).last;
    expect((op.method, op.path, op.query['version']), ('DELETE', '/api/v1/personal/holdings/$tata', '1'));
    expect(op.entities.single.data['deleted_at'], isNotNull);
    expect(_zerodha(tester).holdings.map((h) => h.holding.id), [nifty]);
    expect(_zerodha(tester).valueMinor, 6845000 + 500000);
    await runWrite(tester, w.restoreHolding(tata));
    op = _ops(tester).last;
    expect((op.method, op.path, op.query['version']), ('POST', '/api/v1/personal/holdings/$tata/restore', '2'));
    expect(_zerodha(tester).valueMinor, 8575000);
    // With the SIP gone, nothing names the fund.
    await runWrite(tester, w.deletePersonal(_sip(l)));
    await runWrite(tester, w.deleteHolding(nifty));
    expect(_zerodha(tester).holdings.map((h) => h.holding.id), [tata]);
  });

  testWidgets('an account with holdings is not deleted and stays an investment account', (tester) async {
    await _offline(tester);
    final l = _ledger(tester);
    final w = _writes(tester);
    final zerodha = _account(l, 'Zerodha');
    await _expectRefused(
      tester,
      w.deleteAccount(zerodha),
      'account_in_use',
      "This account has holdings, so it can't be deleted",
    );
    await _expectRefused(
      tester,
      w.updateAccount(zerodha, type: AccountType.bank),
      'account_in_use',
      'This account has holdings, so it stays an investment account',
    );
    // Once they're gone it can go, and a holding can't come back without it.
    final tata = _holding(l, 'Tata Motors shares');
    await runWrite(tester, w.deletePersonal(_sip(l)));
    await runWrite(tester, w.deleteHolding(_holding(l, 'Nifty 50 index fund')));
    await runWrite(tester, w.deleteHolding(tata));
    await runWrite(tester, w.deleteAccount(zerodha));
    await _expectRefused(
      tester,
      w.restoreHolding(tata),
      'unknown_account',
      "This holding's account was deleted. Restore the account first",
    );
  });

  testWidgets('in one batch: a holding and an investment naming it; its delete counts the entries so far', (
    tester,
  ) async {
    await _offline(tester);
    final l = _ledger(tester);
    final w = _writes(tester);
    final zerodha = _account(l, 'Zerodha'), hdfc = _account(l, 'HDFC ··4821');
    const holdingId = 'a0000000-0000-4000-8000-0000000000a1';
    PersonalTxnIn invest(int amount) => PersonalTxnIn(
      type: PersonalTxnInTypeEnum.investmentContribution,
      amountMinor: amount,
      description: 'Gold ETF',
      date: DateTime.utc(2026, 9, 25),
      accountId: hdfc,
      holdingId: holdingId,
      source_: PersonalTxnInSource_Enum.manual,
    );
    final body = PersonalHoldingIn(
      name: 'Gold ETF',
      assetType: PersonalHoldingInAssetTypeEnum.gold,
      marketValueMinor: 1000000,
      valuationAt: DateTime.utc(2026, 9, 24),
      valuationSource: PersonalHoldingInValuationSourceEnum.manual,
      accountId: zerodha,
    );
    await runWrite(
      tester,
      w.importUnits([
        [
          BatchItem.createHolding(holdingId, body),
          BatchItem.createEntry('a0000000-0000-4000-8000-0000000000e1', invest(200000)),
        ],
      ], label: (_) => 'Bought gold'),
    );
    final op = _ops(tester).last;
    expect(op.path, '/api/v1/personal/batch');
    final items = PersonalMixedBatchIn.fromJson(op.body)!.items;
    expect([for (final i in items) (i.kind.value, i.op.value)], [('holding', 'create'), ('transaction', 'create')]);
    final sent = ((op.body!['items'] as List).first as Map)['holding'] as Map;
    expect((sent['id'], sent['version'], sent['account_id']), (null, null, zerodha));
    expect(op.entities.map((e) => e.entity), ['personal_holding', 'personal_transaction']);
    // ₹10,000 valued 24 Sep, and the ₹2,000 put in on 25 Sep at cost.
    final gold = _zerodha(tester).holdings.firstWhere((h) => h.holding.id == holdingId);
    expect((gold.valueMinor, gold.addedSinceMinor), (1200000, 200000));
    await _expectRefused(
      tester,
      w.importUnits([
        [
          BatchItem.createEntry('a0000000-0000-4000-8000-0000000000e2', invest(100000)),
          BatchItem.deleteHolding(holdingId),
        ],
      ]),
      'holding_in_use',
      '2 entries name this holding. Change or delete them first',
    );
  });
}
