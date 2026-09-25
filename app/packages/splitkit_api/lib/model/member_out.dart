//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MemberOut {
  /// Returns a new [MemberOut] instance.
  MemberOut({
    required this.user,
    required this.role,
    required this.joinedAt,
    this.placeholderName,
  });

  UserBrief user;

  String role;

  DateTime joinedAt;

  String? placeholderName;

  @override
  bool operator ==(Object other) => identical(this, other) || other is MemberOut &&
    other.user == user &&
    other.role == role &&
    other.joinedAt == joinedAt &&
    other.placeholderName == placeholderName;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (user.hashCode) +
    (role.hashCode) +
    (joinedAt.hashCode) +
    (placeholderName == null ? 0 : placeholderName!.hashCode);

  @override
  String toString() => 'MemberOut[user=$user, role=$role, joinedAt=$joinedAt, placeholderName=$placeholderName]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'user'] = this.user;
      json[r'role'] = this.role;
      json[r'joined_at'] = this.joinedAt.toUtc().toIso8601String();
    if (this.placeholderName != null) {
      json[r'placeholder_name'] = this.placeholderName;
    } else {
      json[r'placeholder_name'] = null;
    }
    return json;
  }

  /// Returns a new [MemberOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MemberOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "MemberOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "MemberOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return MemberOut(
        user: UserBrief.fromJson(json[r'user'])!,
        role: mapValueOfType<String>(json, r'role')!,
        joinedAt: mapDateTime(json, r'joined_at', r'')!,
        placeholderName: mapValueOfType<String>(json, r'placeholder_name'),
      );
    }
    return null;
  }

  static List<MemberOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MemberOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MemberOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MemberOut> mapFromJson(dynamic json) {
    final map = <String, MemberOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MemberOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MemberOut-objects as value to a dart map
  static Map<String, List<MemberOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<MemberOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MemberOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'user',
    'role',
    'joined_at',
  };
}

