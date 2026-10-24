//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalGoalContributionOut {
  /// Returns a new [PersonalGoalContributionOut] instance.
  PersonalGoalContributionOut({
    required this.id,
    required this.goalId,
    this.transactionId,
    required this.amountMinor,
    required this.currency,
    required this.date,
    this.note,
    this.actingAdminId,
    required this.createdAt,
    this.deletedAt,
    required this.version,
  });

  String id;

  String goalId;

  String? transactionId;

  int amountMinor;

  String currency;

  DateTime date;

  String? note;

  String? actingAdminId;

  DateTime createdAt;

  DateTime? deletedAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalGoalContributionOut &&
    other.id == id &&
    other.goalId == goalId &&
    other.transactionId == transactionId &&
    other.amountMinor == amountMinor &&
    other.currency == currency &&
    other.date == date &&
    other.note == note &&
    other.actingAdminId == actingAdminId &&
    other.createdAt == createdAt &&
    other.deletedAt == deletedAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (goalId.hashCode) +
    (transactionId == null ? 0 : transactionId!.hashCode) +
    (amountMinor.hashCode) +
    (currency.hashCode) +
    (date.hashCode) +
    (note == null ? 0 : note!.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (createdAt.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'PersonalGoalContributionOut[id=$id, goalId=$goalId, transactionId=$transactionId, amountMinor=$amountMinor, currency=$currency, date=$date, note=$note, actingAdminId=$actingAdminId, createdAt=$createdAt, deletedAt=$deletedAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'goal_id'] = this.goalId;
    if (this.transactionId != null) {
      json[r'transaction_id'] = this.transactionId;
    } else {
      json[r'transaction_id'] = null;
    }
      json[r'amount_minor'] = this.amountMinor;
      json[r'currency'] = this.currency;
      json[r'date'] = _dateFormatter.format(this.date.toUtc());
    if (this.note != null) {
      json[r'note'] = this.note;
    } else {
      json[r'note'] = null;
    }
    if (this.actingAdminId != null) {
      json[r'acting_admin_id'] = this.actingAdminId;
    } else {
      json[r'acting_admin_id'] = null;
    }
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
    if (this.deletedAt != null) {
      json[r'deleted_at'] = this.deletedAt!.toUtc().toIso8601String();
    } else {
      json[r'deleted_at'] = null;
    }
      json[r'version'] = this.version;
    return json;
  }

  /// Returns a new [PersonalGoalContributionOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalGoalContributionOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalGoalContributionOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalGoalContributionOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalGoalContributionOut(
        id: mapValueOfType<String>(json, r'id')!,
        goalId: mapValueOfType<String>(json, r'goal_id')!,
        transactionId: mapValueOfType<String>(json, r'transaction_id'),
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        date: mapDateTime(json, r'date', r'')!,
        note: mapValueOfType<String>(json, r'note'),
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<PersonalGoalContributionOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalGoalContributionOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalGoalContributionOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalGoalContributionOut> mapFromJson(dynamic json) {
    final map = <String, PersonalGoalContributionOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalGoalContributionOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalGoalContributionOut-objects as value to a dart map
  static Map<String, List<PersonalGoalContributionOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalGoalContributionOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalGoalContributionOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'goal_id',
    'amount_minor',
    'currency',
    'date',
    'created_at',
    'version',
  };
}

