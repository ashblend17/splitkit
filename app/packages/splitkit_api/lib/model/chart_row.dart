//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ChartRow {
  /// Returns a new [ChartRow] instance.
  ChartRow({
    required this.label,
    required this.valueMinor,
  });

  String label;

  int valueMinor;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ChartRow &&
    other.label == label &&
    other.valueMinor == valueMinor;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (label.hashCode) +
    (valueMinor.hashCode);

  @override
  String toString() => 'ChartRow[label=$label, valueMinor=$valueMinor]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'label'] = this.label;
      json[r'value_minor'] = this.valueMinor;
    return json;
  }

  /// Returns a new [ChartRow] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ChartRow? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ChartRow[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ChartRow[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ChartRow(
        label: mapValueOfType<String>(json, r'label')!,
        valueMinor: mapValueOfType<int>(json, r'value_minor')!,
      );
    }
    return null;
  }

  static List<ChartRow> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ChartRow>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ChartRow.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ChartRow> mapFromJson(dynamic json) {
    final map = <String, ChartRow>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ChartRow.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ChartRow-objects as value to a dart map
  static Map<String, List<ChartRow>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ChartRow>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ChartRow.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'label',
    'value_minor',
  };
}

