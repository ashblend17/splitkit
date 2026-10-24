//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonOut {
  /// Returns a new [PersonOut] instance.
  PersonOut({
    required this.name,
    required this.rows,
    required this.match,
    this.user,
  });

  String name;

  int rows;

  PersonOutMatchEnum match;

  UserBrief? user;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonOut &&
    other.name == name &&
    other.rows == rows &&
    other.match == match &&
    other.user == user;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (name.hashCode) +
    (rows.hashCode) +
    (match.hashCode) +
    (user == null ? 0 : user!.hashCode);

  @override
  String toString() => 'PersonOut[name=$name, rows=$rows, match=$match, user=$user]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'name'] = this.name;
      json[r'rows'] = this.rows;
      json[r'match'] = this.match;
    if (this.user != null) {
      json[r'user'] = this.user;
    } else {
      json[r'user'] = null;
    }
    return json;
  }

  /// Returns a new [PersonOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonOut(
        name: mapValueOfType<String>(json, r'name')!,
        rows: mapValueOfType<int>(json, r'rows')!,
        match: PersonOutMatchEnum.fromJson(json[r'match'])!,
        user: UserBrief.fromJson(json[r'user']),
      );
    }
    return null;
  }

  static List<PersonOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonOut> mapFromJson(dynamic json) {
    final map = <String, PersonOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonOut-objects as value to a dart map
  static Map<String, List<PersonOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'name',
    'rows',
    'match',
  };
}


class PersonOutMatchEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonOutMatchEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const you = PersonOutMatchEnum._(r'you');
  static const matched = PersonOutMatchEnum._(r'matched');
  static const suggested = PersonOutMatchEnum._(r'suggested');
  static const unmatched = PersonOutMatchEnum._(r'unmatched');

  /// List of all possible values in this [enum][PersonOutMatchEnum].
  static const values = <PersonOutMatchEnum>[
    you,
    matched,
    suggested,
    unmatched,
  ];

  static PersonOutMatchEnum? fromJson(dynamic value) => PersonOutMatchEnumTypeTransformer().decode(value);

  static List<PersonOutMatchEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonOutMatchEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonOutMatchEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonOutMatchEnum] to String,
/// and [decode] dynamic data back to [PersonOutMatchEnum].
class PersonOutMatchEnumTypeTransformer {
  factory PersonOutMatchEnumTypeTransformer() => _instance ??= const PersonOutMatchEnumTypeTransformer._();

  const PersonOutMatchEnumTypeTransformer._();

  String encode(PersonOutMatchEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonOutMatchEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonOutMatchEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'you': return PersonOutMatchEnum.you;
        case r'matched': return PersonOutMatchEnum.matched;
        case r'suggested': return PersonOutMatchEnum.suggested;
        case r'unmatched': return PersonOutMatchEnum.unmatched;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonOutMatchEnumTypeTransformer] instance.
  static PersonOutMatchEnumTypeTransformer? _instance;
}


