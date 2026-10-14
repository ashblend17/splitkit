import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/categorise/category_rules.dart';

void main() {
  test('the pattern and id are the same as the server makes', () {
    // api tests/api/test_category_rules.py checks the same values.
    expect(rulePattern('  Zomato \t LIMITED '), 'zomato limited');
    expect(
      ruleId('332ab8e1-bd10-4aba-b102-000fde14e5ee', income: false, pattern: 'zomato limited'),
      '31ea0691-c685-5452-9ae5-6dac2475cabf',
    );
  });

  test("a merchant's key sets the bank's spelling aside", () {
    // Merchants as banks wrote them in real SMS.
    for (final (raw, key) in [
      ('ZOMATO LIMITED', 'zomato'),
      ('ZOMATO CYBS', 'zomato'),
      ('zomato.payu@axisbank', 'zomato'),
      ('Zomato', 'zomato'),
      ('Airtel', 'airtel'),
      ('airtel', 'airtel'),
      ('AMAZON PAY IN G', 'amazon pay'),
      ('AMAZON PAY IN E', 'amazon pay'),
      ('UBER INDIA SYST', 'uber'),
      ('Redbus India Pr', 'redbus'),
      ('JOHN DO', 'john'),
      ('CIJI C K', 'ciji'),
      ('DOE GLOBAL', 'doe global'),
      ('THE MILLET CAFE', 'the millet cafe'),
      ('KFC', 'kfc'),
      ('', ''),
    ]) {
      expect(merchantKey(raw), key, reason: raw);
    }
  });
}
