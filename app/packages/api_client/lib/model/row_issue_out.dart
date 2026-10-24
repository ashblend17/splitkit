//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class RowIssueOut {
  /// Returns a new [RowIssueOut] instance.
  RowIssueOut({
    required this.level,
    required this.code,
    required this.message,
  });

  RowIssueOutLevelEnum level;

  String code;

  String message;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RowIssueOut &&
    other.level == level &&
    other.code == code &&
    other.message == message;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (level.hashCode) +
    (code.hashCode) +
    (message.hashCode);

  @override
  String toString() => 'RowIssueOut[level=$level, code=$code, message=$message]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'level'] = this.level;
      json[r'code'] = this.code;
      json[r'message'] = this.message;
    return json;
  }

  /// Returns a new [RowIssueOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static RowIssueOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "RowIssueOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "RowIssueOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return RowIssueOut(
        level: RowIssueOutLevelEnum.fromJson(json[r'level'])!,
        code: mapValueOfType<String>(json, r'code')!,
        message: mapValueOfType<String>(json, r'message')!,
      );
    }
    return null;
  }

  static List<RowIssueOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RowIssueOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RowIssueOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, RowIssueOut> mapFromJson(dynamic json) {
    final map = <String, RowIssueOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = RowIssueOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of RowIssueOut-objects as value to a dart map
  static Map<String, List<RowIssueOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<RowIssueOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = RowIssueOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'level',
    'code',
    'message',
  };
}


class RowIssueOutLevelEnum {
  /// Instantiate a new enum with the provided [value].
  const RowIssueOutLevelEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const error = RowIssueOutLevelEnum._(r'error');
  static const warning = RowIssueOutLevelEnum._(r'warning');

  /// List of all possible values in this [enum][RowIssueOutLevelEnum].
  static const values = <RowIssueOutLevelEnum>[
    error,
    warning,
  ];

  static RowIssueOutLevelEnum? fromJson(dynamic value) => RowIssueOutLevelEnumTypeTransformer().decode(value);

  static List<RowIssueOutLevelEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RowIssueOutLevelEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RowIssueOutLevelEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [RowIssueOutLevelEnum] to String,
/// and [decode] dynamic data back to [RowIssueOutLevelEnum].
class RowIssueOutLevelEnumTypeTransformer {
  factory RowIssueOutLevelEnumTypeTransformer() => _instance ??= const RowIssueOutLevelEnumTypeTransformer._();

  const RowIssueOutLevelEnumTypeTransformer._();

  String encode(RowIssueOutLevelEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a RowIssueOutLevelEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  RowIssueOutLevelEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'error': return RowIssueOutLevelEnum.error;
        case r'warning': return RowIssueOutLevelEnum.warning;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [RowIssueOutLevelEnumTypeTransformer] instance.
  static RowIssueOutLevelEnumTypeTransformer? _instance;
}


