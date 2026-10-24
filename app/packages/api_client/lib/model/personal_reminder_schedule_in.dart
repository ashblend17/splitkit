//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalReminderScheduleIn {
  /// Returns a new [PersonalReminderScheduleIn] instance.
  PersonalReminderScheduleIn({
    this.id,
    this.version,
    required this.dayOfMonth,
    this.goalId,
    this.holdingId,
    this.amountMinor,
    this.active = true,
  });

  String? id;

  int? version;

  /// Minimum value: 1
  /// Maximum value: 28
  int dayOfMonth;

  String? goalId;

  String? holdingId;

  /// Maximum value: 9999999999
  int? amountMinor;

  bool active;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalReminderScheduleIn &&
    other.id == id &&
    other.version == version &&
    other.dayOfMonth == dayOfMonth &&
    other.goalId == goalId &&
    other.holdingId == holdingId &&
    other.amountMinor == amountMinor &&
    other.active == active;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (dayOfMonth.hashCode) +
    (goalId == null ? 0 : goalId!.hashCode) +
    (holdingId == null ? 0 : holdingId!.hashCode) +
    (amountMinor == null ? 0 : amountMinor!.hashCode) +
    (active.hashCode);

  @override
  String toString() => 'PersonalReminderScheduleIn[id=$id, version=$version, dayOfMonth=$dayOfMonth, goalId=$goalId, holdingId=$holdingId, amountMinor=$amountMinor, active=$active]';

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
      json[r'day_of_month'] = this.dayOfMonth;
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
    if (this.amountMinor != null) {
      json[r'amount_minor'] = this.amountMinor;
    } else {
      json[r'amount_minor'] = null;
    }
      json[r'active'] = this.active;
    return json;
  }

  /// Returns a new [PersonalReminderScheduleIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalReminderScheduleIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalReminderScheduleIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalReminderScheduleIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalReminderScheduleIn(
        id: mapValueOfType<String>(json, r'id'),
        version: mapValueOfType<int>(json, r'version'),
        dayOfMonth: mapValueOfType<int>(json, r'day_of_month')!,
        goalId: mapValueOfType<String>(json, r'goal_id'),
        holdingId: mapValueOfType<String>(json, r'holding_id'),
        amountMinor: mapValueOfType<int>(json, r'amount_minor'),
        active: mapValueOfType<bool>(json, r'active') ?? true,
      );
    }
    return null;
  }

  static List<PersonalReminderScheduleIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalReminderScheduleIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalReminderScheduleIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalReminderScheduleIn> mapFromJson(dynamic json) {
    final map = <String, PersonalReminderScheduleIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalReminderScheduleIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalReminderScheduleIn-objects as value to a dart map
  static Map<String, List<PersonalReminderScheduleIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalReminderScheduleIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalReminderScheduleIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'day_of_month',
  };
}

