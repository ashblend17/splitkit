/// Pure split engine: a Dart port of api/app/modules/splits/engine. Same methods, rounding
/// and messages; both pass shared/split_vectors.json. No Flutter imports, no I/O.
library;

import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

import '../money/money.dart';

class SplitInput {
  const SplitInput(this.userId, [this.value]);

  final String userId;

  /// equal: ignored · exact: minor units · percent: percentage · shares: share count.
  final Decimal? value;
}

class Share {
  const Share(this.userId, this.shareMinor, this.inputValue);

  final String userId;
  final int shareMinor;
  final Decimal? inputValue;

  @override
  String toString() => 'Share($userId, $shareMinor)';
}

class SplitValidation {
  const SplitValidation(this.ok, this.remainingMinor, this.message, [this.remainingPercent]);

  final bool ok;

  /// Total minus allocated. Negative means over-allocated.
  final int remainingMinor;

  /// Human copy for the status line, e.g. "₹100 still needs to be allocated".
  final String message;

  /// Percent method only: 100 minus the percentages entered.
  final Decimal? remainingPercent;
}

class SplitValidationException implements Exception {
  const SplitValidationException(this.validation);
  final SplitValidation validation;

  @override
  String toString() => validation.message;
}

abstract interface class SplitMethod {
  String get key;
  String get label;
  String get symbol;
  String get hint;

  SplitValidation validate(int totalMinor, List<SplitInput> inputs, {String currency = 'INR'});
  List<Share> allocate(int totalMinor, List<SplitInput> inputs, {String currency = 'INR'});
}

const valid = 'Split is valid';
final _hundred = Decimal.fromInt(100);

/// Largest-remainder allocation on exact fractions. Leftover paise go to the largest
/// remainders; ties go to the earlier input. A zero weight never receives a paisa.
List<int> distribute(int totalMinor, List<Decimal> weights) {
  if (totalMinor < 0) throw ArgumentError('totalMinor must not be negative');
  if (weights.any((w) => w < Decimal.zero)) throw ArgumentError('weights must not be negative');
  final sum = weights.fold(Rational.zero, (a, w) => a + w.toRational());
  if (sum == Rational.zero) throw ArgumentError('weights must not all be zero');

  final total = Rational.fromInt(totalMinor);
  final exact = [for (final w in weights) total * w.toRational() / sum];
  final parts = [for (final q in exact) (q.numerator ~/ q.denominator).toInt()];
  var leftover = totalMinor - parts.fold(0, (a, b) => a + b);
  final order = List<int>.generate(weights.length, (i) => i)
    ..sort((a, b) {
      final byRemainder = (exact[b] - Rational.fromInt(parts[b])).compareTo(exact[a] - Rational.fromInt(parts[a]));
      return byRemainder != 0 ? byRemainder : a.compareTo(b);
    });
  for (final i in order) {
    if (leftover == 0) break;
    parts[i] += 1;
    leftover -= 1;
  }
  return parts;
}

String _formatPercent(Decimal v) => '${v.toString()}%';

int _roundHalfUp(Rational x) {
  final half = Rational(BigInt.one, BigInt.two);
  final magnitude = x.abs() + half;
  final floor = (magnitude.numerator ~/ magnitude.denominator).toInt();
  return x.signum < 0 ? -floor : floor;
}

String _overOrUnder(int remaining, String currency) => remaining > 0
    ? '${formatMinor(remaining, currency: currency)} still needs to be allocated'
    : '${formatMinor(-remaining, currency: currency)} over the total — reduce someone';

SplitValidation? _checkCommon(int totalMinor, List<SplitInput> inputs, String currency) {
  final ids = inputs.map((i) => i.userId).toList();
  if (ids.length != ids.toSet().length) throw ArgumentError('Each person can appear only once in a split');
  if (totalMinor <= 0) {
    return SplitValidation(false, totalMinor, 'Enter an amount above ${formatMinor(0, currency: currency)}');
  }
  return null;
}

List<Decimal> _values(List<SplitInput> inputs) => [
  for (final i in inputs) i.value ?? (throw ArgumentError('Missing value for ${i.userId}')),
];

abstract class _Base implements SplitMethod {
  const _Base();

  List<int> parts(int totalMinor, List<SplitInput> inputs);

  @override
  List<Share> allocate(int totalMinor, List<SplitInput> inputs, {String currency = 'INR'}) {
    final v = validate(totalMinor, inputs, currency: currency);
    if (!v.ok) throw SplitValidationException(v);
    final p = parts(totalMinor, inputs);
    return [for (var i = 0; i < inputs.length; i++) Share(inputs[i].userId, p[i], inputs[i].value)];
  }
}

class EqualSplit extends _Base {
  const EqualSplit();
  @override
  String get key => 'equal';
  @override
  String get label => 'Equal';
  @override
  String get symbol => '=';
  @override
  String get hint => 'Everyone ticked pays the same. Untick anyone who is not involved.';

  @override
  SplitValidation validate(int totalMinor, List<SplitInput> inputs, {String currency = 'INR'}) {
    final failed = _checkCommon(totalMinor, inputs, currency);
    if (failed != null) return failed;
    if (inputs.isEmpty) return SplitValidation(false, totalMinor, 'Pick at least one person');
    return const SplitValidation(true, 0, valid);
  }

  @override
  List<Share> allocate(int totalMinor, List<SplitInput> inputs, {String currency = 'INR'}) =>
      super.allocate(totalMinor, [for (final i in inputs) SplitInput(i.userId)], currency: currency);

  @override
  List<int> parts(int totalMinor, List<SplitInput> inputs) =>
      distribute(totalMinor, List.filled(inputs.length, Decimal.one));
}

class ExactSplit extends _Base {
  const ExactSplit();
  @override
  String get key => 'exact';
  @override
  String get label => 'Exact';
  @override
  String get symbol => '₹';
  @override
  String get hint => 'Enter exactly what each person owes. It must add up to the total.';

  @override
  SplitValidation validate(int totalMinor, List<SplitInput> inputs, {String currency = 'INR'}) {
    final failed = _checkCommon(totalMinor, inputs, currency);
    if (failed != null) return failed;
    final values = _values(inputs);
    if (values.any((v) => !v.isInteger)) throw ArgumentError('Exact amounts must be whole minor units');
    final allocated = values.fold(0, (a, v) => a + v.toBigInt().toInt());
    final remaining = totalMinor - allocated;
    if (values.any((v) => v < Decimal.zero)) return SplitValidation(false, remaining, "Amounts can't be negative");
    if (remaining != 0) return SplitValidation(false, remaining, _overOrUnder(remaining, currency));
    return const SplitValidation(true, 0, valid);
  }

  @override
  List<int> parts(int totalMinor, List<SplitInput> inputs) => [for (final v in _values(inputs)) v.toBigInt().toInt()];
}

class PercentSplit extends _Base {
  const PercentSplit();
  @override
  String get key => 'percent';
  @override
  String get label => 'Percent';
  @override
  String get symbol => '%';
  @override
  String get hint => 'Give each person a percentage. It must add up to 100%.';

  @override
  SplitValidation validate(int totalMinor, List<SplitInput> inputs, {String currency = 'INR'}) {
    final failed = _checkCommon(totalMinor, inputs, currency);
    if (failed != null) return failed;
    final values = _values(inputs);
    final remainingPct = _hundred - values.fold(Decimal.zero, (a, v) => a + v);
    final remaining = _roundHalfUp(Rational.fromInt(totalMinor) * remainingPct.toRational() / _hundred.toRational());
    if (values.any((v) => v < Decimal.zero)) {
      return SplitValidation(false, remaining, "Percentages can't be negative", remainingPct);
    }
    if (remainingPct > Decimal.zero) {
      return SplitValidation(
        false,
        remaining,
        '${_formatPercent(remainingPct)} (${formatMinor(remaining, currency: currency)}) still needs to be allocated',
        remainingPct,
      );
    }
    if (remainingPct < Decimal.zero) {
      return SplitValidation(
        false,
        remaining,
        '${_formatPercent(-remainingPct)} over the total — reduce someone',
        remainingPct,
      );
    }
    return SplitValidation(true, 0, valid, Decimal.zero);
  }

  @override
  List<int> parts(int totalMinor, List<SplitInput> inputs) => distribute(totalMinor, _values(inputs));
}

class SharesSplit extends _Base {
  const SharesSplit();
  @override
  String get key => 'shares';
  @override
  String get label => 'Shares';
  @override
  String get symbol => '×';
  @override
  String get hint => 'Give each person shares, e.g. 2 for a couple. The total is divided by shares.';

  @override
  SplitValidation validate(int totalMinor, List<SplitInput> inputs, {String currency = 'INR'}) {
    final failed = _checkCommon(totalMinor, inputs, currency);
    if (failed != null) return failed;
    final values = _values(inputs);
    if (values.any((v) => v < Decimal.zero)) return SplitValidation(false, totalMinor, "Shares can't be negative");
    if (values.fold(Decimal.zero, (a, v) => a + v) == Decimal.zero) {
      return SplitValidation(false, totalMinor, _overOrUnder(totalMinor, currency));
    }
    return const SplitValidation(true, 0, valid);
  }

  @override
  List<int> parts(int totalMinor, List<SplitInput> inputs) => distribute(totalMinor, _values(inputs));
}

/// Split methods in selector order. The SplitSelector renders whatever is registered here.
class SplitRegistry {
  SplitRegistry([Iterable<SplitMethod> methods = const []]) {
    methods.forEach(register);
  }

  final _methods = <String, SplitMethod>{};

  void register(SplitMethod method) {
    if (_methods.containsKey(method.key)) throw ArgumentError('Split method already registered: ${method.key}');
    _methods[method.key] = method;
  }

  SplitMethod get(String key) => _methods[key] ?? (throw ArgumentError('Unknown split method: $key'));
  List<SplitMethod> get all => List.unmodifiable(_methods.values);
  List<String> get keys => List.unmodifiable(_methods.keys);
}

final splitRegistry = SplitRegistry(const [EqualSplit(), ExactSplit(), PercentSplit(), SharesSplit()]);
