//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalHoldingIn {
  /// Returns a new [PersonalHoldingIn] instance.
  PersonalHoldingIn({
    this.id,
    this.version,
    required this.name,
    required this.assetType,
    required this.marketValueMinor,
    required this.valuationAt,
    required this.valuationSource,
    this.accountId,
    this.quantity,
    this.costBasisMinor,
  });

  String? id;

  int? version;

  String name;

  PersonalHoldingInAssetTypeEnum assetType;

  /// Minimum value: 0
  /// Maximum value: 1000000000000000
  int marketValueMinor;

  DateTime valuationAt;

  PersonalHoldingInValuationSourceEnum valuationSource;

  String? accountId;

  String? quantity;

  /// Minimum value: 0
  /// Maximum value: 1000000000000000
  int? costBasisMinor;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalHoldingIn &&
    other.id == id &&
    other.version == version &&
    other.name == name &&
    other.assetType == assetType &&
    other.marketValueMinor == marketValueMinor &&
    other.valuationAt == valuationAt &&
    other.valuationSource == valuationSource &&
    other.accountId == accountId &&
    other.quantity == quantity &&
    other.costBasisMinor == costBasisMinor;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (name.hashCode) +
    (assetType.hashCode) +
    (marketValueMinor.hashCode) +
    (valuationAt.hashCode) +
    (valuationSource.hashCode) +
    (accountId == null ? 0 : accountId!.hashCode) +
    (quantity == null ? 0 : quantity!.hashCode) +
    (costBasisMinor == null ? 0 : costBasisMinor!.hashCode);

  @override
  String toString() => 'PersonalHoldingIn[id=$id, version=$version, name=$name, assetType=$assetType, marketValueMinor=$marketValueMinor, valuationAt=$valuationAt, valuationSource=$valuationSource, accountId=$accountId, quantity=$quantity, costBasisMinor=$costBasisMinor]';

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
      json[r'asset_type'] = this.assetType;
      json[r'market_value_minor'] = this.marketValueMinor;
      json[r'valuation_at'] = _dateFormatter.format(this.valuationAt.toUtc());
      json[r'valuation_source'] = this.valuationSource;
    if (this.accountId != null) {
      json[r'account_id'] = this.accountId;
    } else {
      json[r'account_id'] = null;
    }
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
    return json;
  }

  /// Returns a new [PersonalHoldingIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalHoldingIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalHoldingIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalHoldingIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalHoldingIn(
        id: mapValueOfType<String>(json, r'id'),
        version: mapValueOfType<int>(json, r'version'),
        name: mapValueOfType<String>(json, r'name')!,
        assetType: PersonalHoldingInAssetTypeEnum.fromJson(json[r'asset_type'])!,
        marketValueMinor: mapValueOfType<int>(json, r'market_value_minor')!,
        valuationAt: mapDateTime(json, r'valuation_at', r'')!,
        valuationSource: PersonalHoldingInValuationSourceEnum.fromJson(json[r'valuation_source'])!,
        accountId: mapValueOfType<String>(json, r'account_id'),
        quantity: mapValueOfType<String>(json, r'quantity'),
        costBasisMinor: mapValueOfType<int>(json, r'cost_basis_minor'),
      );
    }
    return null;
  }

  static List<PersonalHoldingIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalHoldingIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalHoldingIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalHoldingIn> mapFromJson(dynamic json) {
    final map = <String, PersonalHoldingIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalHoldingIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalHoldingIn-objects as value to a dart map
  static Map<String, List<PersonalHoldingIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalHoldingIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalHoldingIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'name',
    'asset_type',
    'market_value_minor',
    'valuation_at',
    'valuation_source',
  };
}


class PersonalHoldingInAssetTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalHoldingInAssetTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const mutualFund = PersonalHoldingInAssetTypeEnum._(r'mutual_fund');
  static const stock = PersonalHoldingInAssetTypeEnum._(r'stock');
  static const fd = PersonalHoldingInAssetTypeEnum._(r'fd');
  static const gold = PersonalHoldingInAssetTypeEnum._(r'gold');
  static const other = PersonalHoldingInAssetTypeEnum._(r'other');

  /// List of all possible values in this [enum][PersonalHoldingInAssetTypeEnum].
  static const values = <PersonalHoldingInAssetTypeEnum>[
    mutualFund,
    stock,
    fd,
    gold,
    other,
  ];

  static PersonalHoldingInAssetTypeEnum? fromJson(dynamic value) => PersonalHoldingInAssetTypeEnumTypeTransformer().decode(value);

  static List<PersonalHoldingInAssetTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalHoldingInAssetTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalHoldingInAssetTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalHoldingInAssetTypeEnum] to String,
/// and [decode] dynamic data back to [PersonalHoldingInAssetTypeEnum].
class PersonalHoldingInAssetTypeEnumTypeTransformer {
  factory PersonalHoldingInAssetTypeEnumTypeTransformer() => _instance ??= const PersonalHoldingInAssetTypeEnumTypeTransformer._();

  const PersonalHoldingInAssetTypeEnumTypeTransformer._();

  String encode(PersonalHoldingInAssetTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalHoldingInAssetTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalHoldingInAssetTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'mutual_fund': return PersonalHoldingInAssetTypeEnum.mutualFund;
        case r'stock': return PersonalHoldingInAssetTypeEnum.stock;
        case r'fd': return PersonalHoldingInAssetTypeEnum.fd;
        case r'gold': return PersonalHoldingInAssetTypeEnum.gold;
        case r'other': return PersonalHoldingInAssetTypeEnum.other;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalHoldingInAssetTypeEnumTypeTransformer] instance.
  static PersonalHoldingInAssetTypeEnumTypeTransformer? _instance;
}



class PersonalHoldingInValuationSourceEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalHoldingInValuationSourceEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const manual = PersonalHoldingInValuationSourceEnum._(r'manual');

  /// List of all possible values in this [enum][PersonalHoldingInValuationSourceEnum].
  static const values = <PersonalHoldingInValuationSourceEnum>[
    manual,
  ];

  static PersonalHoldingInValuationSourceEnum? fromJson(dynamic value) => PersonalHoldingInValuationSourceEnumTypeTransformer().decode(value);

  static List<PersonalHoldingInValuationSourceEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalHoldingInValuationSourceEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalHoldingInValuationSourceEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalHoldingInValuationSourceEnum] to String,
/// and [decode] dynamic data back to [PersonalHoldingInValuationSourceEnum].
class PersonalHoldingInValuationSourceEnumTypeTransformer {
  factory PersonalHoldingInValuationSourceEnumTypeTransformer() => _instance ??= const PersonalHoldingInValuationSourceEnumTypeTransformer._();

  const PersonalHoldingInValuationSourceEnumTypeTransformer._();

  String encode(PersonalHoldingInValuationSourceEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalHoldingInValuationSourceEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalHoldingInValuationSourceEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'manual': return PersonalHoldingInValuationSourceEnum.manual;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalHoldingInValuationSourceEnumTypeTransformer] instance.
  static PersonalHoldingInValuationSourceEnumTypeTransformer? _instance;
}


