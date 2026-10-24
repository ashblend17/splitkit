//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UserUpdate {
  /// Returns a new [UserUpdate] instance.
  UserUpdate({
    this.version,
    this.name,
    this.avatarUrl,
    this.currency,
  });

  int? version;

  String? name;

  String? avatarUrl;

  UserUpdateCurrencyEnum? currency;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UserUpdate &&
    other.version == version &&
    other.name == name &&
    other.avatarUrl == avatarUrl &&
    other.currency == currency;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (version == null ? 0 : version!.hashCode) +
    (name == null ? 0 : name!.hashCode) +
    (avatarUrl == null ? 0 : avatarUrl!.hashCode) +
    (currency == null ? 0 : currency!.hashCode);

  @override
  String toString() => 'UserUpdate[version=$version, name=$name, avatarUrl=$avatarUrl, currency=$currency]';

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
    if (this.avatarUrl != null) {
      json[r'avatar_url'] = this.avatarUrl;
    } else {
      json[r'avatar_url'] = null;
    }
    if (this.currency != null) {
      json[r'currency'] = this.currency;
    } else {
      json[r'currency'] = null;
    }
    return json;
  }

  /// Returns a new [UserUpdate] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UserUpdate? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UserUpdate[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UserUpdate[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UserUpdate(
        version: mapValueOfType<int>(json, r'version'),
        name: mapValueOfType<String>(json, r'name'),
        avatarUrl: mapValueOfType<String>(json, r'avatar_url'),
        currency: UserUpdateCurrencyEnum.fromJson(json[r'currency']),
      );
    }
    return null;
  }

  static List<UserUpdate> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserUpdate>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserUpdate.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UserUpdate> mapFromJson(dynamic json) {
    final map = <String, UserUpdate>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UserUpdate.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UserUpdate-objects as value to a dart map
  static Map<String, List<UserUpdate>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UserUpdate>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UserUpdate.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class UserUpdateCurrencyEnum {
  /// Instantiate a new enum with the provided [value].
  const UserUpdateCurrencyEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const INR = UserUpdateCurrencyEnum._(r'INR');
  static const USD = UserUpdateCurrencyEnum._(r'USD');
  static const EUR = UserUpdateCurrencyEnum._(r'EUR');

  /// List of all possible values in this [enum][UserUpdateCurrencyEnum].
  static const values = <UserUpdateCurrencyEnum>[
    INR,
    USD,
    EUR,
  ];

  static UserUpdateCurrencyEnum? fromJson(dynamic value) => UserUpdateCurrencyEnumTypeTransformer().decode(value);

  static List<UserUpdateCurrencyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserUpdateCurrencyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserUpdateCurrencyEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [UserUpdateCurrencyEnum] to String,
/// and [decode] dynamic data back to [UserUpdateCurrencyEnum].
class UserUpdateCurrencyEnumTypeTransformer {
  factory UserUpdateCurrencyEnumTypeTransformer() => _instance ??= const UserUpdateCurrencyEnumTypeTransformer._();

  const UserUpdateCurrencyEnumTypeTransformer._();

  String encode(UserUpdateCurrencyEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a UserUpdateCurrencyEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  UserUpdateCurrencyEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'INR': return UserUpdateCurrencyEnum.INR;
        case r'USD': return UserUpdateCurrencyEnum.USD;
        case r'EUR': return UserUpdateCurrencyEnum.EUR;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [UserUpdateCurrencyEnumTypeTransformer] instance.
  static UserUpdateCurrencyEnumTypeTransformer? _instance;
}


