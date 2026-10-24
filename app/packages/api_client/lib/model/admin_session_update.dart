//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminSessionUpdate {
  /// Returns a new [AdminSessionUpdate] instance.
  AdminSessionUpdate({
    required this.mode,
  });

  AdminSessionUpdateModeEnum mode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminSessionUpdate &&
    other.mode == mode;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (mode.hashCode);

  @override
  String toString() => 'AdminSessionUpdate[mode=$mode]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'mode'] = this.mode;
    return json;
  }

  /// Returns a new [AdminSessionUpdate] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminSessionUpdate? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminSessionUpdate[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminSessionUpdate[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminSessionUpdate(
        mode: AdminSessionUpdateModeEnum.fromJson(json[r'mode'])!,
      );
    }
    return null;
  }

  static List<AdminSessionUpdate> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionUpdate>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionUpdate.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminSessionUpdate> mapFromJson(dynamic json) {
    final map = <String, AdminSessionUpdate>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminSessionUpdate.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminSessionUpdate-objects as value to a dart map
  static Map<String, List<AdminSessionUpdate>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminSessionUpdate>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminSessionUpdate.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'mode',
  };
}


class AdminSessionUpdateModeEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminSessionUpdateModeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const readOnly = AdminSessionUpdateModeEnum._(r'read_only');
  static const edit = AdminSessionUpdateModeEnum._(r'edit');

  /// List of all possible values in this [enum][AdminSessionUpdateModeEnum].
  static const values = <AdminSessionUpdateModeEnum>[
    readOnly,
    edit,
  ];

  static AdminSessionUpdateModeEnum? fromJson(dynamic value) => AdminSessionUpdateModeEnumTypeTransformer().decode(value);

  static List<AdminSessionUpdateModeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionUpdateModeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionUpdateModeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminSessionUpdateModeEnum] to String,
/// and [decode] dynamic data back to [AdminSessionUpdateModeEnum].
class AdminSessionUpdateModeEnumTypeTransformer {
  factory AdminSessionUpdateModeEnumTypeTransformer() => _instance ??= const AdminSessionUpdateModeEnumTypeTransformer._();

  const AdminSessionUpdateModeEnumTypeTransformer._();

  String encode(AdminSessionUpdateModeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminSessionUpdateModeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminSessionUpdateModeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'read_only': return AdminSessionUpdateModeEnum.readOnly;
        case r'edit': return AdminSessionUpdateModeEnum.edit;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminSessionUpdateModeEnumTypeTransformer] instance.
  static AdminSessionUpdateModeEnumTypeTransformer? _instance;
}


