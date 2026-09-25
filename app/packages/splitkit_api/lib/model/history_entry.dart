//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class HistoryEntry {
  /// Returns a new [HistoryEntry] instance.
  HistoryEntry({
    required this.action,
    this.person,
    this.admin,
    required this.at,
    this.diff = const {},
  });

  String action;

  UserBrief? person;

  UserBrief? admin;

  DateTime at;

  Map<String, Object> diff;

  @override
  bool operator ==(Object other) => identical(this, other) || other is HistoryEntry &&
    other.action == action &&
    other.person == person &&
    other.admin == admin &&
    other.at == at &&
    _deepEquality.equals(other.diff, diff);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (person == null ? 0 : person!.hashCode) +
    (admin == null ? 0 : admin!.hashCode) +
    (at.hashCode) +
    (diff.hashCode);

  @override
  String toString() => 'HistoryEntry[action=$action, person=$person, admin=$admin, at=$at, diff=$diff]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'action'] = this.action;
    if (this.person != null) {
      json[r'person'] = this.person;
    } else {
      json[r'person'] = null;
    }
    if (this.admin != null) {
      json[r'admin'] = this.admin;
    } else {
      json[r'admin'] = null;
    }
      json[r'at'] = this.at.toUtc().toIso8601String();
      json[r'diff'] = this.diff;
    return json;
  }

  /// Returns a new [HistoryEntry] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static HistoryEntry? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "HistoryEntry[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "HistoryEntry[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return HistoryEntry(
        action: mapValueOfType<String>(json, r'action')!,
        person: UserBrief.fromJson(json[r'person']),
        admin: UserBrief.fromJson(json[r'admin']),
        at: mapDateTime(json, r'at', r'')!,
        diff: mapCastOfType<String, Object>(json, r'diff')!,
      );
    }
    return null;
  }

  static List<HistoryEntry> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <HistoryEntry>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = HistoryEntry.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, HistoryEntry> mapFromJson(dynamic json) {
    final map = <String, HistoryEntry>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = HistoryEntry.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of HistoryEntry-objects as value to a dart map
  static Map<String, List<HistoryEntry>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<HistoryEntry>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = HistoryEntry.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
    'at',
    'diff',
  };
}

