//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UserBrief {
  /// Returns a new [UserBrief] instance.
  UserBrief({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isPlaceholder = false,
  });

  String id;

  String name;

  String? avatarUrl;

  bool isPlaceholder;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UserBrief &&
    other.id == id &&
    other.name == name &&
    other.avatarUrl == avatarUrl &&
    other.isPlaceholder == isPlaceholder;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode) +
    (avatarUrl == null ? 0 : avatarUrl!.hashCode) +
    (isPlaceholder.hashCode);

  @override
  String toString() => 'UserBrief[id=$id, name=$name, avatarUrl=$avatarUrl, isPlaceholder=$isPlaceholder]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
    if (this.avatarUrl != null) {
      json[r'avatar_url'] = this.avatarUrl;
    } else {
      json[r'avatar_url'] = null;
    }
      json[r'is_placeholder'] = this.isPlaceholder;
    return json;
  }

  /// Returns a new [UserBrief] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UserBrief? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UserBrief[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UserBrief[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UserBrief(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        avatarUrl: mapValueOfType<String>(json, r'avatar_url'),
        isPlaceholder: mapValueOfType<bool>(json, r'is_placeholder') ?? false,
      );
    }
    return null;
  }

  static List<UserBrief> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserBrief>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserBrief.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UserBrief> mapFromJson(dynamic json) {
    final map = <String, UserBrief>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UserBrief.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UserBrief-objects as value to a dart map
  static Map<String, List<UserBrief>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UserBrief>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UserBrief.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
  };
}

