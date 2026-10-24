//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalHoldingOut {
  /// Returns a new [PersonalHoldingOut] instance.
  PersonalHoldingOut({
    required this.id,
    required this.accountId,
    required this.name,
    required this.assetType,
    this.quantity,
    this.costBasisMinor,
    required this.marketValueMinor,
    required this.valuationAt,
    required this.valuationSource,
    required this.currency,
    this.actingAdminId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
  });

  String id;

  String accountId;

  String name;

  PersonalHoldingOutAssetTypeEnum assetType;

  String? quantity;

  int? costBasisMinor;

  int marketValueMinor;

  DateTime valuationAt;

  PersonalHoldingOutValuationSourceEnum valuationSource;

  String currency;

  String? actingAdminId;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? deletedAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalHoldingOut &&
    other.id == id &&
    other.accountId == accountId &&
    other.name == name &&
    other.assetType == assetType &&
    other.quantity == quantity &&
    other.costBasisMinor == costBasisMinor &&
    other.marketValueMinor == marketValueMinor &&
    other.valuationAt == valuationAt &&
    other.valuationSource == valuationSource &&
    other.currency == currency &&
    other.actingAdminId == actingAdminId &&
    other.createdAt == createdAt &&
    other.updatedAt == updatedAt &&
    other.deletedAt == deletedAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (accountId.hashCode) +
    (name.hashCode) +
    (assetType.hashCode) +
    (quantity == null ? 0 : quantity!.hashCode) +
    (costBasisMinor == null ? 0 : costBasisMinor!.hashCode) +
    (marketValueMinor.hashCode) +
    (valuationAt.hashCode) +
    (valuationSource.hashCode) +
    (currency.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (createdAt.hashCode) +
    (updatedAt.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'PersonalHoldingOut[id=$id, accountId=$accountId, name=$name, assetType=$assetType, quantity=$quantity, costBasisMinor=$costBasisMinor, marketValueMinor=$marketValueMinor, valuationAt=$valuationAt, valuationSource=$valuationSource, currency=$currency, actingAdminId=$actingAdminId, createdAt=$createdAt, updatedAt=$updatedAt, deletedAt=$deletedAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'account_id'] = this.accountId;
      json[r'name'] = this.name;
      json[r'asset_type'] = this.assetType;
    if (this.quantity != null) {
      json[r'quantity'] = this.quantity;
    } else {
      json[r'quantity'] = null;
    }
    if (this.costBasisMinor != null) {
      json[r'cost_basis_minor'] = this.costBasisMinor;
    } else {
      json[r'cost_basis_minor'] = null;
    }
      json[r'market_value_minor'] = this.marketValueMinor;
      json[r'valuation_at'] = _dateFormatter.format(this.valuationAt.toUtc());
      json[r'valuation_source'] = this.valuationSource;
      json[r'currency'] = this.currency;
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

  /// Returns a new [PersonalHoldingOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalHoldingOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalHoldingOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalHoldingOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalHoldingOut(
        id: mapValueOfType<String>(json, r'id')!,
        accountId: mapValueOfType<String>(json, r'account_id')!,
        name: mapValueOfType<String>(json, r'name')!,
        assetType: PersonalHoldingOutAssetTypeEnum.fromJson(json[r'asset_type'])!,
        quantity: mapValueOfType<String>(json, r'quantity'),
        costBasisMinor: mapValueOfType<int>(json, r'cost_basis_minor'),
        marketValueMinor: mapValueOfType<int>(json, r'market_value_minor')!,
        valuationAt: mapDateTime(json, r'valuation_at', r'')!,
        valuationSource: PersonalHoldingOutValuationSourceEnum.fromJson(json[r'valuation_source'])!,
        currency: mapValueOfType<String>(json, r'currency')!,
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<PersonalHoldingOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalHoldingOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalHoldingOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalHoldingOut> mapFromJson(dynamic json) {
    final map = <String, PersonalHoldingOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalHoldingOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalHoldingOut-objects as value to a dart map
  static Map<String, List<PersonalHoldingOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalHoldingOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalHoldingOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'account_id',
    'name',
    'asset_type',
    'market_value_minor',
    'valuation_at',
    'valuation_source',
    'currency',
    'created_at',
    'updated_at',
    'version',
  };
}


class PersonalHoldingOutAssetTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalHoldingOutAssetTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const mutualFund = PersonalHoldingOutAssetTypeEnum._(r'mutual_fund');
  static const stock = PersonalHoldingOutAssetTypeEnum._(r'stock');
  static const fd = PersonalHoldingOutAssetTypeEnum._(r'fd');
  static const gold = PersonalHoldingOutAssetTypeEnum._(r'gold');
  static const other = PersonalHoldingOutAssetTypeEnum._(r'other');

  /// List of all possible values in this [enum][PersonalHoldingOutAssetTypeEnum].
  static const values = <PersonalHoldingOutAssetTypeEnum>[
    mutualFund,
    stock,
    fd,
    gold,
    other,
  ];

  static PersonalHoldingOutAssetTypeEnum? fromJson(dynamic value) => PersonalHoldingOutAssetTypeEnumTypeTransformer().decode(value);

  static List<PersonalHoldingOutAssetTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalHoldingOutAssetTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalHoldingOutAssetTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalHoldingOutAssetTypeEnum] to String,
/// and [decode] dynamic data back to [PersonalHoldingOutAssetTypeEnum].
class PersonalHoldingOutAssetTypeEnumTypeTransformer {
  factory PersonalHoldingOutAssetTypeEnumTypeTransformer() => _instance ??= const PersonalHoldingOutAssetTypeEnumTypeTransformer._();

  const PersonalHoldingOutAssetTypeEnumTypeTransformer._();

  String encode(PersonalHoldingOutAssetTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalHoldingOutAssetTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalHoldingOutAssetTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'mutual_fund': return PersonalHoldingOutAssetTypeEnum.mutualFund;
        case r'stock': return PersonalHoldingOutAssetTypeEnum.stock;
        case r'fd': return PersonalHoldingOutAssetTypeEnum.fd;
        case r'gold': return PersonalHoldingOutAssetTypeEnum.gold;
        case r'other': return PersonalHoldingOutAssetTypeEnum.other;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalHoldingOutAssetTypeEnumTypeTransformer] instance.
  static PersonalHoldingOutAssetTypeEnumTypeTransformer? _instance;
}



class PersonalHoldingOutValuationSourceEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalHoldingOutValuationSourceEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const manual = PersonalHoldingOutValuationSourceEnum._(r'manual');

  /// List of all possible values in this [enum][PersonalHoldingOutValuationSourceEnum].
  static const values = <PersonalHoldingOutValuationSourceEnum>[
    manual,
  ];

  static PersonalHoldingOutValuationSourceEnum? fromJson(dynamic value) => PersonalHoldingOutValuationSourceEnumTypeTransformer().decode(value);

  static List<PersonalHoldingOutValuationSourceEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalHoldingOutValuationSourceEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalHoldingOutValuationSourceEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalHoldingOutValuationSourceEnum] to String,
/// and [decode] dynamic data back to [PersonalHoldingOutValuationSourceEnum].
class PersonalHoldingOutValuationSourceEnumTypeTransformer {
  factory PersonalHoldingOutValuationSourceEnumTypeTransformer() => _instance ??= const PersonalHoldingOutValuationSourceEnumTypeTransformer._();

  const PersonalHoldingOutValuationSourceEnumTypeTransformer._();

  String encode(PersonalHoldingOutValuationSourceEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalHoldingOutValuationSourceEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalHoldingOutValuationSourceEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'manual': return PersonalHoldingOutValuationSourceEnum.manual;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalHoldingOutValuationSourceEnumTypeTransformer] instance.
  static PersonalHoldingOutValuationSourceEnumTypeTransformer? _instance;
}


