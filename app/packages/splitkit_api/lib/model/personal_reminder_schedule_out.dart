//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalReminderScheduleOut {
  /// Returns a new [PersonalReminderScheduleOut] instance.
  PersonalReminderScheduleOut({
    required this.id,
    this.goalId,
    this.holdingId,
    required this.dayOfMonth,
    this.amountMinor,
    required this.currency,
    required this.active,
    this.actingAdminId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
  });

  String id;

  String? goalId;

  String? holdingId;

  int dayOfMonth;

  int? amountMinor;

  String currency;

  bool active;

  String? actingAdminId;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? deletedAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalReminderScheduleOut &&
    other.id == id &&
    other.goalId == goalId &&
    other.holdingId == holdingId &&
    other.dayOfMonth == dayOfMonth &&
    other.amountMinor == amountMinor &&
    other.currency == currency &&
    other.active == active &&
    other.actingAdminId == actingAdminId &&
    other.createdAt == createdAt &&
    other.updatedAt == updatedAt &&
    other.deletedAt == deletedAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (goalId == null ? 0 : goalId!.hashCode) +
    (holdingId == null ? 0 : holdingId!.hashCode) +
    (dayOfMonth.hashCode) +
    (amountMinor == null ? 0 : amountMinor!.hashCode) +
    (currency.hashCode) +
    (active.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (createdAt.hashCode) +
    (updatedAt.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'PersonalReminderScheduleOut[id=$id, goalId=$goalId, holdingId=$holdingId, dayOfMonth=$dayOfMonth, amountMinor=$amountMinor, currency=$currency, active=$active, actingAdminId=$actingAdminId, createdAt=$createdAt, updatedAt=$updatedAt, deletedAt=$deletedAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
    if (this.goalId != null) {
      json[r'goal_id'] = this.goalId;
    } else {
      json[r'goal_id'] = null;
    }
    if (this.holdingId != null) {
      json[r'holding_id'] = this.holdingId;
    } else {
      json[r'holding_id'] = null;
    }
      json[r'day_of_month'] = this.dayOfMonth;
    if (this.amountMinor != null) {
      json[r'amount_minor'] = this.amountMinor;
    } else {
      json[r'amount_minor'] = null;
    }
      json[r'currency'] = this.currency;
      json[r'active'] = this.active;
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

  /// Returns a new [PersonalReminderScheduleOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalReminderScheduleOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalReminderScheduleOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalReminderScheduleOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalReminderScheduleOut(
        id: mapValueOfType<String>(json, r'id')!,
        goalId: mapValueOfType<String>(json, r'goal_id'),
        holdingId: mapValueOfType<String>(json, r'holding_id'),
        dayOfMonth: mapValueOfType<int>(json, r'day_of_month')!,
        amountMinor: mapValueOfType<int>(json, r'amount_minor'),
        currency: mapValueOfType<String>(json, r'currency')!,
        active: mapValueOfType<bool>(json, r'active')!,
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<PersonalReminderScheduleOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalReminderScheduleOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalReminderScheduleOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalReminderScheduleOut> mapFromJson(dynamic json) {
    final map = <String, PersonalReminderScheduleOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalReminderScheduleOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalReminderScheduleOut-objects as value to a dart map
  static Map<String, List<PersonalReminderScheduleOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalReminderScheduleOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalReminderScheduleOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'day_of_month',
    'currency',
    'active',
    'created_at',
    'updated_at',
    'version',
  };
}

