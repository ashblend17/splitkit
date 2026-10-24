//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MoneyTotal {
  /// Returns a new [MoneyTotal] instance.
  MoneyTotal({
    required this.amountMinor,
    required this.currency,
  });

  int amountMinor;

  String currency;

  @override
  bool operator ==(Object other) => identical(this, other) || other is MoneyTotal &&
    other.amountMinor == amountMinor &&
    other.currency == currency;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (amountMinor.hashCode) +
    (currency.hashCode);

  @override
  String toString() => 'MoneyTotal[amountMinor=$amountMinor, currency=$currency]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'amount_minor'] = this.amountMinor;
      json[r'currency'] = this.currency;
    return json;
  }

  /// Returns a new [MoneyTotal] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MoneyTotal? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "MoneyTotal[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "MoneyTotal[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return MoneyTotal(
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
        currency: mapValueOfType<String>(json, r'currency')!,
      );
    }
    return null;
  }

  static List<MoneyTotal> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MoneyTotal>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MoneyTotal.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MoneyTotal> mapFromJson(dynamic json) {
    final map = <String, MoneyTotal>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MoneyTotal.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MoneyTotal-objects as value to a dart map
  static Map<String, List<MoneyTotal>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<MoneyTotal>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MoneyTotal.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'amount_minor',
    'currency',
  };
}

