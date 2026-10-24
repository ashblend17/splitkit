//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ChartAverage {
  /// Returns a new [ChartAverage] instance.
  ChartAverage({
    required this.label,
    required this.averageMinor,
    required this.nowMinor,
  });

  String label;

  int averageMinor;

  int nowMinor;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ChartAverage &&
    other.label == label &&
    other.averageMinor == averageMinor &&
    other.nowMinor == nowMinor;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (label.hashCode) +
    (averageMinor.hashCode) +
    (nowMinor.hashCode);

  @override
  String toString() => 'ChartAverage[label=$label, averageMinor=$averageMinor, nowMinor=$nowMinor]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'label'] = this.label;
      json[r'average_minor'] = this.averageMinor;
      json[r'now_minor'] = this.nowMinor;
    return json;
  }

  /// Returns a new [ChartAverage] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ChartAverage? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ChartAverage[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ChartAverage[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ChartAverage(
        label: mapValueOfType<String>(json, r'label')!,
        averageMinor: mapValueOfType<int>(json, r'average_minor')!,
        nowMinor: mapValueOfType<int>(json, r'now_minor')!,
      );
    }
    return null;
  }

  static List<ChartAverage> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ChartAverage>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ChartAverage.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ChartAverage> mapFromJson(dynamic json) {
    final map = <String, ChartAverage>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ChartAverage.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ChartAverage-objects as value to a dart map
  static Map<String, List<ChartAverage>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ChartAverage>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ChartAverage.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'label',
    'average_minor',
    'now_minor',
  };
}

