import 'package:flutter_test/flutter_test.dart';
import 'package:splitkit/core/categorise/category_rules.dart';
import 'package:splitkit/core/finance/finance.dart';

import 'finance_helpers.dart';

void main() {
  /// A spend at [merchant] on [day].
  FinEntry spend(
    String id, {
    int amount = 45000,
    int day = 20260910,
    String merchant = 'SWIGGY LIMITED',
    String? reference,
    String? accountId,
    String time = '10:00',
  }) => entry(
    id: id,
    type: 'expense',
    amount: amount,
    day: day,
    merchant: merchant,
    reference: reference,
    accountId: accountId,
    time: time,
    sms: true,
  );

  String? target(
    List<FinEntry> entries, {
    int amount = 45000,
    int day = 20260920,
    String? reference,
    String? merchant = 'Swiggy',
    String? accountId,
    int windowDays = 60,
  }) => refundTarget(
    entries,
    amountMinor: amount,
    day: day,
    reference: reference,
    merchantKey: merchant == null ? null : merchantKey(merchant),
    accountId: accountId,
    windowDays: windowDays,
  )?.id;

  test('a spend with the same bank reference wins over the merchant, whatever its date', () {
    final entries = [
      spend('same-merchant', day: 20260919),
      spend('same-ref', merchant: 'UPI payment', reference: '123456789012', day: 20250101),
    ];
    expect(target(entries, reference: '123456789012'), 'same-ref');
    expect(target(entries, reference: '999'), 'same-merchant');
  });

  test('otherwise a spend from the same merchant (by merchantKey), in the window before the refund', () {
    expect(target([spend('a')]), 'a');
    expect(target([spend('a', merchant: 'ZOMATO LTD')]), isNull);
    expect(target([spend('a')], merchant: null), isNull);
    expect(target([spend('a')], merchant: ''), isNull);
    // The window: up to 60 days before, not after.
    expect(target([spend('a', day: 20260722)]), 'a');
    expect(target([spend('a', day: 20260721)]), isNull);
    expect(target([spend('a', day: 20260921)]), isNull);
    expect(target([spend('a', day: 20260721)], windowDays: 61), 'a');
  });

  test('only live spends: not incomes, refunds or deleted entries', () {
    expect(
      target([
        entry(id: 'income', type: 'income', amount: 45000, day: 20260910, merchant: 'SWIGGY'),
        entry(id: 'gone', type: 'expense', amount: 45000, day: 20260910, merchant: 'SWIGGY', deletedAt: 'x'),
      ]),
      isNull,
    );
  });

  test('only with enough left to refund', () {
    final original = spend('a', amount: 45000);
    final earlier = entry(type: 'refund', amount: 30000, day: 20260912, refundOfId: 'a');
    expect(refundableMinor(original, [original, earlier]), 15000);
    expect(target([original, earlier], amount: 15000), 'a');
    expect(target([original, earlier], amount: 15001), isNull);
    // Deleted refunds give the money back to refund.
    final undone = entry(type: 'refund', amount: 30000, refundOfId: 'a', deletedAt: 'x');
    expect(refundableMinor(original, [original, undone]), 45000);
    // Never below zero.
    expect(refundableMinor(original, [original, earlier, entry(type: 'refund', amount: 30000, refundOfId: 'a')]), 0);
    // The reference match needs enough left too.
    final byRef = spend('r', amount: 100, reference: '555');
    expect(target([byRef, spend('m')], reference: '555'), 'm');
  });

  test('of several: the same account, then the exact amount, then the newest, then by id', () {
    expect(
      target([spend('other', day: 20260919), spend('mine', day: 20260901, accountId: 'hdfc')], accountId: 'hdfc'),
      'mine',
    );
    expect(target([spend('bigger', amount: 90000, day: 20260919), spend('exact', day: 20260901)]), 'exact');
    expect(target([spend('older', day: 20260901), spend('newer', day: 20260919)]), 'newer');
    expect(target([spend('morning', time: '09:00'), spend('evening', time: '21:00')]), 'evening');
    expect(target([spend('b'), spend('a')]), 'a');
  });
}
