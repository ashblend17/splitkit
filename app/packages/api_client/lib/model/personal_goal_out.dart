//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalGoalOut {
  /// Returns a new [PersonalGoalOut] instance.
  PersonalGoalOut({
    required this.id,
    required this.name,
    required this.targetMinor,
    required this.currency,
    this.targetDate,
    required this.trackingMode,
    this.linkedAccountId,
    this.manualProgressMinor,
    this.expectedReturnBp,
    required this.priority,
    required this.status,
    this.actingAdminId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
  });

  String id;

  String name;

  int targetMinor;

  String currency;

  DateTime? targetDate;

  PersonalGoalOutTrackingModeEnum trackingMode;

  String? linkedAccountId;

  int? manualProgressMinor;

  int? expectedReturnBp;

  int priority;

  PersonalGoalOutStatusEnum status;

  String? actingAdminId;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? deletedAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalGoalOut &&
    other.id == id &&
    other.name == name &&
    other.targetMinor == targetMinor &&
    other.currency == currency &&
    other.targetDate == targetDate &&
    other.trackingMode == trackingMode &&
    other.linkedAccountId == linkedAccountId &&
    other.manualProgressMinor == manualProgressMinor &&
    other.expectedReturnBp == expectedReturnBp &&
    other.priority == priority &&
    other.status == status &&
    other.actingAdminId == actingAdminId &&
    other.createdAt == createdAt &&
    other.updatedAt == updatedAt &&
    other.deletedAt == deletedAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode) +
    (targetMinor.hashCode) +
    (currency.hashCode) +
    (targetDate == null ? 0 : targetDate!.hashCode) +
    (trackingMode.hashCode) +
    (linkedAccountId == null ? 0 : linkedAccountId!.hashCode) +
    (manualProgressMinor == null ? 0 : manualProgressMinor!.hashCode) +
    (expectedReturnBp == null ? 0 : expectedReturnBp!.hashCode) +
    (priority.hashCode) +
    (status.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (createdAt.hashCode) +
    (updatedAt.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'PersonalGoalOut[id=$id, name=$name, targetMinor=$targetMinor, currency=$currency, targetDate=$targetDate, trackingMode=$trackingMode, linkedAccountId=$linkedAccountId, manualProgressMinor=$manualProgressMinor, expectedReturnBp=$expectedReturnBp, priority=$priority, status=$status, actingAdminId=$actingAdminId, createdAt=$createdAt, updatedAt=$updatedAt, deletedAt=$deletedAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
      json[r'target_minor'] = this.targetMinor;
      json[r'currency'] = this.currency;
    if (this.targetDate != null) {
      json[r'target_date'] = _dateFormatter.format(this.targetDate!.toUtc());
    } else {
      json[r'target_date'] = null;
    }
      json[r'tracking_mode'] = this.trackingMode;
    if (this.linkedAccountId != null) {
      json[r'linked_account_id'] = this.linkedAccountId;
    } else {
      json[r'linked_account_id'] = null;
    }
    if (this.manualProgressMinor != null) {
      json[r'manual_progress_minor'] = this.manualProgressMinor;
    } else {
      json[r'manual_progress_minor'] = null;
    }
    if (this.expectedReturnBp != null) {
      json[r'expected_return_bp'] = this.expectedReturnBp;
    } else {
      json[r'expected_return_bp'] = null;
    }
      json[r'priority'] = this.priority;
      json[r'status'] = this.status;
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

  /// Returns a new [PersonalGoalOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalGoalOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalGoalOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalGoalOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalGoalOut(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        targetMinor: mapValueOfType<int>(json, r'target_minor')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        targetDate: mapDateTime(json, r'target_date', r''),
        trackingMode: PersonalGoalOutTrackingModeEnum.fromJson(json[r'tracking_mode'])!,
        linkedAccountId: mapValueOfType<String>(json, r'linked_account_id'),
        manualProgressMinor: mapValueOfType<int>(json, r'manual_progress_minor'),
        expectedReturnBp: mapValueOfType<int>(json, r'expected_return_bp'),
        priority: mapValueOfType<int>(json, r'priority')!,
        status: PersonalGoalOutStatusEnum.fromJson(json[r'status'])!,
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<PersonalGoalOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalGoalOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalGoalOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalGoalOut> mapFromJson(dynamic json) {
    final map = <String, PersonalGoalOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalGoalOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalGoalOut-objects as value to a dart map
  static Map<String, List<PersonalGoalOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalGoalOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalGoalOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
    'target_minor',
    'currency',
    'tracking_mode',
    'priority',
    'status',
    'created_at',
    'updated_at',
    'version',
  };
}


class PersonalGoalOutTrackingModeEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalGoalOutTrackingModeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const contribution = PersonalGoalOutTrackingModeEnum._(r'contribution');
  static const linkedBalance = PersonalGoalOutTrackingModeEnum._(r'linked_balance');
  static const manual = PersonalGoalOutTrackingModeEnum._(r'manual');

  /// List of all possible values in this [enum][PersonalGoalOutTrackingModeEnum].
  static const values = <PersonalGoalOutTrackingModeEnum>[
    contribution,
    linkedBalance,
    manual,
  ];

  static PersonalGoalOutTrackingModeEnum? fromJson(dynamic value) => PersonalGoalOutTrackingModeEnumTypeTransformer().decode(value);

  static List<PersonalGoalOutTrackingModeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalGoalOutTrackingModeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalGoalOutTrackingModeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalGoalOutTrackingModeEnum] to String,
/// and [decode] dynamic data back to [PersonalGoalOutTrackingModeEnum].
class PersonalGoalOutTrackingModeEnumTypeTransformer {
  factory PersonalGoalOutTrackingModeEnumTypeTransformer() => _instance ??= const PersonalGoalOutTrackingModeEnumTypeTransformer._();

  const PersonalGoalOutTrackingModeEnumTypeTransformer._();

  String encode(PersonalGoalOutTrackingModeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalGoalOutTrackingModeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalGoalOutTrackingModeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'contribution': return PersonalGoalOutTrackingModeEnum.contribution;
        case r'linked_balance': return PersonalGoalOutTrackingModeEnum.linkedBalance;
        case r'manual': return PersonalGoalOutTrackingModeEnum.manual;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalGoalOutTrackingModeEnumTypeTransformer] instance.
  static PersonalGoalOutTrackingModeEnumTypeTransformer? _instance;
}



class PersonalGoalOutStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalGoalOutStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const active = PersonalGoalOutStatusEnum._(r'active');
  static const paused = PersonalGoalOutStatusEnum._(r'paused');
  static const completed = PersonalGoalOutStatusEnum._(r'completed');
  static const archived = PersonalGoalOutStatusEnum._(r'archived');

  /// List of all possible values in this [enum][PersonalGoalOutStatusEnum].
  static const values = <PersonalGoalOutStatusEnum>[
    active,
    paused,
    completed,
    archived,
  ];

  static PersonalGoalOutStatusEnum? fromJson(dynamic value) => PersonalGoalOutStatusEnumTypeTransformer().decode(value);

  static List<PersonalGoalOutStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalGoalOutStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalGoalOutStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalGoalOutStatusEnum] to String,
/// and [decode] dynamic data back to [PersonalGoalOutStatusEnum].
class PersonalGoalOutStatusEnumTypeTransformer {
  factory PersonalGoalOutStatusEnumTypeTransformer() => _instance ??= const PersonalGoalOutStatusEnumTypeTransformer._();

  const PersonalGoalOutStatusEnumTypeTransformer._();

  String encode(PersonalGoalOutStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalGoalOutStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalGoalOutStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'active': return PersonalGoalOutStatusEnum.active;
        case r'paused': return PersonalGoalOutStatusEnum.paused;
        case r'completed': return PersonalGoalOutStatusEnum.completed;
        case r'archived': return PersonalGoalOutStatusEnum.archived;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalGoalOutStatusEnumTypeTransformer] instance.
  static PersonalGoalOutStatusEnumTypeTransformer? _instance;
}


