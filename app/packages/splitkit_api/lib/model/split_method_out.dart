//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SplitMethodOut {
  /// Returns a new [SplitMethodOut] instance.
  SplitMethodOut({
    required this.key,
    required this.label,
    required this.symbol,
    required this.hint,
  });

  String key;

  String label;

  String symbol;

  String hint;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SplitMethodOut &&
    other.key == key &&
    other.label == label &&
    other.symbol == symbol &&
    other.hint == hint;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (key.hashCode) +
    (label.hashCode) +
    (symbol.hashCode) +
    (hint.hashCode);

  @override
  String toString() => 'SplitMethodOut[key=$key, label=$label, symbol=$symbol, hint=$hint]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'key'] = this.key;
      json[r'label'] = this.label;
      json[r'symbol'] = this.symbol;
      json[r'hint'] = this.hint;
    return json;
  }

  /// Returns a new [SplitMethodOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SplitMethodOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SplitMethodOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SplitMethodOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SplitMethodOut(
        key: mapValueOfType<String>(json, r'key')!,
        label: mapValueOfType<String>(json, r'label')!,
        symbol: mapValueOfType<String>(json, r'symbol')!,
        hint: mapValueOfType<String>(json, r'hint')!,
      );
    }
    return null;
  }

  static List<SplitMethodOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SplitMethodOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SplitMethodOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SplitMethodOut> mapFromJson(dynamic json) {
    final map = <String, SplitMethodOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SplitMethodOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SplitMethodOut-objects as value to a dart map
  static Map<String, List<SplitMethodOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SplitMethodOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SplitMethodOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'key',
    'label',
    'symbol',
    'hint',
  };
}

