//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminSessionIn {
  /// Returns a new [AdminSessionIn] instance.
  AdminSessionIn({
    required this.targetUserId,
    required this.mode,
  });

  String targetUserId;

  AdminSessionInModeEnum mode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminSessionIn &&
    other.targetUserId == targetUserId &&
    other.mode == mode;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (targetUserId.hashCode) +
    (mode.hashCode);

  @override
  String toString() => 'AdminSessionIn[targetUserId=$targetUserId, mode=$mode]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'target_user_id'] = this.targetUserId;
      json[r'mode'] = this.mode;
    return json;
  }

  /// Returns a new [AdminSessionIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminSessionIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminSessionIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminSessionIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminSessionIn(
        targetUserId: mapValueOfType<String>(json, r'target_user_id')!,
        mode: AdminSessionInModeEnum.fromJson(json[r'mode'])!,
      );
    }
    return null;
  }

  static List<AdminSessionIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminSessionIn> mapFromJson(dynamic json) {
    final map = <String, AdminSessionIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminSessionIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminSessionIn-objects as value to a dart map
  static Map<String, List<AdminSessionIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminSessionIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminSessionIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'target_user_id',
    'mode',
  };
}


class AdminSessionInModeEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminSessionInModeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const readOnly = AdminSessionInModeEnum._(r'read_only');
  static const edit = AdminSessionInModeEnum._(r'edit');

  /// List of all possible values in this [enum][AdminSessionInModeEnum].
  static const values = <AdminSessionInModeEnum>[
    readOnly,
    edit,
  ];

  static AdminSessionInModeEnum? fromJson(dynamic value) => AdminSessionInModeEnumTypeTransformer().decode(value);

  static List<AdminSessionInModeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionInModeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionInModeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminSessionInModeEnum] to String,
/// and [decode] dynamic data back to [AdminSessionInModeEnum].
class AdminSessionInModeEnumTypeTransformer {
  factory AdminSessionInModeEnumTypeTransformer() => _instance ??= const AdminSessionInModeEnumTypeTransformer._();

  const AdminSessionInModeEnumTypeTransformer._();

  String encode(AdminSessionInModeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminSessionInModeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminSessionInModeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'read_only': return AdminSessionInModeEnum.readOnly;
        case r'edit': return AdminSessionInModeEnum.edit;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminSessionInModeEnumTypeTransformer] instance.
  static AdminSessionInModeEnumTypeTransformer? _instance;
}


