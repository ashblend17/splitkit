import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/finance/finance.dart';

void main() {
  const john = '49eaa721-4d30-5296-a193-d18818ade774'; // the seed's john

  test("smsAccountId gives the id the server's backfill gives a label", () {
    // api/tests/api/test_personal_backfill.py asserts the same literal (through ledger_vectors.json).
    expect(smsAccountId(john, 'HDFC ··4821'), '21aa8dac-2761-5677-ad69-c1b5e7fe9543');
    expect(smsAccountId(john, 'HDFC ··4821'), smsAccountId(john, 'HDFC ··4821'));
    expect(smsAccountId(john, 'HDFC ··4822'), isNot(smsAccountId(john, 'HDFC ··4821')));
  });

  test('accountTypeForLabel: only "credit card" makes a card', () {
    expect(accountTypeForLabel('ICICI Credit card ··9012'), AccountType.creditCard);
    expect(accountTypeForLabel('Debit card ··1234'), AccountType.bank);
    expect(accountTypeForLabel('Cash'), AccountType.bank);
  });
}
