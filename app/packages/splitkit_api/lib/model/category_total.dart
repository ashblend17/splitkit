//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CategoryTotal {
  /// Returns a new [CategoryTotal] instance.
  CategoryTotal({
    this.category,
    required this.label,
    required this.amountMinor,
  });

  CategoryOut? category;

  String label;

  int amountMinor;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CategoryTotal &&
    other.category == category &&
    other.label == label &&
    other.amountMinor == amountMinor;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (category == null ? 0 : category!.hashCode) +
    (label.hashCode) +
    (amountMinor.hashCode);

  @override
  String toString() => 'CategoryTotal[category=$category, label=$label, amountMinor=$amountMinor]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.category != null) {
      json[r'category'] = this.category;
    } else {
      json[r'category'] = null;
    }
      json[r'label'] = this.label;
      json[r'amount_minor'] = this.amountMinor;
    return json;
  }

  /// Returns a new [CategoryTotal] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CategoryTotal? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CategoryTotal[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CategoryTotal[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CategoryTotal(
        category: CategoryOut.fromJson(json[r'category']),
        label: mapValueOfType<String>(json, r'label')!,
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
      );
    }
    return null;
  }

  static List<CategoryTotal> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CategoryTotal>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CategoryTotal.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CategoryTotal> mapFromJson(dynamic json) {
    final map = <String, CategoryTotal>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CategoryTotal.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CategoryTotal-objects as value to a dart map
  static Map<String, List<CategoryTotal>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CategoryTotal>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CategoryTotal.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'label',
    'amount_minor',
  };
}

