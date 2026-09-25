//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalSummaryOut {
  /// Returns a new [PersonalSummaryOut] instance.
  PersonalSummaryOut({
    required this.month,
    required this.monthLabel,
    required this.currency,
    required this.spentMinor,
    required this.incomeMinor,
    required this.leftOverMinor,
    required this.groupShareMinor,
    this.byCategory = const [],
  });

  String month;

  String monthLabel;

  String currency;

  int spentMinor;

  int incomeMinor;

  int leftOverMinor;

  int groupShareMinor;

  List<CategoryTotal> byCategory;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalSummaryOut &&
    other.month == month &&
    other.monthLabel == monthLabel &&
    other.currency == currency &&
    other.spentMinor == spentMinor &&
    other.incomeMinor == incomeMinor &&
    other.leftOverMinor == leftOverMinor &&
    other.groupShareMinor == groupShareMinor &&
    _deepEquality.equals(other.byCategory, byCategory);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (month.hashCode) +
    (monthLabel.hashCode) +
    (currency.hashCode) +
    (spentMinor.hashCode) +
    (incomeMinor.hashCode) +
    (leftOverMinor.hashCode) +
    (groupShareMinor.hashCode) +
    (byCategory.hashCode);

  @override
  String toString() => 'PersonalSummaryOut[month=$month, monthLabel=$monthLabel, currency=$currency, spentMinor=$spentMinor, incomeMinor=$incomeMinor, leftOverMinor=$leftOverMinor, groupShareMinor=$groupShareMinor, byCategory=$byCategory]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'month'] = this.month;
      json[r'month_label'] = this.monthLabel;
      json[r'currency'] = this.currency;
      json[r'spent_minor'] = this.spentMinor;
      json[r'income_minor'] = this.incomeMinor;
      json[r'left_over_minor'] = this.leftOverMinor;
      json[r'group_share_minor'] = this.groupShareMinor;
      json[r'by_category'] = this.byCategory;
    return json;
  }

  /// Returns a new [PersonalSummaryOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalSummaryOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalSummaryOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalSummaryOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalSummaryOut(
        month: mapValueOfType<String>(json, r'month')!,
        monthLabel: mapValueOfType<String>(json, r'month_label')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        spentMinor: mapValueOfType<int>(json, r'spent_minor')!,
        incomeMinor: mapValueOfType<int>(json, r'income_minor')!,
        leftOverMinor: mapValueOfType<int>(json, r'left_over_minor')!,
        groupShareMinor: mapValueOfType<int>(json, r'group_share_minor')!,
        byCategory: CategoryTotal.listFromJson(json[r'by_category']),
      );
    }
    return null;
  }

  static List<PersonalSummaryOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalSummaryOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalSummaryOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalSummaryOut> mapFromJson(dynamic json) {
    final map = <String, PersonalSummaryOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalSummaryOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalSummaryOut-objects as value to a dart map
  static Map<String, List<PersonalSummaryOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalSummaryOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalSummaryOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'month',
    'month_label',
    'currency',
    'spent_minor',
    'income_minor',
    'left_over_minor',
    'group_share_minor',
    'by_category',
  };
}

