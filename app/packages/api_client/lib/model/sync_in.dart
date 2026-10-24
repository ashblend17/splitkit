//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SyncIn {
  /// Returns a new [SyncIn] instance.
  SyncIn({
    this.cursors = const {},
    this.limit = 500,
  });

  Map<String, int> cursors;

  /// Minimum value: 1
  /// Maximum value: 1000
  int limit;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SyncIn &&
    _deepEquality.equals(other.cursors, cursors) &&
    other.limit == limit;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (cursors.hashCode) +
    (limit.hashCode);

  @override
  String toString() => 'SyncIn[cursors=$cursors, limit=$limit]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'cursors'] = this.cursors;
      json[r'limit'] = this.limit;
    return json;
  }

  /// Returns a new [SyncIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SyncIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SyncIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SyncIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SyncIn(
        cursors: mapCastOfType<String, int>(json, r'cursors') ?? const {},
        limit: mapValueOfType<int>(json, r'limit') ?? 500,
      );
    }
    return null;
  }

  static List<SyncIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SyncIn> mapFromJson(dynamic json) {
    final map = <String, SyncIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SyncIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SyncIn-objects as value to a dart map
  static Map<String, List<SyncIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SyncIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SyncIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

