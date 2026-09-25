//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ValidationError {
  /// Returns a new [ValidationError] instance.
  ValidationError({
    this.loc = const [],
    required this.msg,
    required this.type,
    this.input,
    this.ctx,
  });

  List<String> loc;

  String msg;

  String type;

  Object? input;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Object? ctx;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ValidationError &&
    _deepEquality.equals(other.loc, loc) &&
    other.msg == msg &&
    other.type == type &&
    other.input == input &&
    other.ctx == ctx;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (loc.hashCode) +
    (msg.hashCode) +
    (type.hashCode) +
    (input == null ? 0 : input!.hashCode) +
    (ctx == null ? 0 : ctx!.hashCode);

  @override
  String toString() => 'ValidationError[loc=$loc, msg=$msg, type=$type, input=$input, ctx=$ctx]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'loc'] = this.loc;
      json[r'msg'] = this.msg;
      json[r'type'] = this.type;
    if (this.input != null) {
      json[r'input'] = this.input;
    } else {
      json[r'input'] = null;
    }
    if (this.ctx != null) {
      json[r'ctx'] = this.ctx;
    } else {
      json[r'ctx'] = null;
    }
    return json;
  }

  /// Returns a new [ValidationError] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ValidationError? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ValidationError[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ValidationError[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ValidationError(
        loc: json[r'loc'] is Iterable
            ? (json[r'loc'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        msg: mapValueOfType<String>(json, r'msg')!,
        type: mapValueOfType<String>(json, r'type')!,
        input: mapValueOfType<Object>(json, r'input'),
        ctx: mapValueOfType<Object>(json, r'ctx'),
      );
    }
    return null;
  }

  static List<ValidationError> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ValidationError>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ValidationError.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ValidationError> mapFromJson(dynamic json) {
    final map = <String, ValidationError>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ValidationError.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ValidationError-objects as value to a dart map
  static Map<String, List<ValidationError>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ValidationError>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ValidationError.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'loc',
    'msg',
    'type',
  };
}

