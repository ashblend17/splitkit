//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportPreviewOut {
  /// Returns a new [ImportPreviewOut] instance.
  ImportPreviewOut({
    required this.fileName,
    required this.groupName,
    required this.currency,
    this.people = const [],
    this.candidates = const [],
    this.categories = const [],
    this.categoryOptions = const [],
    this.rows = const [],
    required this.totals,
  });

  String fileName;

  String groupName;

  String currency;

  List<PersonOut> people;

  List<UserBrief> candidates;

  List<CategoryMatchOut> categories;

  List<CategoryOptionOut> categoryOptions;

  List<ImportRowOut> rows;

  ImportTotalsOut totals;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ImportPreviewOut &&
    other.fileName == fileName &&
    other.groupName == groupName &&
    other.currency == currency &&
    _deepEquality.equals(other.people, people) &&
    _deepEquality.equals(other.candidates, candidates) &&
    _deepEquality.equals(other.categories, categories) &&
    _deepEquality.equals(other.categoryOptions, categoryOptions) &&
    _deepEquality.equals(other.rows, rows) &&
    other.totals == totals;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (fileName.hashCode) +
    (groupName.hashCode) +
    (currency.hashCode) +
    (people.hashCode) +
    (candidates.hashCode) +
    (categories.hashCode) +
    (categoryOptions.hashCode) +
    (rows.hashCode) +
    (totals.hashCode);

  @override
  String toString() => 'ImportPreviewOut[fileName=$fileName, groupName=$groupName, currency=$currency, people=$people, candidates=$candidates, categories=$categories, categoryOptions=$categoryOptions, rows=$rows, totals=$totals]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'file_name'] = this.fileName;
      json[r'group_name'] = this.groupName;
      json[r'currency'] = this.currency;
      json[r'people'] = this.people;
      json[r'candidates'] = this.candidates;
      json[r'categories'] = this.categories;
      json[r'category_options'] = this.categoryOptions;
      json[r'rows'] = this.rows;
      json[r'totals'] = this.totals;
    return json;
  }

  /// Returns a new [ImportPreviewOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportPreviewOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ImportPreviewOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ImportPreviewOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ImportPreviewOut(
        fileName: mapValueOfType<String>(json, r'file_name')!,
        groupName: mapValueOfType<String>(json, r'group_name')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        people: PersonOut.listFromJson(json[r'people']),
        candidates: UserBrief.listFromJson(json[r'candidates']),
        categories: CategoryMatchOut.listFromJson(json[r'categories']),
        categoryOptions: CategoryOptionOut.listFromJson(json[r'category_options']),
        rows: ImportRowOut.listFromJson(json[r'rows']),
        totals: ImportTotalsOut.fromJson(json[r'totals'])!,
      );
    }
    return null;
  }

  static List<ImportPreviewOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ImportPreviewOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportPreviewOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportPreviewOut> mapFromJson(dynamic json) {
    final map = <String, ImportPreviewOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportPreviewOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportPreviewOut-objects as value to a dart map
  static Map<String, List<ImportPreviewOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ImportPreviewOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportPreviewOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'file_name',
    'group_name',
    'currency',
    'people',
    'candidates',
    'categories',
    'category_options',
    'rows',
    'totals',
  };
}

