//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalReminderStateOut {
  /// Returns a new [PersonalReminderStateOut] instance.
  PersonalReminderStateOut({
    required this.id,
    required this.dedupKey,
    required this.status,
    this.snoozedUntil,
    this.actingAdminId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
  });

  String id;

  String dedupKey;

  PersonalReminderStateOutStatusEnum status;

  DateTime? snoozedUntil;

  String? actingAdminId;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? deletedAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalReminderStateOut &&
    other.id == id &&
    other.dedupKey == dedupKey &&
    other.status == status &&
    other.snoozedUntil == snoozedUntil &&
    other.actingAdminId == actingAdminId &&
    other.createdAt == createdAt &&
    other.updatedAt == updatedAt &&
    other.deletedAt == deletedAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (dedupKey.hashCode) +
    (status.hashCode) +
    (snoozedUntil == null ? 0 : snoozedUntil!.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (createdAt.hashCode) +
    (updatedAt.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'PersonalReminderStateOut[id=$id, dedupKey=$dedupKey, status=$status, snoozedUntil=$snoozedUntil, actingAdminId=$actingAdminId, createdAt=$createdAt, updatedAt=$updatedAt, deletedAt=$deletedAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'dedup_key'] = this.dedupKey;
      json[r'status'] = this.status;
    if (this.snoozedUntil != null) {
      json[r'snoozed_until'] = this.snoozedUntil!.toUtc().toIso8601String();
    } else {
      json[r'snoozed_until'] = null;
    }
    if (this.actingAdminId != null) {
      json[r'acting_admin_id'] = this.actingAdminId;
    } else {
      json[r'acting_admin_id'] = null;
    }
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
      json[r'updated_at'] = this.updatedAt.toUtc().toIso8601String();
    if (this.deletedAt != null) {
      json[r'deleted_at'] = this.deletedAt!.toUtc().toIso8601String();
    } else {
      json[r'deleted_at'] = null;
    }
      json[r'version'] = this.version;
    return json;
  }

  /// Returns a new [PersonalReminderStateOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalReminderStateOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalReminderStateOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalReminderStateOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalReminderStateOut(
        id: mapValueOfType<String>(json, r'id')!,
        dedupKey: mapValueOfType<String>(json, r'dedup_key')!,
        status: PersonalReminderStateOutStatusEnum.fromJson(json[r'status'])!,
        snoozedUntil: mapDateTime(json, r'snoozed_until', r''),
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<PersonalReminderStateOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalReminderStateOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalReminderStateOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalReminderStateOut> mapFromJson(dynamic json) {
    final map = <String, PersonalReminderStateOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalReminderStateOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalReminderStateOut-objects as value to a dart map
  static Map<String, List<PersonalReminderStateOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalReminderStateOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalReminderStateOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'dedup_key',
    'status',
    'created_at',
    'updated_at',
    'version',
  };
}


class PersonalReminderStateOutStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalReminderStateOutStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const dismissed = PersonalReminderStateOutStatusEnum._(r'dismissed');
  static const snoozed = PersonalReminderStateOutStatusEnum._(r'snoozed');
  static const done = PersonalReminderStateOutStatusEnum._(r'done');

  /// List of all possible values in this [enum][PersonalReminderStateOutStatusEnum].
  static const values = <PersonalReminderStateOutStatusEnum>[
    dismissed,
    snoozed,
    done,
  ];

  static PersonalReminderStateOutStatusEnum? fromJson(dynamic value) => PersonalReminderStateOutStatusEnumTypeTransformer().decode(value);

  static List<PersonalReminderStateOutStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalReminderStateOutStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalReminderStateOutStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalReminderStateOutStatusEnum] to String,
/// and [decode] dynamic data back to [PersonalReminderStateOutStatusEnum].
class PersonalReminderStateOutStatusEnumTypeTransformer {
  factory PersonalReminderStateOutStatusEnumTypeTransformer() => _instance ??= const PersonalReminderStateOutStatusEnumTypeTransformer._();

  const PersonalReminderStateOutStatusEnumTypeTransformer._();

  String encode(PersonalReminderStateOutStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalReminderStateOutStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalReminderStateOutStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'dismissed': return PersonalReminderStateOutStatusEnum.dismissed;
        case r'snoozed': return PersonalReminderStateOutStatusEnum.snoozed;
        case r'done': return PersonalReminderStateOutStatusEnum.done;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalReminderStateOutStatusEnumTypeTransformer] instance.
  static PersonalReminderStateOutStatusEnumTypeTransformer? _instance;
}


