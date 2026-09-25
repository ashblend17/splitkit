//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReviewItemOut {
  /// Returns a new [ReviewItemOut] instance.
  ReviewItemOut({
    required this.title,
    required this.why,
    this.expenseId,
  });

  String title;

  String why;

  String? expenseId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReviewItemOut &&
    other.title == title &&
    other.why == why &&
    other.expenseId == expenseId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (title.hashCode) +
    (why.hashCode) +
    (expenseId == null ? 0 : expenseId!.hashCode);

  @override
  String toString() => 'ReviewItemOut[title=$title, why=$why, expenseId=$expenseId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'title'] = this.title;
      json[r'why'] = this.why;
    if (this.expenseId != null) {
      json[r'expense_id'] = this.expenseId;
    } else {
      json[r'expense_id'] = null;
    }
    return json;
  }

  /// Returns a new [ReviewItemOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReviewItemOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ReviewItemOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ReviewItemOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ReviewItemOut(
        title: mapValueOfType<String>(json, r'title')!,
        why: mapValueOfType<String>(json, r'why')!,
        expenseId: mapValueOfType<String>(json, r'expense_id'),
      );
    }
    return null;
  }

  static List<ReviewItemOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReviewItemOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReviewItemOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReviewItemOut> mapFromJson(dynamic json) {
    final map = <String, ReviewItemOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReviewItemOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReviewItemOut-objects as value to a dart map
  static Map<String, List<ReviewItemOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReviewItemOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReviewItemOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'title',
    'why',
  };
}

