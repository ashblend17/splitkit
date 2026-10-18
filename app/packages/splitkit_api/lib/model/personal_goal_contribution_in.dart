//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalGoalContributionIn {
  /// Returns a new [PersonalGoalContributionIn] instance.
  PersonalGoalContributionIn({
    this.id,
    this.version,
    required this.goalId,
    required this.amountMinor,
    required this.date,
    this.transactionId,
    this.note,
  });

  String? id;

  int? version;

  String goalId;

  /// Maximum value: 9999999999
  int amountMinor;

  DateTime date;

  String? transactionId;

  String? note;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalGoalContributionIn &&
    other.id == id &&
    other.version == version &&
    other.goalId == goalId &&
    other.amountMinor == amountMinor &&
    other.date == date &&
    other.transactionId == transactionId &&
    other.note == note;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (goalId.hashCode) +
    (amountMinor.hashCode) +
    (date.hashCode) +
    (transactionId == null ? 0 : transactionId!.hashCode) +
    (note == null ? 0 : note!.hashCode);

  @override
  String toString() => 'PersonalGoalContributionIn[id=$id, version=$version, goalId=$goalId, amountMinor=$amountMinor, date=$date, transactionId=$transactionId, note=$note]';

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
      json[r'goal_id'] = this.goalId;
      json[r'amount_minor'] = this.amountMinor;
      json[r'date'] = _dateFormatter.format(this.date.toUtc());
    if (this.transactionId != null) {
      json[r'transaction_id'] = this.transactionId;
    } else {
      json[r'transaction_id'] = null;
    }
    if (this.note != null) {
      json[r'note'] = this.note;
    } else {
      json[r'note'] = null;
    }
    return json;
  }

  /// Returns a new [PersonalGoalContributionIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalGoalContributionIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalGoalContributionIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalGoalContributionIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalGoalContributionIn(
        id: mapValueOfType<String>(json, r'id'),
        version: mapValueOfType<int>(json, r'version'),
        goalId: mapValueOfType<String>(json, r'goal_id')!,
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
        date: mapDateTime(json, r'date', r'')!,
        transactionId: mapValueOfType<String>(json, r'transaction_id'),
        note: mapValueOfType<String>(json, r'note'),
      );
    }
    return null;
  }

  static List<PersonalGoalContributionIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalGoalContributionIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalGoalContributionIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalGoalContributionIn> mapFromJson(dynamic json) {
    final map = <String, PersonalGoalContributionIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalGoalContributionIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalGoalContributionIn-objects as value to a dart map
  static Map<String, List<PersonalGoalContributionIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalGoalContributionIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalGoalContributionIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'goal_id',
    'amount_minor',
    'date',
  };
}

