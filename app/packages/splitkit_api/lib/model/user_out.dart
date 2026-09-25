//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UserOut {
  /// Returns a new [UserOut] instance.
  UserOut({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    required this.currency,
    required this.role,
    required this.createdAt,
    required this.version,
  });

  String id;

  String name;

  String? email;

  String? avatarUrl;

  String currency;

  String role;

  DateTime createdAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UserOut &&
    other.id == id &&
    other.name == name &&
    other.email == email &&
    other.avatarUrl == avatarUrl &&
    other.currency == currency &&
    other.role == role &&
    other.createdAt == createdAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode) +
    (email == null ? 0 : email!.hashCode) +
    (avatarUrl == null ? 0 : avatarUrl!.hashCode) +
    (currency.hashCode) +
    (role.hashCode) +
    (createdAt.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'UserOut[id=$id, name=$name, email=$email, avatarUrl=$avatarUrl, currency=$currency, role=$role, createdAt=$createdAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
    if (this.email != null) {
      json[r'email'] = this.email;
    } else {
      json[r'email'] = null;
    }
    if (this.avatarUrl != null) {
      json[r'avatar_url'] = this.avatarUrl;
    } else {
      json[r'avatar_url'] = null;
    }
      json[r'currency'] = this.currency;
      json[r'role'] = this.role;
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
      json[r'version'] = this.version;
    return json;
  }

  /// Returns a new [UserOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UserOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UserOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UserOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UserOut(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        email: mapValueOfType<String>(json, r'email'),
        avatarUrl: mapValueOfType<String>(json, r'avatar_url'),
        currency: mapValueOfType<String>(json, r'currency')!,
        role: mapValueOfType<String>(json, r'role')!,
        createdAt: mapDateTime(json, r'created_at', r'')!,
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<UserOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UserOut> mapFromJson(dynamic json) {
    final map = <String, UserOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UserOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UserOut-objects as value to a dart map
  static Map<String, List<UserOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UserOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UserOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
    'currency',
    'role',
    'created_at',
    'version',
  };
}

