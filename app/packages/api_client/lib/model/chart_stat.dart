//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ChartStat {
  /// Returns a new [ChartStat] instance.
  ChartStat({
    required this.valueMinor,
    this.note,
  });

  int valueMinor;

  String? note;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ChartStat &&
    other.valueMinor == valueMinor &&
    other.note == note;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (valueMinor.hashCode) +
    (note == null ? 0 : note!.hashCode);

  @override
  String toString() => 'ChartStat[valueMinor=$valueMinor, note=$note]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'value_minor'] = this.valueMinor;
    if (this.note != null) {
      json[r'note'] = this.note;
    } else {
      json[r'note'] = null;
    }
    return json;
  }

  /// Returns a new [ChartStat] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ChartStat? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ChartStat[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ChartStat[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ChartStat(
        valueMinor: mapValueOfType<int>(json, r'value_minor')!,
        note: mapValueOfType<String>(json, r'note'),
      );
    }
    return null;
  }

  static List<ChartStat> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ChartStat>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ChartStat.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ChartStat> mapFromJson(dynamic json) {
    final map = <String, ChartStat>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ChartStat.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ChartStat-objects as value to a dart map
  static Map<String, List<ChartStat>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ChartStat>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ChartStat.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'value_minor',
  };
}

