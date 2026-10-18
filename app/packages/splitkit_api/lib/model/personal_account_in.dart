//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalAccountIn {
  /// Returns a new [PersonalAccountIn] instance.
  PersonalAccountIn({
    this.id,
    this.version,
    required this.name,
    required this.type,
    this.openingBalanceMinor = 0,
    this.smsLabel,
    this.status,
  });

  String? id;

  int? version;

  String name;

  PersonalAccountInTypeEnum type;

  /// Minimum value: -1000000000000000
  /// Maximum value: 1000000000000000
  int openingBalanceMinor;

  String? smsLabel;

  PersonalAccountInStatusEnum? status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalAccountIn &&
    other.id == id &&
    other.version == version &&
    other.name == name &&
    other.type == type &&
    other.openingBalanceMinor == openingBalanceMinor &&
    other.smsLabel == smsLabel &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (name.hashCode) +
    (type.hashCode) +
    (openingBalanceMinor.hashCode) +
    (smsLabel == null ? 0 : smsLabel!.hashCode) +
    (status == null ? 0 : status!.hashCode);

  @override
  String toString() => 'PersonalAccountIn[id=$id, version=$version, name=$name, type=$type, openingBalanceMinor=$openingBalanceMinor, smsLabel=$smsLabel, status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.version != null) {
      json[r'version'] = this.version;
    } else {
      json[r'version'] = null;
    }
      json[r'name'] = this.name;
      json[r'type'] = this.type;
      json[r'opening_balance_minor'] = this.openingBalanceMinor;
    if (this.smsLabel != null) {
      json[r'sms_label'] = this.smsLabel;
    } else {
      json[r'sms_label'] = null;
    }
    if (this.status != null) {
      json[r'status'] = this.status;
    } else {
      json[r'status'] = null;
    }
    return json;
  }

  /// Returns a new [PersonalAccountIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalAccountIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalAccountIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalAccountIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalAccountIn(
        id: mapValueOfType<String>(json, r'id'),
        version: mapValueOfType<int>(json, r'version'),
        name: mapValueOfType<String>(json, r'name')!,
        type: PersonalAccountInTypeEnum.fromJson(json[r'type'])!,
        openingBalanceMinor: mapValueOfType<int>(json, r'opening_balance_minor') ?? 0,
        smsLabel: mapValueOfType<String>(json, r'sms_label'),
        status: PersonalAccountInStatusEnum.fromJson(json[r'status']),
      );
    }
    return null;
  }

  static List<PersonalAccountIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAccountIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAccountIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalAccountIn> mapFromJson(dynamic json) {
    final map = <String, PersonalAccountIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalAccountIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalAccountIn-objects as value to a dart map
  static Map<String, List<PersonalAccountIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalAccountIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalAccountIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'name',
    'type',
  };
}


class PersonalAccountInTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalAccountInTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const cash = PersonalAccountInTypeEnum._(r'cash');
  static const bank = PersonalAccountInTypeEnum._(r'bank');
  static const creditCard = PersonalAccountInTypeEnum._(r'credit_card');
  static const loan = PersonalAccountInTypeEnum._(r'loan');
  static const investment = PersonalAccountInTypeEnum._(r'investment');
  static const otherAsset = PersonalAccountInTypeEnum._(r'other_asset');

  /// List of all possible values in this [enum][PersonalAccountInTypeEnum].
  static const values = <PersonalAccountInTypeEnum>[
    cash,
    bank,
    creditCard,
    loan,
    investment,
    otherAsset,
  ];

  static PersonalAccountInTypeEnum? fromJson(dynamic value) => PersonalAccountInTypeEnumTypeTransformer().decode(value);

  static List<PersonalAccountInTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAccountInTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAccountInTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalAccountInTypeEnum] to String,
/// and [decode] dynamic data back to [PersonalAccountInTypeEnum].
class PersonalAccountInTypeEnumTypeTransformer {
  factory PersonalAccountInTypeEnumTypeTransformer() => _instance ??= const PersonalAccountInTypeEnumTypeTransformer._();

  const PersonalAccountInTypeEnumTypeTransformer._();

  String encode(PersonalAccountInTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalAccountInTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalAccountInTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'cash': return PersonalAccountInTypeEnum.cash;
        case r'bank': return PersonalAccountInTypeEnum.bank;
        case r'credit_card': return PersonalAccountInTypeEnum.creditCard;
        case r'loan': return PersonalAccountInTypeEnum.loan;
        case r'investment': return PersonalAccountInTypeEnum.investment;
        case r'other_asset': return PersonalAccountInTypeEnum.otherAsset;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalAccountInTypeEnumTypeTransformer] instance.
  static PersonalAccountInTypeEnumTypeTransformer? _instance;
}



class PersonalAccountInStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalAccountInStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const active = PersonalAccountInStatusEnum._(r'active');
  static const closed = PersonalAccountInStatusEnum._(r'closed');

  /// List of all possible values in this [enum][PersonalAccountInStatusEnum].
  static const values = <PersonalAccountInStatusEnum>[
    active,
    closed,
  ];

  static PersonalAccountInStatusEnum? fromJson(dynamic value) => PersonalAccountInStatusEnumTypeTransformer().decode(value);

  static List<PersonalAccountInStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAccountInStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAccountInStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalAccountInStatusEnum] to String,
/// and [decode] dynamic data back to [PersonalAccountInStatusEnum].
class PersonalAccountInStatusEnumTypeTransformer {
  factory PersonalAccountInStatusEnumTypeTransformer() => _instance ??= const PersonalAccountInStatusEnumTypeTransformer._();

  const PersonalAccountInStatusEnumTypeTransformer._();

  String encode(PersonalAccountInStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalAccountInStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalAccountInStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'active': return PersonalAccountInStatusEnum.active;
        case r'closed': return PersonalAccountInStatusEnum.closed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalAccountInStatusEnumTypeTransformer] instance.
  static PersonalAccountInStatusEnumTypeTransformer? _instance;
}


