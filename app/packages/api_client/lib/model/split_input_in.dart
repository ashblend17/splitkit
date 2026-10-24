//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SplitInputIn {
  /// Returns a new [SplitInputIn] instance.
  SplitInputIn({
    required this.userId,
    this.value,
  });

  String userId;

  String? value;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SplitInputIn &&
    other.userId == userId &&
    other.value == value;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (userId.hashCode) +
    (value == null ? 0 : value!.hashCode);

  @override
  String toString() => 'SplitInputIn[userId=$userId, value=$value]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'user_id'] = this.userId;
    if (this.value != null) {
      json[r'value'] = this.value;
    } else {
      json[r'value'] = null;
    }
    return json;
  }

  /// Returns a new [SplitInputIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SplitInputIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SplitInputIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SplitInputIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SplitInputIn(
        userId: mapValueOfType<String>(json, r'user_id')!,
        value: mapValueOfType<String>(json, r'value'),
      );
    }
    return null;
  }

  static List<SplitInputIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SplitInputIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SplitInputIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SplitInputIn> mapFromJson(dynamic json) {
    final map = <String, SplitInputIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SplitInputIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SplitInputIn-objects as value to a dart map
  static Map<String, List<SplitInputIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SplitInputIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SplitInputIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'user_id',
  };
}

