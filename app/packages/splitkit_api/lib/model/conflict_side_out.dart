//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ConflictSideOut {
  /// Returns a new [ConflictSideOut] instance.
  ConflictSideOut({
    required this.title,
    required this.summary,
    required this.deleted,
  });

  String title;

  String summary;

  bool deleted;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ConflictSideOut &&
    other.title == title &&
    other.summary == summary &&
    other.deleted == deleted;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (title.hashCode) +
    (summary.hashCode) +
    (deleted.hashCode);

  @override
  String toString() => 'ConflictSideOut[title=$title, summary=$summary, deleted=$deleted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'title'] = this.title;
      json[r'summary'] = this.summary;
      json[r'deleted'] = this.deleted;
    return json;
  }

  /// Returns a new [ConflictSideOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ConflictSideOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ConflictSideOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ConflictSideOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ConflictSideOut(
        title: mapValueOfType<String>(json, r'title')!,
        summary: mapValueOfType<String>(json, r'summary')!,
        deleted: mapValueOfType<bool>(json, r'deleted')!,
      );
    }
    return null;
  }

  static List<ConflictSideOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ConflictSideOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ConflictSideOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ConflictSideOut> mapFromJson(dynamic json) {
    final map = <String, ConflictSideOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ConflictSideOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ConflictSideOut-objects as value to a dart map
  static Map<String, List<ConflictSideOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ConflictSideOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ConflictSideOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'title',
    'summary',
    'deleted',
  };
}

