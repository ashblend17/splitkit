//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CurrencyTotals {
  /// Returns a new [CurrencyTotals] instance.
  CurrencyTotals({
    required this.currency,
    required this.netMinor,
    required this.youOweMinor,
    required this.youAreOwedMinor,
  });

  String currency;

  int netMinor;

  int youOweMinor;

  int youAreOwedMinor;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CurrencyTotals &&
    other.currency == currency &&
    other.netMinor == netMinor &&
    other.youOweMinor == youOweMinor &&
    other.youAreOwedMinor == youAreOwedMinor;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (currency.hashCode) +
    (netMinor.hashCode) +
    (youOweMinor.hashCode) +
    (youAreOwedMinor.hashCode);

  @override
  String toString() => 'CurrencyTotals[currency=$currency, netMinor=$netMinor, youOweMinor=$youOweMinor, youAreOwedMinor=$youAreOwedMinor]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'currency'] = this.currency;
      json[r'net_minor'] = this.netMinor;
      json[r'you_owe_minor'] = this.youOweMinor;
      json[r'you_are_owed_minor'] = this.youAreOwedMinor;
    return json;
  }

  /// Returns a new [CurrencyTotals] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CurrencyTotals? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CurrencyTotals[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CurrencyTotals[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CurrencyTotals(
        currency: mapValueOfType<String>(json, r'currency')!,
        netMinor: mapValueOfType<int>(json, r'net_minor')!,
        youOweMinor: mapValueOfType<int>(json, r'you_owe_minor')!,
        youAreOwedMinor: mapValueOfType<int>(json, r'you_are_owed_minor')!,
      );
    }
    return null;
  }

  static List<CurrencyTotals> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CurrencyTotals>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CurrencyTotals.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CurrencyTotals> mapFromJson(dynamic json) {
    final map = <String, CurrencyTotals>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CurrencyTotals.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CurrencyTotals-objects as value to a dart map
  static Map<String, List<CurrencyTotals>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CurrencyTotals>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CurrencyTotals.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'currency',
    'net_minor',
    'you_owe_minor',
    'you_are_owed_minor',
  };
}

