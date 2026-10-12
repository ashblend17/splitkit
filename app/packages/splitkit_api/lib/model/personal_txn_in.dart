//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalTxnIn {
  /// Returns a new [PersonalTxnIn] instance.
  PersonalTxnIn({
    this.id,
    this.version,
    required this.type,
    required this.amountMinor,
    required this.description,
    required this.date,
    this.categoryId,
    this.notes,
    this.channel,
    this.merchant,
    this.account,
    this.expenseId,
    this.settlementId,
    this.reviewed = true,
    required this.source_,
    this.reference,
    this.balanceMinor,
    this.smsAt,
  });

  String? id;

  int? version;

  PersonalTxnInTypeEnum type;

  /// Maximum value: 9999999999
  int amountMinor;

  String description;

  DateTime date;

  String? categoryId;

  String? notes;

  PersonalTxnInChannelEnum? channel;

  String? merchant;

  String? account;

  String? expenseId;

  String? settlementId;

  bool reviewed;

  PersonalTxnInSource_Enum source_;

  String? reference;

  /// Minimum value: -1000000000000000
  /// Maximum value: 1000000000000000
  int? balanceMinor;

  DateTime? smsAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalTxnIn &&
    other.id == id &&
    other.version == version &&
    other.type == type &&
    other.amountMinor == amountMinor &&
    other.description == description &&
    other.date == date &&
    other.categoryId == categoryId &&
    other.notes == notes &&
    other.channel == channel &&
    other.merchant == merchant &&
    other.account == account &&
    other.expenseId == expenseId &&
    other.settlementId == settlementId &&
    other.reviewed == reviewed &&
    other.source_ == source_ &&
    other.reference == reference &&
    other.balanceMinor == balanceMinor &&
    other.smsAt == smsAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (type.hashCode) +
    (amountMinor.hashCode) +
    (description.hashCode) +
    (date.hashCode) +
    (categoryId == null ? 0 : categoryId!.hashCode) +
    (notes == null ? 0 : notes!.hashCode) +
    (channel == null ? 0 : channel!.hashCode) +
    (merchant == null ? 0 : merchant!.hashCode) +
    (account == null ? 0 : account!.hashCode) +
    (expenseId == null ? 0 : expenseId!.hashCode) +
    (settlementId == null ? 0 : settlementId!.hashCode) +
    (reviewed.hashCode) +
    (source_.hashCode) +
    (reference == null ? 0 : reference!.hashCode) +
    (balanceMinor == null ? 0 : balanceMinor!.hashCode) +
    (smsAt == null ? 0 : smsAt!.hashCode);

  @override
  String toString() => 'PersonalTxnIn[id=$id, version=$version, type=$type, amountMinor=$amountMinor, description=$description, date=$date, categoryId=$categoryId, notes=$notes, channel=$channel, merchant=$merchant, account=$account, expenseId=$expenseId, settlementId=$settlementId, reviewed=$reviewed, source_=$source_, reference=$reference, balanceMinor=$balanceMinor, smsAt=$smsAt]';

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
      json[r'type'] = this.type;
      json[r'amount_minor'] = this.amountMinor;
      json[r'description'] = this.description;
      json[r'date'] = _dateFormatter.format(this.date.toUtc());
    if (this.categoryId != null) {
      json[r'category_id'] = this.categoryId;
    } else {
      json[r'category_id'] = null;
    }
    if (this.notes != null) {
      json[r'notes'] = this.notes;
    } else {
      json[r'notes'] = null;
    }
    if (this.channel != null) {
      json[r'channel'] = this.channel;
    } else {
      json[r'channel'] = null;
    }
    if (this.merchant != null) {
      json[r'merchant'] = this.merchant;
    } else {
      json[r'merchant'] = null;
    }
    if (this.account != null) {
      json[r'account'] = this.account;
    } else {
      json[r'account'] = null;
    }
    if (this.expenseId != null) {
      json[r'expense_id'] = this.expenseId;
    } else {
      json[r'expense_id'] = null;
    }
    if (this.settlementId != null) {
      json[r'settlement_id'] = this.settlementId;
    } else {
      json[r'settlement_id'] = null;
    }
      json[r'reviewed'] = this.reviewed;
      json[r'source'] = this.source_;
    if (this.reference != null) {
      json[r'reference'] = this.reference;
    } else {
      json[r'reference'] = null;
    }
    if (this.balanceMinor != null) {
      json[r'balance_minor'] = this.balanceMinor;
    } else {
      json[r'balance_minor'] = null;
    }
    if (this.smsAt != null) {
      json[r'sms_at'] = this.smsAt!.toUtc().toIso8601String();
    } else {
      json[r'sms_at'] = null;
    }
    return json;
  }

  /// Returns a new [PersonalTxnIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalTxnIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalTxnIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalTxnIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalTxnIn(
        id: mapValueOfType<String>(json, r'id'),
        version: mapValueOfType<int>(json, r'version'),
        type: PersonalTxnInTypeEnum.fromJson(json[r'type'])!,
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
        description: mapValueOfType<String>(json, r'description')!,
        date: mapDateTime(json, r'date', r'')!,
        categoryId: mapValueOfType<String>(json, r'category_id'),
        notes: mapValueOfType<String>(json, r'notes'),
        channel: PersonalTxnInChannelEnum.fromJson(json[r'channel']),
        merchant: mapValueOfType<String>(json, r'merchant'),
        account: mapValueOfType<String>(json, r'account'),
        expenseId: mapValueOfType<String>(json, r'expense_id'),
        settlementId: mapValueOfType<String>(json, r'settlement_id'),
        reviewed: mapValueOfType<bool>(json, r'reviewed') ?? true,
        source_: PersonalTxnInSource_Enum.fromJson(json[r'source'])!,
        reference: mapValueOfType<String>(json, r'reference'),
        balanceMinor: mapValueOfType<int>(json, r'balance_minor'),
        smsAt: mapDateTime(json, r'sms_at', r''),
      );
    }
    return null;
  }

  static List<PersonalTxnIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalTxnIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalTxnIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalTxnIn> mapFromJson(dynamic json) {
    final map = <String, PersonalTxnIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalTxnIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalTxnIn-objects as value to a dart map
  static Map<String, List<PersonalTxnIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalTxnIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalTxnIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'type',
    'amount_minor',
    'description',
    'date',
    'source',
  };
}


class PersonalTxnInTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalTxnInTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const income = PersonalTxnInTypeEnum._(r'income');
  static const expense = PersonalTxnInTypeEnum._(r'expense');

  /// List of all possible values in this [enum][PersonalTxnInTypeEnum].
  static const values = <PersonalTxnInTypeEnum>[
    income,
    expense,
  ];

  static PersonalTxnInTypeEnum? fromJson(dynamic value) => PersonalTxnInTypeEnumTypeTransformer().decode(value);

  static List<PersonalTxnInTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalTxnInTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalTxnInTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalTxnInTypeEnum] to String,
/// and [decode] dynamic data back to [PersonalTxnInTypeEnum].
class PersonalTxnInTypeEnumTypeTransformer {
  factory PersonalTxnInTypeEnumTypeTransformer() => _instance ??= const PersonalTxnInTypeEnumTypeTransformer._();

  const PersonalTxnInTypeEnumTypeTransformer._();

  String encode(PersonalTxnInTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalTxnInTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalTxnInTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'income': return PersonalTxnInTypeEnum.income;
        case r'expense': return PersonalTxnInTypeEnum.expense;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalTxnInTypeEnumTypeTransformer] instance.
  static PersonalTxnInTypeEnumTypeTransformer? _instance;
}



class PersonalTxnInChannelEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalTxnInChannelEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const upi = PersonalTxnInChannelEnum._(r'upi');
  static const card = PersonalTxnInChannelEnum._(r'card');
  static const bank = PersonalTxnInChannelEnum._(r'bank');
  static const atm = PersonalTxnInChannelEnum._(r'atm');
  static const cash = PersonalTxnInChannelEnum._(r'cash');
  static const other = PersonalTxnInChannelEnum._(r'other');

  /// List of all possible values in this [enum][PersonalTxnInChannelEnum].
  static const values = <PersonalTxnInChannelEnum>[
    upi,
    card,
    bank,
    atm,
    cash,
    other,
  ];

  static PersonalTxnInChannelEnum? fromJson(dynamic value) => PersonalTxnInChannelEnumTypeTransformer().decode(value);

  static List<PersonalTxnInChannelEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalTxnInChannelEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalTxnInChannelEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalTxnInChannelEnum] to String,
/// and [decode] dynamic data back to [PersonalTxnInChannelEnum].
class PersonalTxnInChannelEnumTypeTransformer {
  factory PersonalTxnInChannelEnumTypeTransformer() => _instance ??= const PersonalTxnInChannelEnumTypeTransformer._();

  const PersonalTxnInChannelEnumTypeTransformer._();

  String encode(PersonalTxnInChannelEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalTxnInChannelEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalTxnInChannelEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'upi': return PersonalTxnInChannelEnum.upi;
        case r'card': return PersonalTxnInChannelEnum.card;
        case r'bank': return PersonalTxnInChannelEnum.bank;
        case r'atm': return PersonalTxnInChannelEnum.atm;
        case r'cash': return PersonalTxnInChannelEnum.cash;
        case r'other': return PersonalTxnInChannelEnum.other;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalTxnInChannelEnumTypeTransformer] instance.
  static PersonalTxnInChannelEnumTypeTransformer? _instance;
}



class PersonalTxnInSource_Enum {
  /// Instantiate a new enum with the provided [value].
  const PersonalTxnInSource_Enum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const manual = PersonalTxnInSource_Enum._(r'manual');
  static const sms = PersonalTxnInSource_Enum._(r'sms');

  /// List of all possible values in this [enum][PersonalTxnInSource_Enum].
  static const values = <PersonalTxnInSource_Enum>[
    manual,
    sms,
  ];

  static PersonalTxnInSource_Enum? fromJson(dynamic value) => PersonalTxnInSource_EnumTypeTransformer().decode(value);

  static List<PersonalTxnInSource_Enum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalTxnInSource_Enum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalTxnInSource_Enum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalTxnInSource_Enum] to String,
/// and [decode] dynamic data back to [PersonalTxnInSource_Enum].
class PersonalTxnInSource_EnumTypeTransformer {
  factory PersonalTxnInSource_EnumTypeTransformer() => _instance ??= const PersonalTxnInSource_EnumTypeTransformer._();

  const PersonalTxnInSource_EnumTypeTransformer._();

  String encode(PersonalTxnInSource_Enum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalTxnInSource_Enum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalTxnInSource_Enum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'manual': return PersonalTxnInSource_Enum.manual;
        case r'sms': return PersonalTxnInSource_Enum.sms;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalTxnInSource_EnumTypeTransformer] instance.
  static PersonalTxnInSource_EnumTypeTransformer? _instance;
}


