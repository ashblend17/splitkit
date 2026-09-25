import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/money/money.dart';

void main() {
  test('formatMinor matches the API formatter', () {
    const cases = {
      0: '₹0',
      50: '₹0.50',
      45000: '₹450',
      155000: '₹1,550',
      153333: '₹1,533.33',
      4826000: '₹48,260',
      8500000: '₹85,000',
      15000000: '₹1,50,000',
      1234567890: '₹1,23,45,678.90',
      -85000: '−₹850',
    };
    cases.forEach((minor, text) => expect(formatMinor(minor), text));
    expect(formatMinor(8500000, signed: true), '+₹85,000');
  });

  test('other currencies group in thousands', () {
    expect(formatMinor(15000000, currency: 'USD'), r'$150,000');
    expect(formatMinor(123456, currency: 'EUR'), '€1,234.56');
  });

  test('parseMinor', () {
    expect(parseMinor('600'), 60000);
    expect(parseMinor('600.5'), 60050);
    expect(parseMinor('₹1,800'), 180000);
    expect(parseMinor(' 0.01 '), 1);
    expect(parseMinor('1,50,000.00'), 15000000);
    expect(parseMinor('12.'), 1200);
    for (final bad in ['abc', '1.234', '', '-5']) {
      expect(parseMinor(bad), isNull, reason: bad);
    }
  });
}
