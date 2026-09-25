//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SplitPreviewIn {
  /// Returns a new [SplitPreviewIn] instance.
  SplitPreviewIn({
    required this.method,
    this.inputs = const [],
    required this.totalMinor,
    this.currency = 'INR',
  });

  String method;

  List<SplitInputIn> inputs;

  int totalMinor;

  String currency;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SplitPreviewIn &&
    other.method == method &&
    _deepEquality.equals(other.inputs, inputs) &&
    other.totalMinor == totalMinor &&
    other.currency == currency;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (method.hashCode) +
    (inputs.hashCode) +
    (totalMinor.hashCode) +
    (currency.hashCode);

  @override
  String toString() => 'SplitPreviewIn[method=$method, inputs=$inputs, totalMinor=$totalMinor, currency=$currency]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'method'] = this.method;
      json[r'inputs'] = this.inputs;
      json[r'total_minor'] = this.totalMinor;
      json[r'currency'] = this.currency;
    return json;
  }

  /// Returns a new [SplitPreviewIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SplitPreviewIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SplitPreviewIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SplitPreviewIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SplitPreviewIn(
        method: mapValueOfType<String>(json, r'method')!,
        inputs: SplitInputIn.listFromJson(json[r'inputs']),
        totalMinor: mapValueOfType<int>(json, r'total_minor')!,
        currency: mapValueOfType<String>(json, r'currency') ?? 'INR',
      );
    }
    return null;
  }

  static List<SplitPreviewIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SplitPreviewIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SplitPreviewIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SplitPreviewIn> mapFromJson(dynamic json) {
    final map = <String, SplitPreviewIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SplitPreviewIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SplitPreviewIn-objects as value to a dart map
  static Map<String, List<SplitPreviewIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SplitPreviewIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SplitPreviewIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'method',
    'inputs',
    'total_minor',
  };
}

