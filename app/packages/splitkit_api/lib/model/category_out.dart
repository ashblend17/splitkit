//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CategoryOut {
  /// Returns a new [CategoryOut] instance.
  CategoryOut({
    required this.id,
    required this.key,
    required this.label,
    required this.icon,
    required this.scope,
    this.ownerId,
  });

  String id;

  String key;

  String label;

  String icon;

  String scope;

  String? ownerId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CategoryOut &&
    other.id == id &&
    other.key == key &&
    other.label == label &&
    other.icon == icon &&
    other.scope == scope &&
    other.ownerId == ownerId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (key.hashCode) +
    (label.hashCode) +
    (icon.hashCode) +
    (scope.hashCode) +
    (ownerId == null ? 0 : ownerId!.hashCode);

  @override
  String toString() => 'CategoryOut[id=$id, key=$key, label=$label, icon=$icon, scope=$scope, ownerId=$ownerId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'key'] = this.key;
      json[r'label'] = this.label;
      json[r'icon'] = this.icon;
      json[r'scope'] = this.scope;
    if (this.ownerId != null) {
      json[r'owner_id'] = this.ownerId;
    } else {
      json[r'owner_id'] = null;
    }
    return json;
  }

  /// Returns a new [CategoryOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CategoryOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CategoryOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CategoryOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CategoryOut(
        id: mapValueOfType<String>(json, r'id')!,
        key: mapValueOfType<String>(json, r'key')!,
        label: mapValueOfType<String>(json, r'label')!,
        icon: mapValueOfType<String>(json, r'icon')!,
        scope: mapValueOfType<String>(json, r'scope')!,
        ownerId: mapValueOfType<String>(json, r'owner_id'),
      );
    }
    return null;
  }

  static List<CategoryOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CategoryOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CategoryOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CategoryOut> mapFromJson(dynamic json) {
    final map = <String, CategoryOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CategoryOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CategoryOut-objects as value to a dart map
  static Map<String, List<CategoryOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CategoryOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CategoryOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'key',
    'label',
    'icon',
    'scope',
  };
}

