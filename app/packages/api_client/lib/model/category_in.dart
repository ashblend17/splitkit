//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CategoryIn {
  /// Returns a new [CategoryIn] instance.
  CategoryIn({
    this.id,
    required this.label,
    this.icon = 'other',
    required this.scope,
  });

  String? id;

  String label;

  String icon;

  CategoryInScopeEnum scope;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CategoryIn &&
    other.id == id &&
    other.label == label &&
    other.icon == icon &&
    other.scope == scope;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (label.hashCode) +
    (icon.hashCode) +
    (scope.hashCode);

  @override
  String toString() => 'CategoryIn[id=$id, label=$label, icon=$icon, scope=$scope]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
      json[r'label'] = this.label;
      json[r'icon'] = this.icon;
      json[r'scope'] = this.scope;
    return json;
  }

  /// Returns a new [CategoryIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CategoryIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CategoryIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CategoryIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CategoryIn(
        id: mapValueOfType<String>(json, r'id'),
        label: mapValueOfType<String>(json, r'label')!,
        icon: mapValueOfType<String>(json, r'icon') ?? 'other',
        scope: CategoryInScopeEnum.fromJson(json[r'scope'])!,
      );
    }
    return null;
  }

  static List<CategoryIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CategoryIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CategoryIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CategoryIn> mapFromJson(dynamic json) {
    final map = <String, CategoryIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CategoryIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CategoryIn-objects as value to a dart map
  static Map<String, List<CategoryIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CategoryIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CategoryIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'label',
    'scope',
  };
}


class CategoryInScopeEnum {
  /// Instantiate a new enum with the provided [value].
  const CategoryInScopeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const group = CategoryInScopeEnum._(r'group');
  static const personal = CategoryInScopeEnum._(r'personal');
  static const all = CategoryInScopeEnum._(r'all');

  /// List of all possible values in this [enum][CategoryInScopeEnum].
  static const values = <CategoryInScopeEnum>[
    group,
    personal,
    all,
  ];

  static CategoryInScopeEnum? fromJson(dynamic value) => CategoryInScopeEnumTypeTransformer().decode(value);

  static List<CategoryInScopeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CategoryInScopeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CategoryInScopeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CategoryInScopeEnum] to String,
/// and [decode] dynamic data back to [CategoryInScopeEnum].
class CategoryInScopeEnumTypeTransformer {
  factory CategoryInScopeEnumTypeTransformer() => _instance ??= const CategoryInScopeEnumTypeTransformer._();

  const CategoryInScopeEnumTypeTransformer._();

  String encode(CategoryInScopeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a CategoryInScopeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CategoryInScopeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'group': return CategoryInScopeEnum.group;
        case r'personal': return CategoryInScopeEnum.personal;
        case r'all': return CategoryInScopeEnum.all;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [CategoryInScopeEnumTypeTransformer] instance.
  static CategoryInScopeEnumTypeTransformer? _instance;
}


