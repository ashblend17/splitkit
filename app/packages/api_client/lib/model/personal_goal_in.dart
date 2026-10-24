//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalGoalIn {
  /// Returns a new [PersonalGoalIn] instance.
  PersonalGoalIn({
    this.id,
    this.version,
    required this.name,
    required this.targetMinor,
    this.targetDate,
    required this.trackingMode,
    this.linkedAccountId,
    this.manualProgressMinor,
    this.expectedReturnBp,
    this.priority = 0,
    this.status,
  });

  String? id;

  int? version;

  String name;

  /// Maximum value: 9999999999
  int targetMinor;

  DateTime? targetDate;

  PersonalGoalInTrackingModeEnum trackingMode;

  String? linkedAccountId;

  /// Minimum value: 0
  /// Maximum value: 1000000000000000
  int? manualProgressMinor;

  /// Minimum value: 0
  /// Maximum value: 10000
  int? expectedReturnBp;

  /// Minimum value: 0
  /// Maximum value: 1000
  int priority;

  PersonalGoalInStatusEnum? status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalGoalIn &&
    other.id == id &&
    other.version == version &&
    other.name == name &&
    other.targetMinor == targetMinor &&
    other.targetDate == targetDate &&
    other.trackingMode == trackingMode &&
    other.linkedAccountId == linkedAccountId &&
    other.manualProgressMinor == manualProgressMinor &&
    other.expectedReturnBp == expectedReturnBp &&
    other.priority == priority &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (name.hashCode) +
    (targetMinor.hashCode) +
    (targetDate == null ? 0 : targetDate!.hashCode) +
    (trackingMode.hashCode) +
    (linkedAccountId == null ? 0 : linkedAccountId!.hashCode) +
    (manualProgressMinor == null ? 0 : manualProgressMinor!.hashCode) +
    (expectedReturnBp == null ? 0 : expectedReturnBp!.hashCode) +
    (priority.hashCode) +
    (status == null ? 0 : status!.hashCode);

  @override
  String toString() => 'PersonalGoalIn[id=$id, version=$version, name=$name, targetMinor=$targetMinor, targetDate=$targetDate, trackingMode=$trackingMode, linkedAccountId=$linkedAccountId, manualProgressMinor=$manualProgressMinor, expectedReturnBp=$expectedReturnBp, priority=$priority, status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.version != null) {
      json[r'version'] = this.version;
    } else {
      json[r'version'] = null;
    }
      json[r'name'] = this.name;
      json[r'target_minor'] = this.targetMinor;
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
    if (this.status != null) {
      json[r'status'] = this.status;
    } else {
      json[r'status'] = null;
    }
    return json;
  }

  /// Returns a new [PersonalGoalIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalGoalIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalGoalIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalGoalIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalGoalIn(
        id: mapValueOfType<String>(json, r'id'),
        version: mapValueOfType<int>(json, r'version'),
        name: mapValueOfType<String>(json, r'name')!,
        targetMinor: mapValueOfType<int>(json, r'target_minor')!,
        targetDate: mapDateTime(json, r'target_date', r''),
        trackingMode: PersonalGoalInTrackingModeEnum.fromJson(json[r'tracking_mode'])!,
        linkedAccountId: mapValueOfType<String>(json, r'linked_account_id'),
        manualProgressMinor: mapValueOfType<int>(json, r'manual_progress_minor'),
        expectedReturnBp: mapValueOfType<int>(json, r'expected_return_bp'),
        priority: mapValueOfType<int>(json, r'priority') ?? 0,
        status: PersonalGoalInStatusEnum.fromJson(json[r'status']),
      );
    }
    return null;
  }

  static List<PersonalGoalIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalGoalIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalGoalIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalGoalIn> mapFromJson(dynamic json) {
    final map = <String, PersonalGoalIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalGoalIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalGoalIn-objects as value to a dart map
  static Map<String, List<PersonalGoalIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalGoalIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalGoalIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'name',
    'target_minor',
    'tracking_mode',
  };
}


class PersonalGoalInTrackingModeEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalGoalInTrackingModeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const contribution = PersonalGoalInTrackingModeEnum._(r'contribution');
  static const linkedBalance = PersonalGoalInTrackingModeEnum._(r'linked_balance');
  static const manual = PersonalGoalInTrackingModeEnum._(r'manual');

  /// List of all possible values in this [enum][PersonalGoalInTrackingModeEnum].
  static const values = <PersonalGoalInTrackingModeEnum>[
    contribution,
    linkedBalance,
    manual,
  ];

  static PersonalGoalInTrackingModeEnum? fromJson(dynamic value) => PersonalGoalInTrackingModeEnumTypeTransformer().decode(value);

  static List<PersonalGoalInTrackingModeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalGoalInTrackingModeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalGoalInTrackingModeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalGoalInTrackingModeEnum] to String,
/// and [decode] dynamic data back to [PersonalGoalInTrackingModeEnum].
class PersonalGoalInTrackingModeEnumTypeTransformer {
  factory PersonalGoalInTrackingModeEnumTypeTransformer() => _instance ??= const PersonalGoalInTrackingModeEnumTypeTransformer._();

  const PersonalGoalInTrackingModeEnumTypeTransformer._();

  String encode(PersonalGoalInTrackingModeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalGoalInTrackingModeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalGoalInTrackingModeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'contribution': return PersonalGoalInTrackingModeEnum.contribution;
        case r'linked_balance': return PersonalGoalInTrackingModeEnum.linkedBalance;
        case r'manual': return PersonalGoalInTrackingModeEnum.manual;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalGoalInTrackingModeEnumTypeTransformer] instance.
  static PersonalGoalInTrackingModeEnumTypeTransformer? _instance;
}



class PersonalGoalInStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalGoalInStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const active = PersonalGoalInStatusEnum._(r'active');
  static const paused = PersonalGoalInStatusEnum._(r'paused');
  static const completed = PersonalGoalInStatusEnum._(r'completed');
  static const archived = PersonalGoalInStatusEnum._(r'archived');

  /// List of all possible values in this [enum][PersonalGoalInStatusEnum].
  static const values = <PersonalGoalInStatusEnum>[
    active,
    paused,
    completed,
    archived,
  ];

  static PersonalGoalInStatusEnum? fromJson(dynamic value) => PersonalGoalInStatusEnumTypeTransformer().decode(value);

  static List<PersonalGoalInStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalGoalInStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalGoalInStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalGoalInStatusEnum] to String,
/// and [decode] dynamic data back to [PersonalGoalInStatusEnum].
class PersonalGoalInStatusEnumTypeTransformer {
  factory PersonalGoalInStatusEnumTypeTransformer() => _instance ??= const PersonalGoalInStatusEnumTypeTransformer._();

  const PersonalGoalInStatusEnumTypeTransformer._();

  String encode(PersonalGoalInStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalGoalInStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalGoalInStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'active': return PersonalGoalInStatusEnum.active;
        case r'paused': return PersonalGoalInStatusEnum.paused;
        case r'completed': return PersonalGoalInStatusEnum.completed;
        case r'archived': return PersonalGoalInStatusEnum.archived;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalGoalInStatusEnumTypeTransformer] instance.
  static PersonalGoalInStatusEnumTypeTransformer? _instance;
}


