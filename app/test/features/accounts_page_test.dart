import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/api/api.dart';
import 'package:app/core/finance/finance.dart';
import 'package:app/core/finance/finance_providers.dart';
import 'package:app/core/local/providers.dart';
import 'package:app/core/local/writes.dart';
import 'package:app/core/router/router.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/personal/account_sheet.dart';
import 'package:app/features/personal/accounts_page.dart';
import 'package:app/features/sms/sms_importer.dart';
import 'package:app/features/sms/sms_setup_page.dart';

import '../fake_backend.dart';
import '../fake_sms.dart';
import '../helpers.dart';

/// The seed's accounts (test/fixtures/sync/john.json).
const hdfc = '21aa8dac-2761-5677-ad69-c1b5e7fe9543'; // bank, ₹96,135 from its entries; the bank said ₹39,936
const cash = '6b3de561-066a-5f99-9fba-efd3ea940df7'; // ₹500 opening + the ₹2,000 withdrawal
const savings = '137b07e8-c67b-5bb2-a5a7-4f58aa342755'; // Emergency savings, ₹1,20,000, no entries
const zerodha = '3ba3ab40-68eb-5169-bd41-e06f44ea0e71'; // investment, ₹0 balance, ₹85,750 in holdings

const tall = Size(390, 1400);
const desktop = Size(1440, 900);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens account [id]'s sheet from its row.
Future<void> _open(WidgetTester tester, String id) =>
    _tap(tester, find.descendant(of: find.byKey(ValueKey('account:$id')), matching: find.byType(IconTile)));

/// The seed with no accounts at all.
FakeBackend _noAccounts() {
  final be = FakeBackend();
  for (final s in be.snapshots.values) {
    ((s as Map)['entities'] as List).removeWhere((e) => (e as Map)['entity'] == 'personal_account');
  }
  return be;
}

List<(String, String, Map?)> _queued(WidgetTester tester) => [
  for (final op in appContainer(tester).read(outboxProvider)) (op.method, op.path, op.body as Map?),
];

void main() {
  setUpAll(loadFonts);

  for (final (name, size) in [('a phone', tall), ('a desktop', desktop)]) {
    testWidgets('on $name: net worth, accounts by group, and what the bank said', (tester) async {
      await pumpApp(tester, location: '/personal/accounts', size: size);
      expect(find.text('Net worth'), findsOneWidget);
      expect(find.text('₹3,05,515'), findsOneWidget); // Zerodha at its holdings' ₹85,750
      expect(find.text('₹3,04,385'), findsOneWidget); // assets
      expect(find.text('Owed on cards and loans'), findsOneWidget);
      expect(find.text('With friends (Split)'), findsOneWidget);
      expect(find.text('+₹1,470'), findsOneWidget);
      for (final group in ['CASH & BANK', 'CARDS & LOANS', 'INVESTMENTS & OTHER']) {
        expect(find.text(group), findsOneWidget);
      }
      expect(find.text('₹96,135'), findsOneWidget);
      expect(find.text('₹340 owed'), findsOneWidget); // the ICICI card
      expect(find.text('₹1,20,000'), findsOneWidget);
      expect(find.text('Bank said ₹39,936 on 23 Sep · ₹56,199 off'), findsOneWidget);
      expect(find.text('Reconcile'), findsOneWidget);
      expect(find.textContaining('CLOSED'), findsNothing);
      // A page opened from a tab: a centred column beside the rail or sidebar.
      expect(
        tester.getSize(find.ancestor(of: find.text('Net worth'), matching: find.byType(SkCard))).width,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Overview opens it, and Back returns', (tester) async {
    await pumpApp(tester, location: '/personal', size: tall);
    await _tap(tester, find.text('All accounts'));
    expect(find.byType(AccountsPage), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back to overview'));
    expect(find.byType(AccountsPage), findsNothing);
    expect(find.text('Spent in September'), findsOneWidget);
  });

  testWidgets('Reconcile records a correction at the bank\'s balance, with Undo', (tester) async {
    final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
    be.offline = true;
    await _tap(tester, find.text('Reconcile'));
    final (method, path, body) = _queued(tester).single;
    expect((method, path), ('POST', '/api/v1/personal/transactions'));
    expect(
      (body!['type'], body['direction'], body['amount_minor'], body['account_id'], body['date']),
      ('adjustment', 'out', 5619900, hdfc, '2026-09-23'),
    );
    expect(find.text('Recorded a ₹56,199 correction to HDFC ··4821'), findsOneWidget);
    expect(find.textContaining('Bank said'), findsNothing);
    expect(find.text('₹39,936'), findsOneWidget); // what the bank said, now the balance
    expect(find.text('₹2,49,316'), findsOneWidget); // net worth, ₹56,199 less

    await _tap(tester, find.text('Undo'));
    expect(_queued(tester).last.$1, 'DELETE');
    expect(find.text('Bank said ₹39,936 on 23 Sep · ₹56,199 off'), findsOneWidget);
    expect(find.text('₹96,135'), findsOneWidget);
  });

  testWidgets('with nothing to load yet, a skeleton', (tester) async {
    await pumpApp(tester, overrides: [netWorthProvider.overrideWith((ref) => Completer<NetWorth>().future)]);
    appContainer(tester).read(routerProvider).go('/personal/accounts');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LoadingSkeleton), findsOneWidget);
    expect(find.text('Net worth'), findsNothing);
  });

  testWidgets("when it can't be read, an error with Try again", (tester) async {
    var calls = 0;
    const wallet = FinAccount(id: 'w', name: 'Wallet', type: AccountType.cash, currency: 'INR', openingMinor: 50000);
    await pumpApp(
      tester,
      location: '/personal/accounts',
      overrides: [
        netWorthProvider.overrideWith((ref) async {
          if (calls++ == 0) {
            throw ApiException(
              500,
              jsonEncode({
                'error': {'code': 'x', 'message': 'Could not read this from the device'},
              }),
            );
          }
          return const NetWorth(
            assetsMinor: 50000,
            liabilitiesMinor: 0,
            splitMinor: 0,
            splitCounted: false,
            accounts: [AccountBalance(account: wallet, balanceMinor: 50000, entryCount: 0)],
          );
        }),
      ],
    );
    expect(find.text("Couldn't load this"), findsOneWidget);
    expect(find.text('Could not read this from the device'), findsOneWidget);
    await _tap(tester, find.text('Try again'));
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('With friends (Split)'), findsNothing); // not counted
  });

  testWidgets('with no accounts, an offer to add one', (tester) async {
    await pumpApp(tester, backend: _noAccounts(), location: '/personal/accounts');
    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.text('Add your bank, card or cash to see balances and net worth.'), findsOneWidget);
    await _tap(tester, find.widgetWithText(SkButton, 'Add account'));
    expect(find.text('Opening balance'), findsOneWidget);
  });

  testWidgets('with no accounts while bank SMS are read, it says they will appear', (tester) async {
    await pumpApp(
      tester,
      backend: _noAccounts(),
      location: '/personal/accounts',
      sms: FakeSmsSource(available: true),
      overrides: [
        smsSetupProvider.overrideWith(
          (ref) async => (settings: SmsSettings(since: DateTime(2026, 9)), dismissed: false, skipped: 0),
        ),
      ],
    );
    expect(
      find.text('Add your bank, card or cash to see balances and net worth. Accounts appear as bank SMS are read.'),
      findsOneWidget,
    );
  });

  testWidgets('adding an account: the sheet gives back its id', (tester) async {
    final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
    be.offline = true;
    final made = showAccountSheet(tester.element(find.byType(AccountsPage)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SelectableChip, 'Credit card'));
    await tester.pumpAndSettle();
    expect(find.text('Owed when you started'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'HDFC Millennia');
    await tester.enterText(find.byType(TextField).at(1), '1200');
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(SkButton, 'Add account'));
    final id = await made;
    final (method, path, body) = _queued(tester).single;
    expect((method, path), ('POST', '/api/v1/personal/accounts'));
    expect(
      (body!['id'], body['name'], body['type'], body['opening_balance_minor'], body['sms_label']),
      (id, 'HDFC Millennia', 'credit_card', 120000, null),
    );
    expect(find.text('HDFC Millennia'), findsOneWidget);
    expect(find.text('₹1,200 owed'), findsOneWidget);
  });

  testWidgets('editing an account sends what changed', (tester) async {
    final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
    be.offline = true;
    await _open(tester, savings);
    expect(find.text('Bank account · 0 entries'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Rainy day fund');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    final (method, path, body) = _queued(tester).single;
    expect((method, path), ('PUT', '/api/v1/personal/accounts/$savings'));
    expect((body!['name'], body['opening_balance_minor'], body['type']), ('Rainy day fund', 12000000, 'bank'));
    expect(find.text('Rainy day fund'), findsOneWidget);
  });

  testWidgets('closing an account with money in it records a correction first', (tester) async {
    final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
    be.offline = true;
    await _open(tester, cash);
    await _tap(tester, find.text('Close account'));
    expect(find.text('Record a ₹2,500 correction and close?'), findsOneWidget);
    await _tap(tester, find.text('Correct and close'));
    final (method, path, body) = _queued(tester).single;
    expect((method, path), ('POST', '/api/v1/personal/batch'));
    final items = (body!['items'] as List).cast<Map>();
    expect([for (final i in items) (i['op'], i['kind'])], [('create', 'transaction'), ('update', 'account')]);
    final (fix, account) = (items[0]['transaction'] as Map, items[1]['account'] as Map);
    expect(
      (fix['type'], fix['direction'], fix['amount_minor'], fix['account_id']),
      ('adjustment', 'out', 250000, cash),
    );
    expect(account['status'], 'closed');
    expect(find.text('Closed Cash'), findsOneWidget);
    expect(find.text('₹3,03,015'), findsOneWidget); // net worth, ₹2,500 less

    // Folded away under Closed until asked for.
    expect(find.byKey(const ValueKey('account:$cash')), findsNothing);
    await _tap(tester, find.text('CLOSED (1)'));
    expect(find.descendant(of: find.byKey(const ValueKey('account:$cash')), matching: find.text('₹0')), findsOneWidget);
    // Closed: no Reconcile for it, and it opens again from its sheet.
    await _open(tester, cash);
    expect(find.text('The bank says…'), findsNothing);
    await _tap(tester, find.text('Reopen'));
    expect(_queued(tester).last.$2, '/api/v1/personal/accounts/$cash');
    expect(find.text('Reopened Cash'), findsOneWidget);
  });

  testWidgets('deleting an account with no entries, and Undo', (tester) async {
    // Without the seed's rules: Emergency top-up sends money to Emergency savings (rule_points_here).
    final be = await pumpApp(
      tester,
      location: '/personal/accounts',
      size: tall,
      backend: FakeBackend().withoutAllocationRules(),
    );
    be.offline = true;
    // One with entries is closed instead.
    await _open(tester, hdfc);
    expect(find.text('Delete'), findsNothing);
    Navigator.of(tester.element(find.text('See entries'))).pop();
    await tester.pumpAndSettle();

    // The Emergency fund follows Emergency savings, which can't be deleted while it does.
    const fund = '44810de1-2cb6-5600-bbda-885df88b8d98';
    await runWrite(tester, appContainer(tester).read(writesProvider).deleteGoal(fund));
    await tester.pumpAndSettle();
    await _open(tester, savings);
    await _tap(tester, find.text('Delete'));
    expect(_queued(tester).last.$1, 'DELETE');
    expect(_queued(tester).last.$2, '/api/v1/personal/accounts/$savings');
    expect(find.text('Deleted Emergency savings'), findsOneWidget);
    expect(find.text('Emergency savings'), findsNothing);
    await _tap(tester, find.text('Undo'));
    expect(_queued(tester).last.$2, '/api/v1/personal/accounts/$savings/restore');
    expect(find.text('Emergency savings'), findsOneWidget);
  });

  testWidgets("an account a goal follows, or with holdings, offers no Delete: it says why", (tester) async {
    await pumpApp(tester, location: '/personal/accounts', size: tall);
    await _open(tester, savings);
    expect(find.text('Bank account · 0 entries'), findsOneWidget);
    expect(find.widgetWithText(SkButton, 'Delete'), findsNothing);
    expect(find.text("Emergency fund follows this account's balance, so it can't be deleted."), findsOneWidget);
    Navigator.of(tester.element(find.text('See entries'))).pop();
    await tester.pumpAndSettle();

    // Zerodha: worth its holdings, not matched to a bank, and kept while it has them.
    await _open(tester, zerodha);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('Holdings ₹85,750 · incl. ₹5,000 added since 15 Aug'), findsWidgets);
    expect(find.text('The bank says…'), findsNothing);
    expect(find.widgetWithText(SkButton, 'Delete'), findsNothing);
    expect(find.text("It has holdings, so it can't be deleted. Delete them first."), findsOneWidget);
  });

  testWidgets('"The bank says…" sets the balance as of today', (tester) async {
    final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
    be.offline = true;
    await _open(tester, cash);
    await tester.enterText(find.byType(TextField).at(3), '3000');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Match'));
    final (method, _, body) = _queued(tester).single;
    expect(method, 'POST');
    expect(
      (body!['type'], body['direction'], body['amount_minor'], body['date']),
      ('adjustment', 'in', 50000, '2026-09-25'),
    );
    expect(find.text('Recorded a ₹500 correction to Cash'), findsOneWidget);
    expect(find.text('₹3,000'), findsOneWidget);
  });

  testWidgets("See entries shows the account's entries", (tester) async {
    await pumpApp(tester, location: '/personal/accounts', size: tall);
    await _open(tester, hdfc);
    await _tap(tester, find.text('See entries'));
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('HDFC ··4821'), findsOneWidget); // the account filter
    expect(find.text('Swiggy order'), findsOneWidget);
    expect(find.text('Blue Tokai coffee'), findsNothing); // the ICICI card
  });

  testWidgets('an account linked to another is listed under it, and counts in its balance', (tester) async {
    final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
    be.offline = true;
    final w = appContainer(tester).read(writesProvider);
    final card = await runWrite(
      tester,
      w.createAccount(name: 'HDFC Debit card ··3016', type: AccountType.bank, smsLabel: 'HDFC Debit card ··3016'),
    );
    await runWrite(
      tester,
      w.createPersonal(
        PersonalTxnIn(
          type: PersonalTxnInTypeEnum.expense,
          amountMinor: 13500,
          description: 'Paddle',
          date: DateTime.utc(2026, 9, 24),
          accountId: card,
          source_: PersonalTxnInSource_Enum.manual,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('account:$card')), findsOneWidget);
    await runWrite(tester, w.linkAccount(card, intoId: hdfc));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('account:$card')), findsNothing);
    expect(find.text('Bank account · with HDFC Debit card ··3016'), findsOneWidget);
    expect(find.text('₹96,000'), findsOneWidget); // ₹96,135 less the card's ₹135

    // Its sheet lists the card, with Unlink.
    await _open(tester, hdfc);
    expect(find.byKey(ValueKey('account:linked:$card')), findsOneWidget);
    await _tap(tester, find.descendant(of: find.byKey(ValueKey('account:linked:$card')), matching: find.text('Unlink')));
    expect(_queued(tester).last.$3!['linked_account_id'], isNull);
    expect(find.text('Unlinked HDFC Debit card ··3016 from HDFC ··4821'), findsOneWidget);
    expect(find.byKey(ValueKey('account:$card')), findsOneWidget);
  });

  testWidgets('accounts that look like one are offered: Link, or Not the same', (tester) async {
    final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
    be.offline = true;
    final w = appContainer(tester).read(writesProvider);
    final long = await runWrite(
      tester,
      w.createAccount(name: 'HDFC ··54821', type: AccountType.bank, smsLabel: 'HDFC ··54821'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Same account?'), findsOneWidget);
    expect(
      find.text(
        "HDFC ··54821 looks like part of HDFC ··4821: the same bank, and 54821 ends in 4821. Linked, its entries "
        "count in HDFC ··4821's balance.",
      ),
      findsOneWidget,
    );
    await _tap(tester, find.widgetWithText(SkButton, 'Link'));
    final (method, path, body) = _queued(tester).last;
    expect((method, path, body!['linked_account_id']), ('PUT', '/api/v1/personal/accounts/$long', hdfc));
    expect(find.text('Linked HDFC ··54821 to HDFC ··4821'), findsOneWidget);
    expect(find.text('Same account?'), findsNothing);

    await _tap(tester, find.text('Undo'));
    expect(find.text('Same account?'), findsOneWidget);
    await _tap(tester, find.widgetWithText(SkButton, 'Not the same'));
    expect(find.text('Same account?'), findsNothing);
    expect(appContainer(tester).read(notSameAccountProvider).value, hasLength(1));
  });

  testWidgets('a card read from SMS and never checked says so; Set owed opens it', (tester) async {
    final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
    be.offline = true;
    final card = appContainer(tester).read(financeEngineProvider).value!.accountForLabel('ICICI Credit card ··9012')!;
    expect(find.byKey(ValueKey('account:unchecked:${card.id}')), findsOneWidget);
    expect(find.text('Added up from SMS since 5 Sep, never checked'), findsOneWidget);
    await _tap(tester, find.text('Set owed'));
    expect(find.text('The bank says…'), findsOneWidget);
    expect(
      find.text(
        "Type what the statement says you owe. A correction dated today makes this match, and entries dated before "
        "it won't change it.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('"The bank says…" can be below zero (ISS-101)', (tester) async {
    final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
    be.offline = true;
    await _open(tester, cash);
    await tester.enterText(find.byType(TextField).at(3), '300');
    await _tap(tester, find.widgetWithText(SelectableChip, 'Overdrawn (below zero)').last);
    await _tap(tester, find.text('Match'));
    final (_, _, body) = _queued(tester).single;
    expect((body!['direction'], body['amount_minor']), ('out', 280000)); // ₹2,500 to −₹300
    expect(body['balance_minor'], -30000); // what it is from now on (ISS-130)
    expect(find.text('−₹300'), findsOneWidget);
    await _open(tester, cash);
    expect(find.text('Balance set to −₹300 on Today.'), findsOneWidget);
  });

  testWidgets('an account sheet links the account to another, and takes its full number', (tester) async {
    final be = await pumpApp(tester, location: '/personal/accounts', size: tall);
    be.offline = true;
    final w = appContainer(tester).read(writesProvider);
    final card = await runWrite(tester, w.createAccount(name: 'Card ··3232', type: AccountType.bank));
    await tester.pumpAndSettle();
    await _open(tester, card);
    await _tap(tester, find.text('This is part of another account'));
    await _tap(tester, find.byKey(ValueKey('account:pick:$hdfc')));
    expect(find.text('Link Card ··3232 to HDFC ··4821?'), findsOneWidget);
    await _tap(tester, find.text('Link').last);
    expect(_queued(tester).last.$3!['linked_account_id'], hdfc);
    expect(find.byKey(ValueKey('account:$card')), findsNothing);

    await _open(tester, hdfc);
    expect(find.text('Account number (optional)'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'The full number'), '5010 0123 4821');
    await _tap(tester, find.text('Save changes'));
    expect(_queued(tester).last.$3!['account_number'], '5010 0123 4821');
    expect(appContainer(tester).read(financeEngineProvider).value!.account(hdfc)!.accountNumber, '501001234821');
  });
}
