//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SettleUpIn {
  /// Returns a new [SettleUpIn] instance.
  SettleUpIn({
    this.amountMinor,
    required this.date,
    required this.method,
    this.note,
    this.currency,
  });

  int? amountMinor;

  DateTime date;

  SettleUpInMethodEnum method;

  String? note;

  String? currency;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SettleUpIn &&
    other.amountMinor == amountMinor &&
    other.date == date &&
    other.method == method &&
    other.note == note &&
    other.currency == currency;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (amountMinor == null ? 0 : amountMinor!.hashCode) +
    (date.hashCode) +
    (method.hashCode) +
    (note == null ? 0 : note!.hashCode) +
    (currency == null ? 0 : currency!.hashCode);

  @override
  String toString() => 'SettleUpIn[amountMinor=$amountMinor, date=$date, method=$method, note=$note, currency=$currency]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.amountMinor != null) {
      json[r'amount_minor'] = this.amountMinor;
    } else {
      json[r'amount_minor'] = null;
    }
      json[r'date'] = _dateFormatter.format(this.date.toUtc());
      json[r'method'] = this.method;
    if (this.note != null) {
      json[r'note'] = this.note;
    } else {
      json[r'note'] = null;
    }
    if (this.currency != null) {
      json[r'currency'] = this.currency;
    } else {
      json[r'currency'] = null;
    }
    return json;
  }

  /// Returns a new [SettleUpIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SettleUpIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SettleUpIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SettleUpIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SettleUpIn(
        amountMinor: mapValueOfType<int>(json, r'amount_minor'),
        date: mapDateTime(json, r'date', r'')!,
        method: SettleUpInMethodEnum.fromJson(json[r'method'])!,
        note: mapValueOfType<String>(json, r'note'),
        currency: mapValueOfType<String>(json, r'currency'),
      );
    }
    return null;
  }

  static List<SettleUpIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SettleUpIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SettleUpIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SettleUpIn> mapFromJson(dynamic json) {
    final map = <String, SettleUpIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SettleUpIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SettleUpIn-objects as value to a dart map
  static Map<String, List<SettleUpIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SettleUpIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SettleUpIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'date',
    'method',
  };
}


class SettleUpInMethodEnum {
  /// Instantiate a new enum with the provided [value].
  const SettleUpInMethodEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const upi = SettleUpInMethodEnum._(r'upi');
  static const cash = SettleUpInMethodEnum._(r'cash');
  static const bank = SettleUpInMethodEnum._(r'bank');
  static const other = SettleUpInMethodEnum._(r'other');

  /// List of all possible values in this [enum][SettleUpInMethodEnum].
  static const values = <SettleUpInMethodEnum>[
    upi,
    cash,
    bank,
    other,
  ];

  static SettleUpInMethodEnum? fromJson(dynamic value) => SettleUpInMethodEnumTypeTransformer().decode(value);

  static List<SettleUpInMethodEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SettleUpInMethodEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SettleUpInMethodEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SettleUpInMethodEnum] to String,
/// and [decode] dynamic data back to [SettleUpInMethodEnum].
class SettleUpInMethodEnumTypeTransformer {
  factory SettleUpInMethodEnumTypeTransformer() => _instance ??= const SettleUpInMethodEnumTypeTransformer._();

  const SettleUpInMethodEnumTypeTransformer._();

  String encode(SettleUpInMethodEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SettleUpInMethodEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SettleUpInMethodEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'upi': return SettleUpInMethodEnum.upi;
        case r'cash': return SettleUpInMethodEnum.cash;
        case r'bank': return SettleUpInMethodEnum.bank;
        case r'other': return SettleUpInMethodEnum.other;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SettleUpInMethodEnumTypeTransformer] instance.
  static SettleUpInMethodEnumTypeTransformer? _instance;
}


