//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminSessionStartOut {
  /// Returns a new [AdminSessionStartOut] instance.
  AdminSessionStartOut({
    required this.session,
    required this.accessToken,
    this.tokenType = 'bearer',
    required this.expiresIn,
    required this.user,
  });

  AdminSessionOut session;

  String accessToken;

  String tokenType;

  int expiresIn;

  UserOut user;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminSessionStartOut &&
    other.session == session &&
    other.accessToken == accessToken &&
    other.tokenType == tokenType &&
    other.expiresIn == expiresIn &&
    other.user == user;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (session.hashCode) +
    (accessToken.hashCode) +
    (tokenType.hashCode) +
    (expiresIn.hashCode) +
    (user.hashCode);

  @override
  String toString() => 'AdminSessionStartOut[session=$session, accessToken=$accessToken, tokenType=$tokenType, expiresIn=$expiresIn, user=$user]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'session'] = this.session;
      json[r'access_token'] = this.accessToken;
      json[r'token_type'] = this.tokenType;
      json[r'expires_in'] = this.expiresIn;
      json[r'user'] = this.user;
    return json;
  }

  /// Returns a new [AdminSessionStartOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminSessionStartOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminSessionStartOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminSessionStartOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminSessionStartOut(
        session: AdminSessionOut.fromJson(json[r'session'])!,
        accessToken: mapValueOfType<String>(json, r'access_token')!,
        tokenType: mapValueOfType<String>(json, r'token_type') ?? 'bearer',
        expiresIn: mapValueOfType<int>(json, r'expires_in')!,
        user: UserOut.fromJson(json[r'user'])!,
      );
    }
    return null;
  }

  static List<AdminSessionStartOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionStartOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionStartOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminSessionStartOut> mapFromJson(dynamic json) {
    final map = <String, AdminSessionStartOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminSessionStartOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminSessionStartOut-objects as value to a dart map
  static Map<String, List<AdminSessionStartOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminSessionStartOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminSessionStartOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'session',
    'access_token',
    'expires_in',
    'user',
  };
}

