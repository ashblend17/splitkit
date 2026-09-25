//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SplitIn {
  /// Returns a new [SplitIn] instance.
  SplitIn({
    required this.method,
    this.inputs = const [],
  });

  String method;

  List<SplitInputIn> inputs;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SplitIn &&
    other.method == method &&
    _deepEquality.equals(other.inputs, inputs);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (method.hashCode) +
    (inputs.hashCode);

  @override
  String toString() => 'SplitIn[method=$method, inputs=$inputs]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'method'] = this.method;
      json[r'inputs'] = this.inputs;
    return json;
  }

  /// Returns a new [SplitIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SplitIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SplitIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SplitIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SplitIn(
        method: mapValueOfType<String>(json, r'method')!,
        inputs: SplitInputIn.listFromJson(json[r'inputs']),
      );
    }
    return null;
  }

  static List<SplitIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SplitIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SplitIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SplitIn> mapFromJson(dynamic json) {
    final map = <String, SplitIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SplitIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SplitIn-objects as value to a dart map
  static Map<String, List<SplitIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SplitIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SplitIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'method',
    'inputs',
  };
}

