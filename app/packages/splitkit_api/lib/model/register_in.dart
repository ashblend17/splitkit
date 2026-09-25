//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class RegisterIn {
  /// Returns a new [RegisterIn] instance.
  RegisterIn({
    required this.name,
    required this.email,
    required this.password,
    required this.currency,
  });

  String name;

  String email;

  String password;

  RegisterInCurrencyEnum currency;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RegisterIn &&
    other.name == name &&
    other.email == email &&
    other.password == password &&
    other.currency == currency;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (name.hashCode) +
    (email.hashCode) +
    (password.hashCode) +
    (currency.hashCode);

  @override
  String toString() => 'RegisterIn[name=$name, email=$email, password=$password, currency=$currency]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'name'] = this.name;
      json[r'email'] = this.email;
      json[r'password'] = this.password;
      json[r'currency'] = this.currency;
    return json;
  }

  /// Returns a new [RegisterIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static RegisterIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "RegisterIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "RegisterIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return RegisterIn(
        name: mapValueOfType<String>(json, r'name')!,
        email: mapValueOfType<String>(json, r'email')!,
        password: mapValueOfType<String>(json, r'password')!,
        currency: RegisterInCurrencyEnum.fromJson(json[r'currency'])!,
      );
    }
    return null;
  }

  static List<RegisterIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RegisterIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RegisterIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, RegisterIn> mapFromJson(dynamic json) {
    final map = <String, RegisterIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = RegisterIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of RegisterIn-objects as value to a dart map
  static Map<String, List<RegisterIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<RegisterIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = RegisterIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'name',
    'email',
    'password',
    'currency',
  };
}


class RegisterInCurrencyEnum {
  /// Instantiate a new enum with the provided [value].
  const RegisterInCurrencyEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const INR = RegisterInCurrencyEnum._(r'INR');
  static const USD = RegisterInCurrencyEnum._(r'USD');
  static const EUR = RegisterInCurrencyEnum._(r'EUR');

  /// List of all possible values in this [enum][RegisterInCurrencyEnum].
  static const values = <RegisterInCurrencyEnum>[
    INR,
    USD,
    EUR,
  ];

  static RegisterInCurrencyEnum? fromJson(dynamic value) => RegisterInCurrencyEnumTypeTransformer().decode(value);

  static List<RegisterInCurrencyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RegisterInCurrencyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RegisterInCurrencyEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [RegisterInCurrencyEnum] to String,
/// and [decode] dynamic data back to [RegisterInCurrencyEnum].
class RegisterInCurrencyEnumTypeTransformer {
  factory RegisterInCurrencyEnumTypeTransformer() => _instance ??= const RegisterInCurrencyEnumTypeTransformer._();

  const RegisterInCurrencyEnumTypeTransformer._();

  String encode(RegisterInCurrencyEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a RegisterInCurrencyEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  RegisterInCurrencyEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'INR': return RegisterInCurrencyEnum.INR;
        case r'USD': return RegisterInCurrencyEnum.USD;
        case r'EUR': return RegisterInCurrencyEnum.EUR;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [RegisterInCurrencyEnumTypeTransformer] instance.
  static RegisterInCurrencyEnumTypeTransformer? _instance;
}


