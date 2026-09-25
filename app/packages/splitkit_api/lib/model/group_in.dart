//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupIn {
  /// Returns a new [GroupIn] instance.
  GroupIn({
    this.id,
    required this.name,
    required this.icon,
    required this.currency,
  });

  String? id;

  String name;

  GroupInIconEnum icon;

  GroupInCurrencyEnum currency;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GroupIn &&
    other.id == id &&
    other.name == name &&
    other.icon == icon &&
    other.currency == currency;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (name.hashCode) +
    (icon.hashCode) +
    (currency.hashCode);

  @override
  String toString() => 'GroupIn[id=$id, name=$name, icon=$icon, currency=$currency]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
      json[r'name'] = this.name;
      json[r'icon'] = this.icon;
      json[r'currency'] = this.currency;
    return json;
  }

  /// Returns a new [GroupIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GroupIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GroupIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GroupIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GroupIn(
        id: mapValueOfType<String>(json, r'id'),
        name: mapValueOfType<String>(json, r'name')!,
        icon: GroupInIconEnum.fromJson(json[r'icon'])!,
        currency: GroupInCurrencyEnum.fromJson(json[r'currency'])!,
      );
    }
    return null;
  }

  static List<GroupIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GroupIn> mapFromJson(dynamic json) {
    final map = <String, GroupIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GroupIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GroupIn-objects as value to a dart map
  static Map<String, List<GroupIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GroupIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GroupIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'name',
    'icon',
    'currency',
  };
}


class GroupInIconEnum {
  /// Instantiate a new enum with the provided [value].
  const GroupInIconEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const groups = GroupInIconEnum._(r'groups');
  static const travel = GroupInIconEnum._(r'travel');
  static const rent = GroupInIconEnum._(r'rent');
  static const food = GroupInIconEnum._(r'food');
  static const home = GroupInIconEnum._(r'home');
  static const shopping = GroupInIconEnum._(r'shopping');
  static const entertainment = GroupInIconEnum._(r'entertainment');
  static const education = GroupInIconEnum._(r'education');
  static const other = GroupInIconEnum._(r'other');

  /// List of all possible values in this [enum][GroupInIconEnum].
  static const values = <GroupInIconEnum>[
    groups,
    travel,
    rent,
    food,
    home,
    shopping,
    entertainment,
    education,
    other,
  ];

  static GroupInIconEnum? fromJson(dynamic value) => GroupInIconEnumTypeTransformer().decode(value);

  static List<GroupInIconEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupInIconEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupInIconEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [GroupInIconEnum] to String,
/// and [decode] dynamic data back to [GroupInIconEnum].
class GroupInIconEnumTypeTransformer {
  factory GroupInIconEnumTypeTransformer() => _instance ??= const GroupInIconEnumTypeTransformer._();

  const GroupInIconEnumTypeTransformer._();

  String encode(GroupInIconEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a GroupInIconEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  GroupInIconEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'groups': return GroupInIconEnum.groups;
        case r'travel': return GroupInIconEnum.travel;
        case r'rent': return GroupInIconEnum.rent;
        case r'food': return GroupInIconEnum.food;
        case r'home': return GroupInIconEnum.home;
        case r'shopping': return GroupInIconEnum.shopping;
        case r'entertainment': return GroupInIconEnum.entertainment;
        case r'education': return GroupInIconEnum.education;
        case r'other': return GroupInIconEnum.other;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [GroupInIconEnumTypeTransformer] instance.
  static GroupInIconEnumTypeTransformer? _instance;
}



class GroupInCurrencyEnum {
  /// Instantiate a new enum with the provided [value].
  const GroupInCurrencyEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const INR = GroupInCurrencyEnum._(r'INR');
  static const USD = GroupInCurrencyEnum._(r'USD');
  static const EUR = GroupInCurrencyEnum._(r'EUR');

  /// List of all possible values in this [enum][GroupInCurrencyEnum].
  static const values = <GroupInCurrencyEnum>[
    INR,
    USD,
    EUR,
  ];

  static GroupInCurrencyEnum? fromJson(dynamic value) => GroupInCurrencyEnumTypeTransformer().decode(value);

  static List<GroupInCurrencyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupInCurrencyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupInCurrencyEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [GroupInCurrencyEnum] to String,
/// and [decode] dynamic data back to [GroupInCurrencyEnum].
class GroupInCurrencyEnumTypeTransformer {
  factory GroupInCurrencyEnumTypeTransformer() => _instance ??= const GroupInCurrencyEnumTypeTransformer._();

  const GroupInCurrencyEnumTypeTransformer._();

  String encode(GroupInCurrencyEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a GroupInCurrencyEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  GroupInCurrencyEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'INR': return GroupInCurrencyEnum.INR;
        case r'USD': return GroupInCurrencyEnum.USD;
        case r'EUR': return GroupInCurrencyEnum.EUR;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [GroupInCurrencyEnumTypeTransformer] instance.
  static GroupInCurrencyEnumTypeTransformer? _instance;
}


