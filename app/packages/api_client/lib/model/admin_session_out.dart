//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminSessionOut {
  /// Returns a new [AdminSessionOut] instance.
  AdminSessionOut({
    required this.id,
    required this.admin,
    required this.target,
    required this.mode,
    required this.startedAt,
    this.endedAt,
    this.expiresAt,
    required this.active,
  });

  String id;

  UserBrief admin;

  UserBrief target;

  AdminSessionOutModeEnum mode;

  DateTime startedAt;

  DateTime? endedAt;

  DateTime? expiresAt;

  bool active;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminSessionOut &&
    other.id == id &&
    other.admin == admin &&
    other.target == target &&
    other.mode == mode &&
    other.startedAt == startedAt &&
    other.endedAt == endedAt &&
    other.expiresAt == expiresAt &&
    other.active == active;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (admin.hashCode) +
    (target.hashCode) +
    (mode.hashCode) +
    (startedAt.hashCode) +
    (endedAt == null ? 0 : endedAt!.hashCode) +
    (expiresAt == null ? 0 : expiresAt!.hashCode) +
    (active.hashCode);

  @override
  String toString() => 'AdminSessionOut[id=$id, admin=$admin, target=$target, mode=$mode, startedAt=$startedAt, endedAt=$endedAt, expiresAt=$expiresAt, active=$active]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'admin'] = this.admin;
      json[r'target'] = this.target;
      json[r'mode'] = this.mode;
      json[r'started_at'] = this.startedAt.toUtc().toIso8601String();
    if (this.endedAt != null) {
      json[r'ended_at'] = this.endedAt!.toUtc().toIso8601String();
    } else {
      json[r'ended_at'] = null;
    }
    if (this.expiresAt != null) {
      json[r'expires_at'] = this.expiresAt!.toUtc().toIso8601String();
    } else {
      json[r'expires_at'] = null;
    }
      json[r'active'] = this.active;
    return json;
  }

  /// Returns a new [AdminSessionOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminSessionOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminSessionOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminSessionOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminSessionOut(
        id: mapValueOfType<String>(json, r'id')!,
        admin: UserBrief.fromJson(json[r'admin'])!,
        target: UserBrief.fromJson(json[r'target'])!,
        mode: AdminSessionOutModeEnum.fromJson(json[r'mode'])!,
        startedAt: mapDateTime(json, r'started_at', r'')!,
        endedAt: mapDateTime(json, r'ended_at', r''),
        expiresAt: mapDateTime(json, r'expires_at', r''),
        active: mapValueOfType<bool>(json, r'active')!,
      );
    }
    return null;
  }

  static List<AdminSessionOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminSessionOut> mapFromJson(dynamic json) {
    final map = <String, AdminSessionOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminSessionOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminSessionOut-objects as value to a dart map
  static Map<String, List<AdminSessionOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminSessionOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminSessionOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'admin',
    'target',
    'mode',
    'started_at',
    'active',
  };
}


class AdminSessionOutModeEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminSessionOutModeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const readOnly = AdminSessionOutModeEnum._(r'read_only');
  static const edit = AdminSessionOutModeEnum._(r'edit');

  /// List of all possible values in this [enum][AdminSessionOutModeEnum].
  static const values = <AdminSessionOutModeEnum>[
    readOnly,
    edit,
  ];

  static AdminSessionOutModeEnum? fromJson(dynamic value) => AdminSessionOutModeEnumTypeTransformer().decode(value);

  static List<AdminSessionOutModeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionOutModeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionOutModeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminSessionOutModeEnum] to String,
/// and [decode] dynamic data back to [AdminSessionOutModeEnum].
class AdminSessionOutModeEnumTypeTransformer {
  factory AdminSessionOutModeEnumTypeTransformer() => _instance ??= const AdminSessionOutModeEnumTypeTransformer._();

  const AdminSessionOutModeEnumTypeTransformer._();

  String encode(AdminSessionOutModeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminSessionOutModeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminSessionOutModeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'read_only': return AdminSessionOutModeEnum.readOnly;
        case r'edit': return AdminSessionOutModeEnum.edit;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminSessionOutModeEnumTypeTransformer] instance.
  static AdminSessionOutModeEnumTypeTransformer? _instance;
}


