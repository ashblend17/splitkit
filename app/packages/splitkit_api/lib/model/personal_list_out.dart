//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalListOut {
  /// Returns a new [PersonalListOut] instance.
  PersonalListOut({
    this.items = const [],
    required this.spentMinor,
    required this.incomeMinor,
    required this.count,
  });

  List<PersonalTxnOut> items;

  int spentMinor;

  int incomeMinor;

  int count;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalListOut &&
    _deepEquality.equals(other.items, items) &&
    other.spentMinor == spentMinor &&
    other.incomeMinor == incomeMinor &&
    other.count == count;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (items.hashCode) +
    (spentMinor.hashCode) +
    (incomeMinor.hashCode) +
    (count.hashCode);

  @override
  String toString() => 'PersonalListOut[items=$items, spentMinor=$spentMinor, incomeMinor=$incomeMinor, count=$count]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'items'] = this.items;
      json[r'spent_minor'] = this.spentMinor;
      json[r'income_minor'] = this.incomeMinor;
      json[r'count'] = this.count;
    return json;
  }

  /// Returns a new [PersonalListOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalListOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalListOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalListOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalListOut(
        items: PersonalTxnOut.listFromJson(json[r'items']),
        spentMinor: mapValueOfType<int>(json, r'spent_minor')!,
        incomeMinor: mapValueOfType<int>(json, r'income_minor')!,
        count: mapValueOfType<int>(json, r'count')!,
      );
    }
    return null;
  }

  static List<PersonalListOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalListOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalListOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalListOut> mapFromJson(dynamic json) {
    final map = <String, PersonalListOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalListOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalListOut-objects as value to a dart map
  static Map<String, List<PersonalListOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalListOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalListOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'items',
    'spent_minor',
    'income_minor',
    'count',
  };
}

