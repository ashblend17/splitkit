//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupUpdate {
  /// Returns a new [GroupUpdate] instance.
  GroupUpdate({
    this.version,
    this.name,
    this.icon,
    this.archived,
  });

  int? version;

  String? name;

  GroupUpdateIconEnum? icon;

  bool? archived;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GroupUpdate &&
    other.version == version &&
    other.name == name &&
    other.icon == icon &&
    other.archived == archived;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (version == null ? 0 : version!.hashCode) +
    (name == null ? 0 : name!.hashCode) +
    (icon == null ? 0 : icon!.hashCode) +
    (archived == null ? 0 : archived!.hashCode);

  @override
  String toString() => 'GroupUpdate[version=$version, name=$name, icon=$icon, archived=$archived]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.version != null) {
      json[r'version'] = this.version;
    } else {
      json[r'version'] = null;
    }
    if (this.name != null) {
      json[r'name'] = this.name;
    } else {
      json[r'name'] = null;
    }
    if (this.icon != null) {
      json[r'icon'] = this.icon;
    } else {
      json[r'icon'] = null;
    }
    if (this.archived != null) {
      json[r'archived'] = this.archived;
    } else {
      json[r'archived'] = null;
    }
    return json;
  }

  /// Returns a new [GroupUpdate] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GroupUpdate? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GroupUpdate[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GroupUpdate[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GroupUpdate(
        version: mapValueOfType<int>(json, r'version'),
        name: mapValueOfType<String>(json, r'name'),
        icon: GroupUpdateIconEnum.fromJson(json[r'icon']),
        archived: mapValueOfType<bool>(json, r'archived'),
      );
    }
    return null;
  }

  static List<GroupUpdate> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupUpdate>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupUpdate.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GroupUpdate> mapFromJson(dynamic json) {
    final map = <String, GroupUpdate>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GroupUpdate.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GroupUpdate-objects as value to a dart map
  static Map<String, List<GroupUpdate>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GroupUpdate>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GroupUpdate.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class GroupUpdateIconEnum {
  /// Instantiate a new enum with the provided [value].
  const GroupUpdateIconEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const groups = GroupUpdateIconEnum._(r'groups');
  static const travel = GroupUpdateIconEnum._(r'travel');
  static const rent = GroupUpdateIconEnum._(r'rent');
  static const food = GroupUpdateIconEnum._(r'food');
  static const home = GroupUpdateIconEnum._(r'home');
  static const shopping = GroupUpdateIconEnum._(r'shopping');
  static const entertainment = GroupUpdateIconEnum._(r'entertainment');
  static const education = GroupUpdateIconEnum._(r'education');
  static const other = GroupUpdateIconEnum._(r'other');

  /// List of all possible values in this [enum][GroupUpdateIconEnum].
  static const values = <GroupUpdateIconEnum>[
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

  static GroupUpdateIconEnum? fromJson(dynamic value) => GroupUpdateIconEnumTypeTransformer().decode(value);

  static List<GroupUpdateIconEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupUpdateIconEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupUpdateIconEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [GroupUpdateIconEnum] to String,
/// and [decode] dynamic data back to [GroupUpdateIconEnum].
class GroupUpdateIconEnumTypeTransformer {
  factory GroupUpdateIconEnumTypeTransformer() => _instance ??= const GroupUpdateIconEnumTypeTransformer._();

  const GroupUpdateIconEnumTypeTransformer._();

  String encode(GroupUpdateIconEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a GroupUpdateIconEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  GroupUpdateIconEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'groups': return GroupUpdateIconEnum.groups;
        case r'travel': return GroupUpdateIconEnum.travel;
        case r'rent': return GroupUpdateIconEnum.rent;
        case r'food': return GroupUpdateIconEnum.food;
        case r'home': return GroupUpdateIconEnum.home;
        case r'shopping': return GroupUpdateIconEnum.shopping;
        case r'entertainment': return GroupUpdateIconEnum.entertainment;
        case r'education': return GroupUpdateIconEnum.education;
        case r'other': return GroupUpdateIconEnum.other;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [GroupUpdateIconEnumTypeTransformer] instance.
  static GroupUpdateIconEnumTypeTransformer? _instance;
}


