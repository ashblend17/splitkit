import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/finance/finance.dart';

import 'finance_helpers.dart';

/// Linked accounts (FinAccount.linkedAccountId) in balances and net worth, and which account a
/// bank SMS label is (account_links.dart): by full number, by card digits, and the accounts that
/// look like one.
void main() {
  group('balances with links', () {
    test("a linked account's entries count in the account it's part of, as its type", () {
      final hdfc = account('hdfc', label: 'HDFC ··7778', opening: 100000);
      // Opened at the bank's balance, as an account read from a debit card's SMS is.
      final card = account('card', label: 'HDFC Debit card ··3016', opening: 999999, linkedTo: 'hdfc');
      final balances = accountBalances(
        [hdfc, card],
        [
          entry(type: 'expense', amount: 2000, accountId: 'hdfc', day: 20260901),
          entry(type: 'expense', amount: 500, accountId: 'card', day: 20260902, balance: 97500, sms: true),
        ],
      );
      final b = balances.single;
      expect((b.account.id, b.balanceMinor, b.entryCount), ('hdfc', 100000 - 2500, 2));
      expect(b.linked.map((a) => a.id), ['card']);
      // The card's SMS reported the account's balance: a checkpoint for it, and it agrees.
      expect((b.lastReported?.reportedMinor, b.lastReported?.gapMinor), (97500, 0));
      expect((b.firstActivityDay, b.lastActivityDay), (20260901, 20260902));
    });

    test("a card's spends labelled as a bank account count as what you owe once it's linked to the card", () {
      final credit = account('credit', type: AccountType.creditCard, label: 'HDFC Credit card ··5678');
      final plain = account('plain', label: 'HDFC Card ··5678', linkedTo: 'credit');
      final hdfc = account('hdfc', label: 'HDFC ··7778');
      final (out, into) = transfer(from: 'hdfc', to: 'credit', amount: 1000);
      final worth = netWorth(
        balances: accountBalances(
          [credit, plain, hdfc],
          [
            entry(type: 'expense', amount: 1299, accountId: 'plain'),
            out,
            into,
            entry(type: 'income', amount: 5000, accountId: 'hdfc'),
          ],
        ),
        currency: 'INR',
        splitNetMinor: 0,
        countSplit: false,
      );
      expect([for (final b in worth.accounts) (b.account.id, b.balanceMinor)], [('credit', 299), ('hdfc', 4000)]);
      expect((worth.liabilitiesMinor, worth.totalMinor), (299, 3701));
    });

    test('links are one level: to a deleted account, or to one linked itself, an account counts on its own', () {
      final balances = accountBalances(
        [
          account('a'),
          account('b', linkedTo: 'a'),
          account('c', linkedTo: 'b'),
          account('d', linkedTo: 'gone'),
          account('gone', deleted: true),
        ],
        [
          for (final id in ['a', 'b', 'c', 'd']) entry(type: 'income', amount: 100, accountId: id),
        ],
      );
      expect([for (final b in balances) (b.account.id, b.balanceMinor)], [('a', 200), ('c', 100), ('d', 100)]);
    });

    test('unchecked: entries, no balance from the bank and no correction', () {
      final card = account('card', type: AccountType.creditCard);
      expect(accountBalances([card], const []).single.unchecked, isFalse);
      final spent = entry(type: 'expense', amount: 500, accountId: 'card');
      expect(accountBalances([card], [spent]).single.unchecked, isTrue);
      final corrected = entry(type: 'adjustment', direction: 'in', amount: 500, accountId: 'card');
      expect(accountBalances([card], [spent, corrected]).single.correctionCount, 1);
      expect(accountBalances([card], [spent, corrected]).single.unchecked, isFalse);
      final bank = account('bank');
      final reported = entry(type: 'expense', amount: 500, accountId: 'bank', balance: 9500);
      expect(accountBalances([bank], [reported]).single.unchecked, isFalse);
    });

    test('the engine: wholeOf, linkedTo, and no goal follows a linked account', () {
      final f = FinanceEngine(
        accounts: [
          account('hdfc'),
          account('card', linkedTo: 'hdfc'),
        ],
        entries: const [],
        currency: 'INR',
      );
      expect((f.wholeOf('card')?.id, f.wholeOf('hdfc')?.id, f.wholeOf('nope')), ('hdfc', 'hdfc', null));
      expect(f.linkedTo('hdfc').map((a) => a.id), ['card']);
      expect(f.balanceOf('card'), isNull);
      expect(f.followableAccounts().map((a) => a.id), ['hdfc']);
    });
  });

  group('labels', () {
    test('labelParts reads what the parser writes', () {
      String? read(String label) => switch (labelParts(label)) {
        final p? => '${p.bank}|${p.card}|${p.digits}',
        null => null,
      };
      expect(read('HDFC ··4821'), 'HDFC|null|4821');
      expect(read('ICICI Credit card ··9012'), 'ICICI|credit|9012');
      expect(read('ICICI Debit card ··4455'), 'ICICI|debit|4455');
      expect(read('HDFC Card ··5678'), 'HDFC||5678');
      expect(read('IDFC First ··123'), 'IDFC First|null|123');
      expect(read('Bank ··4821'), 'null|null|4821');
      expect(read('My wallet'), isNull);
    });

    test('a label goes in the account whose full number its digits end, of the same bank', () {
      final sbi = account('sbi', name: 'SBI savings', number: '30012345678456');
      final other = account('other', name: 'Old wallet', number: '99998456');
      expect(accountForNewLabel('SBI ··8456', [sbi])?.id, 'sbi');
      expect(accountForNewLabel('SBI ··678456', [sbi])?.id, 'sbi');
      expect(accountForNewLabel('HDFC ··8456', [sbi]), isNull, reason: 'another bank');
      expect(
        accountForNewLabel('SBI Debit card ··8456', [sbi]),
        isNull,
        reason: "a card's digits aren't the account's",
      );
      // An account whose bank isn't known matches on 4 digits or more, so here two fit: neither.
      expect(accountForNewLabel('Bank ··8456', [other])?.id, 'other');
      expect(accountForNewLabel('SBI ··8456', [sbi, other]), isNull);
      expect(accountForNewLabel('Bank ··456', [other]), isNull);
    });

    test("a card's other wording goes in the card (ISS-088)", () {
      final plain = account('plain', label: 'HDFC Card ··5678');
      expect(accountForNewLabel('HDFC Credit card ··5678', [plain])?.id, 'plain');
      expect(accountForNewLabel('ICICI Credit card ··5678', [plain]), isNull);
      expect(accountForNewLabel('HDFC Credit card ··5679', [plain]), isNull);
    });
  });

  group('accounts that look like one', () {
    List<String> pairs(List<FinAccount> accounts, {Set<String> dismissed = const {}}) => [
      for (final s in sameAccounts(accountBalances(accounts, const []), dismissed: dismissed))
        '${s.part.id} → ${s.whole.id}: ${s.why}',
    ];

    test('the same bank, one number ending the other', () {
      expect(pairs([account('short', label: 'HDFC ··7778'), account('long', label: 'HDFC ··787778')]), [
        'long → short: the same bank, and 787778 ends in 7778',
      ]);
      expect(pairs([account('a', label: 'HDFC ··7778'), account('b', label: 'ICICI ··787778')]), isEmpty);
    });

    test('a full number that ends another account\'s digits', () {
      expect(
        pairs([account('sbi', name: 'SBI savings', number: '30012345678456'), account('sms', label: 'SBI ··8456')]),
        ["sms → sbi: SBI savings's number ends in 8456"],
      );
    });

    test('the same card labelled two ways keeps the credit card', () {
      expect(
        pairs([
          account('plain', label: 'HDFC Card ··5678'),
          account('credit', label: 'HDFC Credit card ··5678', type: AccountType.creditCard),
        ]),
        ['plain → credit: the same HDFC card, ending 5678'],
      );
    });

    test("a debit card, when it's your only account at that bank", () {
      final card = account('card', label: 'ICICI Debit card ··4455');
      expect(pairs([account('icici', label: 'ICICI ··104'), card]), [
        'card → icici: a debit card from ICICI, and ICICI ··104 is your only ICICI account',
      ]);
      expect(pairs([account('a', label: 'ICICI ··104'), account('b', label: 'ICICI ··909'), card]), isEmpty);
      // A plain "Card" (a prepaid card, or a credit card) isn't assumed to be on the account.
      expect(pairs([account('icici', label: 'ICICI ··104'), account('prepaid', label: 'ICICI Card ··3232')]), isEmpty);
    });

    test('not offered: dismissed, linked, closed or investment accounts', () {
      final short = account('short', label: 'HDFC ··7778');
      final first = sameAccounts(accountBalances([short, account('long', label: 'HDFC ··787778')], const [])).single;
      expect(pairs([short, account('long', label: 'HDFC ··787778')], dismissed: {first.key}), isEmpty);
      expect(pairs([short, account('long', label: 'HDFC ··787778', linkedTo: 'short')]), isEmpty);
      expect(pairs([short, account('long', label: 'HDFC ··787778', closed: true)]), isEmpty);
      expect(pairs([short, account('long', label: 'HDFC ··787778', type: AccountType.investment)]), isEmpty);
    });

    test('a bank account whose entries carry a credit card label looks like a card', () {
      final f = FinanceEngine(
        accounts: [
          account('plain', label: 'HDFC Card ··5678'),
          account('hdfc', label: 'HDFC ··7778'),
        ],
        entries: [
          entry(type: 'expense', accountId: 'plain', label: 'HDFC Card ··5678'),
          entry(
            type: 'transfer',
            direction: 'in',
            accountId: 'plain',
            label: 'HDFC Credit card ··5678',
            transferGroupId: 'g',
          ),
          entry(type: 'transfer', direction: 'out', accountId: 'hdfc', label: 'HDFC ··7778', transferGroupId: 'g'),
        ],
        currency: 'INR',
      );
      expect(
        [for (final c in looksLikeCards(f.balances, f.creditCardLabelIn)) '${c.account.id}: ${c.label}'],
        ['plain: HDFC Credit card ··5678'],
      );
    });
  });
}
