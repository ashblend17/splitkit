//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalAccountOut {
  /// Returns a new [PersonalAccountOut] instance.
  PersonalAccountOut({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.openingBalanceMinor,
    this.smsLabel,
    required this.status,
    this.actingAdminId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
  });

  String id;

  String name;

  PersonalAccountOutTypeEnum type;

  String currency;

  int openingBalanceMinor;

  String? smsLabel;

  PersonalAccountOutStatusEnum status;

  String? actingAdminId;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? deletedAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalAccountOut &&
    other.id == id &&
    other.name == name &&
    other.type == type &&
    other.currency == currency &&
    other.openingBalanceMinor == openingBalanceMinor &&
    other.smsLabel == smsLabel &&
    other.status == status &&
    other.actingAdminId == actingAdminId &&
    other.createdAt == createdAt &&
    other.updatedAt == updatedAt &&
    other.deletedAt == deletedAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode) +
    (type.hashCode) +
    (currency.hashCode) +
    (openingBalanceMinor.hashCode) +
    (smsLabel == null ? 0 : smsLabel!.hashCode) +
    (status.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (createdAt.hashCode) +
    (updatedAt.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'PersonalAccountOut[id=$id, name=$name, type=$type, currency=$currency, openingBalanceMinor=$openingBalanceMinor, smsLabel=$smsLabel, status=$status, actingAdminId=$actingAdminId, createdAt=$createdAt, updatedAt=$updatedAt, deletedAt=$deletedAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
      json[r'type'] = this.type;
      json[r'currency'] = this.currency;
      json[r'opening_balance_minor'] = this.openingBalanceMinor;
    if (this.smsLabel != null) {
      json[r'sms_label'] = this.smsLabel;
    } else {
      json[r'sms_label'] = null;
    }
      json[r'status'] = this.status;
    if (this.actingAdminId != null) {
      json[r'acting_admin_id'] = this.actingAdminId;
    } else {
      json[r'acting_admin_id'] = null;
    }
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
      json[r'updated_at'] = this.updatedAt.toUtc().toIso8601String();
    if (this.deletedAt != null) {
      json[r'deleted_at'] = this.deletedAt!.toUtc().toIso8601String();
    } else {
      json[r'deleted_at'] = null;
    }
      json[r'version'] = this.version;
    return json;
  }

  /// Returns a new [PersonalAccountOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalAccountOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalAccountOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalAccountOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalAccountOut(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        type: PersonalAccountOutTypeEnum.fromJson(json[r'type'])!,
        currency: mapValueOfType<String>(json, r'currency')!,
        openingBalanceMinor: mapValueOfType<int>(json, r'opening_balance_minor')!,
        smsLabel: mapValueOfType<String>(json, r'sms_label'),
        status: PersonalAccountOutStatusEnum.fromJson(json[r'status'])!,
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<PersonalAccountOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAccountOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAccountOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalAccountOut> mapFromJson(dynamic json) {
    final map = <String, PersonalAccountOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalAccountOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalAccountOut-objects as value to a dart map
  static Map<String, List<PersonalAccountOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalAccountOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalAccountOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
    'type',
    'currency',
    'opening_balance_minor',
    'status',
    'created_at',
    'updated_at',
    'version',
  };
}


class PersonalAccountOutTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalAccountOutTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const cash = PersonalAccountOutTypeEnum._(r'cash');
  static const bank = PersonalAccountOutTypeEnum._(r'bank');
  static const creditCard = PersonalAccountOutTypeEnum._(r'credit_card');
  static const loan = PersonalAccountOutTypeEnum._(r'loan');
  static const investment = PersonalAccountOutTypeEnum._(r'investment');
  static const otherAsset = PersonalAccountOutTypeEnum._(r'other_asset');

  /// List of all possible values in this [enum][PersonalAccountOutTypeEnum].
  static const values = <PersonalAccountOutTypeEnum>[
    cash,
    bank,
    creditCard,
    loan,
    investment,
    otherAsset,
  ];

  static PersonalAccountOutTypeEnum? fromJson(dynamic value) => PersonalAccountOutTypeEnumTypeTransformer().decode(value);

  static List<PersonalAccountOutTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAccountOutTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAccountOutTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalAccountOutTypeEnum] to String,
/// and [decode] dynamic data back to [PersonalAccountOutTypeEnum].
class PersonalAccountOutTypeEnumTypeTransformer {
  factory PersonalAccountOutTypeEnumTypeTransformer() => _instance ??= const PersonalAccountOutTypeEnumTypeTransformer._();

  const PersonalAccountOutTypeEnumTypeTransformer._();

  String encode(PersonalAccountOutTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalAccountOutTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalAccountOutTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'cash': return PersonalAccountOutTypeEnum.cash;
        case r'bank': return PersonalAccountOutTypeEnum.bank;
        case r'credit_card': return PersonalAccountOutTypeEnum.creditCard;
        case r'loan': return PersonalAccountOutTypeEnum.loan;
        case r'investment': return PersonalAccountOutTypeEnum.investment;
        case r'other_asset': return PersonalAccountOutTypeEnum.otherAsset;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalAccountOutTypeEnumTypeTransformer] instance.
  static PersonalAccountOutTypeEnumTypeTransformer? _instance;
}



class PersonalAccountOutStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalAccountOutStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const active = PersonalAccountOutStatusEnum._(r'active');
  static const closed = PersonalAccountOutStatusEnum._(r'closed');

  /// List of all possible values in this [enum][PersonalAccountOutStatusEnum].
  static const values = <PersonalAccountOutStatusEnum>[
    active,
    closed,
  ];

  static PersonalAccountOutStatusEnum? fromJson(dynamic value) => PersonalAccountOutStatusEnumTypeTransformer().decode(value);

  static List<PersonalAccountOutStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAccountOutStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAccountOutStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalAccountOutStatusEnum] to String,
/// and [decode] dynamic data back to [PersonalAccountOutStatusEnum].
class PersonalAccountOutStatusEnumTypeTransformer {
  factory PersonalAccountOutStatusEnumTypeTransformer() => _instance ??= const PersonalAccountOutStatusEnumTypeTransformer._();

  const PersonalAccountOutStatusEnumTypeTransformer._();

  String encode(PersonalAccountOutStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalAccountOutStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalAccountOutStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'active': return PersonalAccountOutStatusEnum.active;
        case r'closed': return PersonalAccountOutStatusEnum.closed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalAccountOutStatusEnumTypeTransformer] instance.
  static PersonalAccountOutStatusEnumTypeTransformer? _instance;
}


