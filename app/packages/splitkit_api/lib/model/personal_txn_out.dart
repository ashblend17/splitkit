//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalTxnOut {
  /// Returns a new [PersonalTxnOut] instance.
  PersonalTxnOut({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.currency,
    required this.description,
    required this.date,
    this.category,
    this.notes,
    this.channel,
    this.merchant,
    this.account,
    required this.source_,
    this.reference,
    this.balanceMinor,
    this.smsAt,
    required this.reviewed,
    this.expenseId,
    this.settlementId,
    required this.counted,
    this.actingAdminId,
    required this.createdAt,
    this.deletedAt,
    required this.version,
  });

  String id;

  PersonalTxnOutTypeEnum type;

  int amountMinor;

  String currency;

  String description;

  DateTime date;

  CategoryOut? category;

  String? notes;

  PersonalTxnOutChannelEnum? channel;

  String? merchant;

  String? account;

  PersonalTxnOutSource_Enum source_;

  String? reference;

  int? balanceMinor;

  DateTime? smsAt;

  bool reviewed;

  String? expenseId;

  String? settlementId;

  bool counted;

  String? actingAdminId;

  DateTime createdAt;

  DateTime? deletedAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalTxnOut &&
    other.id == id &&
    other.type == type &&
    other.amountMinor == amountMinor &&
    other.currency == currency &&
    other.description == description &&
    other.date == date &&
    other.category == category &&
    other.notes == notes &&
    other.channel == channel &&
    other.merchant == merchant &&
    other.account == account &&
    other.source_ == source_ &&
    other.reference == reference &&
    other.balanceMinor == balanceMinor &&
    other.smsAt == smsAt &&
    other.reviewed == reviewed &&
    other.expenseId == expenseId &&
    other.settlementId == settlementId &&
    other.counted == counted &&
    other.actingAdminId == actingAdminId &&
    other.createdAt == createdAt &&
    other.deletedAt == deletedAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (type.hashCode) +
    (amountMinor.hashCode) +
    (currency.hashCode) +
    (description.hashCode) +
    (date.hashCode) +
    (category == null ? 0 : category!.hashCode) +
    (notes == null ? 0 : notes!.hashCode) +
    (channel == null ? 0 : channel!.hashCode) +
    (merchant == null ? 0 : merchant!.hashCode) +
    (account == null ? 0 : account!.hashCode) +
    (source_.hashCode) +
    (reference == null ? 0 : reference!.hashCode) +
    (balanceMinor == null ? 0 : balanceMinor!.hashCode) +
    (smsAt == null ? 0 : smsAt!.hashCode) +
    (reviewed.hashCode) +
    (expenseId == null ? 0 : expenseId!.hashCode) +
    (settlementId == null ? 0 : settlementId!.hashCode) +
    (counted.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (createdAt.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'PersonalTxnOut[id=$id, type=$type, amountMinor=$amountMinor, currency=$currency, description=$description, date=$date, category=$category, notes=$notes, channel=$channel, merchant=$merchant, account=$account, source_=$source_, reference=$reference, balanceMinor=$balanceMinor, smsAt=$smsAt, reviewed=$reviewed, expenseId=$expenseId, settlementId=$settlementId, counted=$counted, actingAdminId=$actingAdminId, createdAt=$createdAt, deletedAt=$deletedAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'type'] = this.type;
      json[r'amount_minor'] = this.amountMinor;
      json[r'currency'] = this.currency;
      json[r'description'] = this.description;
      json[r'date'] = _dateFormatter.format(this.date.toUtc());
    if (this.category != null) {
      json[r'category'] = this.category;
    } else {
      json[r'category'] = null;
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
      json[r'reviewed'] = this.reviewed;
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
      json[r'counted'] = this.counted;
    if (this.actingAdminId != null) {
      json[r'acting_admin_id'] = this.actingAdminId;
    } else {
      json[r'acting_admin_id'] = null;
    }
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
    if (this.deletedAt != null) {
      json[r'deleted_at'] = this.deletedAt!.toUtc().toIso8601String();
    } else {
      json[r'deleted_at'] = null;
    }
      json[r'version'] = this.version;
    return json;
  }

  /// Returns a new [PersonalTxnOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalTxnOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalTxnOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalTxnOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalTxnOut(
        id: mapValueOfType<String>(json, r'id')!,
        type: PersonalTxnOutTypeEnum.fromJson(json[r'type'])!,
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        description: mapValueOfType<String>(json, r'description')!,
        date: mapDateTime(json, r'date', r'')!,
        category: CategoryOut.fromJson(json[r'category']),
        notes: mapValueOfType<String>(json, r'notes'),
        channel: PersonalTxnOutChannelEnum.fromJson(json[r'channel']),
        merchant: mapValueOfType<String>(json, r'merchant'),
        account: mapValueOfType<String>(json, r'account'),
        source_: PersonalTxnOutSource_Enum.fromJson(json[r'source'])!,
        reference: mapValueOfType<String>(json, r'reference'),
        balanceMinor: mapValueOfType<int>(json, r'balance_minor'),
        smsAt: mapDateTime(json, r'sms_at', r''),
        reviewed: mapValueOfType<bool>(json, r'reviewed')!,
        expenseId: mapValueOfType<String>(json, r'expense_id'),
        settlementId: mapValueOfType<String>(json, r'settlement_id'),
        counted: mapValueOfType<bool>(json, r'counted')!,
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<PersonalTxnOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalTxnOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalTxnOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalTxnOut> mapFromJson(dynamic json) {
    final map = <String, PersonalTxnOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalTxnOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalTxnOut-objects as value to a dart map
  static Map<String, List<PersonalTxnOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalTxnOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalTxnOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'type',
    'amount_minor',
    'currency',
    'description',
    'date',
    'source',
    'reviewed',
    'counted',
    'created_at',
    'version',
  };
}


class PersonalTxnOutTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalTxnOutTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const income = PersonalTxnOutTypeEnum._(r'income');
  static const expense = PersonalTxnOutTypeEnum._(r'expense');

  /// List of all possible values in this [enum][PersonalTxnOutTypeEnum].
  static const values = <PersonalTxnOutTypeEnum>[
    income,
    expense,
  ];

  static PersonalTxnOutTypeEnum? fromJson(dynamic value) => PersonalTxnOutTypeEnumTypeTransformer().decode(value);

  static List<PersonalTxnOutTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalTxnOutTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalTxnOutTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalTxnOutTypeEnum] to String,
/// and [decode] dynamic data back to [PersonalTxnOutTypeEnum].
class PersonalTxnOutTypeEnumTypeTransformer {
  factory PersonalTxnOutTypeEnumTypeTransformer() => _instance ??= const PersonalTxnOutTypeEnumTypeTransformer._();

  const PersonalTxnOutTypeEnumTypeTransformer._();

  String encode(PersonalTxnOutTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalTxnOutTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalTxnOutTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'income': return PersonalTxnOutTypeEnum.income;
        case r'expense': return PersonalTxnOutTypeEnum.expense;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalTxnOutTypeEnumTypeTransformer] instance.
  static PersonalTxnOutTypeEnumTypeTransformer? _instance;
}



class PersonalTxnOutChannelEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalTxnOutChannelEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const upi = PersonalTxnOutChannelEnum._(r'upi');
  static const card = PersonalTxnOutChannelEnum._(r'card');
  static const bank = PersonalTxnOutChannelEnum._(r'bank');
  static const atm = PersonalTxnOutChannelEnum._(r'atm');
  static const cash = PersonalTxnOutChannelEnum._(r'cash');
  static const other = PersonalTxnOutChannelEnum._(r'other');

  /// List of all possible values in this [enum][PersonalTxnOutChannelEnum].
  static const values = <PersonalTxnOutChannelEnum>[
    upi,
    card,
    bank,
    atm,
    cash,
    other,
  ];

  static PersonalTxnOutChannelEnum? fromJson(dynamic value) => PersonalTxnOutChannelEnumTypeTransformer().decode(value);

  static List<PersonalTxnOutChannelEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalTxnOutChannelEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalTxnOutChannelEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalTxnOutChannelEnum] to String,
/// and [decode] dynamic data back to [PersonalTxnOutChannelEnum].
class PersonalTxnOutChannelEnumTypeTransformer {
  factory PersonalTxnOutChannelEnumTypeTransformer() => _instance ??= const PersonalTxnOutChannelEnumTypeTransformer._();

  const PersonalTxnOutChannelEnumTypeTransformer._();

  String encode(PersonalTxnOutChannelEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalTxnOutChannelEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalTxnOutChannelEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'upi': return PersonalTxnOutChannelEnum.upi;
        case r'card': return PersonalTxnOutChannelEnum.card;
        case r'bank': return PersonalTxnOutChannelEnum.bank;
        case r'atm': return PersonalTxnOutChannelEnum.atm;
        case r'cash': return PersonalTxnOutChannelEnum.cash;
        case r'other': return PersonalTxnOutChannelEnum.other;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalTxnOutChannelEnumTypeTransformer] instance.
  static PersonalTxnOutChannelEnumTypeTransformer? _instance;
}



class PersonalTxnOutSource_Enum {
  /// Instantiate a new enum with the provided [value].
  const PersonalTxnOutSource_Enum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const manual = PersonalTxnOutSource_Enum._(r'manual');
  static const sms = PersonalTxnOutSource_Enum._(r'sms');

  /// List of all possible values in this [enum][PersonalTxnOutSource_Enum].
  static const values = <PersonalTxnOutSource_Enum>[
    manual,
    sms,
  ];

  static PersonalTxnOutSource_Enum? fromJson(dynamic value) => PersonalTxnOutSource_EnumTypeTransformer().decode(value);

  static List<PersonalTxnOutSource_Enum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalTxnOutSource_Enum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalTxnOutSource_Enum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalTxnOutSource_Enum] to String,
/// and [decode] dynamic data back to [PersonalTxnOutSource_Enum].
class PersonalTxnOutSource_EnumTypeTransformer {
  factory PersonalTxnOutSource_EnumTypeTransformer() => _instance ??= const PersonalTxnOutSource_EnumTypeTransformer._();

  const PersonalTxnOutSource_EnumTypeTransformer._();

  String encode(PersonalTxnOutSource_Enum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalTxnOutSource_Enum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalTxnOutSource_Enum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'manual': return PersonalTxnOutSource_Enum.manual;
        case r'sms': return PersonalTxnOutSource_Enum.sms;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalTxnOutSource_EnumTypeTransformer] instance.
  static PersonalTxnOutSource_EnumTypeTransformer? _instance;
}


