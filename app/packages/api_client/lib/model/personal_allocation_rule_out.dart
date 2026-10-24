//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalAllocationRuleOut {
  /// Returns a new [PersonalAllocationRuleOut] instance.
  PersonalAllocationRuleOut({
    required this.id,
    this.name,
    required this.trigger,
    this.sourceCategoryId,
    this.sourceAccountId,
    required this.kind,
    this.percentBp,
    this.amountMinor,
    required this.currency,
    this.goalId,
    this.accountId,
    required this.active,
    required this.priority,
    this.actingAdminId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
  });

  String id;

  String? name;

  PersonalAllocationRuleOutTriggerEnum trigger;

  String? sourceCategoryId;

  String? sourceAccountId;

  PersonalAllocationRuleOutKindEnum kind;

  int? percentBp;

  int? amountMinor;

  String currency;

  String? goalId;

  String? accountId;

  bool active;

  int priority;

  String? actingAdminId;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? deletedAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalAllocationRuleOut &&
    other.id == id &&
    other.name == name &&
    other.trigger == trigger &&
    other.sourceCategoryId == sourceCategoryId &&
    other.sourceAccountId == sourceAccountId &&
    other.kind == kind &&
    other.percentBp == percentBp &&
    other.amountMinor == amountMinor &&
    other.currency == currency &&
    other.goalId == goalId &&
    other.accountId == accountId &&
    other.active == active &&
    other.priority == priority &&
    other.actingAdminId == actingAdminId &&
    other.createdAt == createdAt &&
    other.updatedAt == updatedAt &&
    other.deletedAt == deletedAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name == null ? 0 : name!.hashCode) +
    (trigger.hashCode) +
    (sourceCategoryId == null ? 0 : sourceCategoryId!.hashCode) +
    (sourceAccountId == null ? 0 : sourceAccountId!.hashCode) +
    (kind.hashCode) +
    (percentBp == null ? 0 : percentBp!.hashCode) +
    (amountMinor == null ? 0 : amountMinor!.hashCode) +
    (currency.hashCode) +
    (goalId == null ? 0 : goalId!.hashCode) +
    (accountId == null ? 0 : accountId!.hashCode) +
    (active.hashCode) +
    (priority.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (createdAt.hashCode) +
    (updatedAt.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'PersonalAllocationRuleOut[id=$id, name=$name, trigger=$trigger, sourceCategoryId=$sourceCategoryId, sourceAccountId=$sourceAccountId, kind=$kind, percentBp=$percentBp, amountMinor=$amountMinor, currency=$currency, goalId=$goalId, accountId=$accountId, active=$active, priority=$priority, actingAdminId=$actingAdminId, createdAt=$createdAt, updatedAt=$updatedAt, deletedAt=$deletedAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
    if (this.name != null) {
      json[r'name'] = this.name;
    } else {
      json[r'name'] = null;
    }
      json[r'trigger'] = this.trigger;
    if (this.sourceCategoryId != null) {
      json[r'source_category_id'] = this.sourceCategoryId;
    } else {
      json[r'source_category_id'] = null;
    }
    if (this.sourceAccountId != null) {
      json[r'source_account_id'] = this.sourceAccountId;
    } else {
      json[r'source_account_id'] = null;
    }
      json[r'kind'] = this.kind;
    if (this.percentBp != null) {
      json[r'percent_bp'] = this.percentBp;
    } else {
      json[r'percent_bp'] = null;
    }
    if (this.amountMinor != null) {
      json[r'amount_minor'] = this.amountMinor;
    } else {
      json[r'amount_minor'] = null;
    }
      json[r'currency'] = this.currency;
    if (this.goalId != null) {
      json[r'goal_id'] = this.goalId;
    } else {
      json[r'goal_id'] = null;
    }
    if (this.accountId != null) {
      json[r'account_id'] = this.accountId;
    } else {
      json[r'account_id'] = null;
    }
      json[r'active'] = this.active;
      json[r'priority'] = this.priority;
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

  /// Returns a new [PersonalAllocationRuleOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalAllocationRuleOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalAllocationRuleOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalAllocationRuleOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalAllocationRuleOut(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name'),
        trigger: PersonalAllocationRuleOutTriggerEnum.fromJson(json[r'trigger'])!,
        sourceCategoryId: mapValueOfType<String>(json, r'source_category_id'),
        sourceAccountId: mapValueOfType<String>(json, r'source_account_id'),
        kind: PersonalAllocationRuleOutKindEnum.fromJson(json[r'kind'])!,
        percentBp: mapValueOfType<int>(json, r'percent_bp'),
        amountMinor: mapValueOfType<int>(json, r'amount_minor'),
        currency: mapValueOfType<String>(json, r'currency')!,
        goalId: mapValueOfType<String>(json, r'goal_id'),
        accountId: mapValueOfType<String>(json, r'account_id'),
        active: mapValueOfType<bool>(json, r'active')!,
        priority: mapValueOfType<int>(json, r'priority')!,
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<PersonalAllocationRuleOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAllocationRuleOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAllocationRuleOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalAllocationRuleOut> mapFromJson(dynamic json) {
    final map = <String, PersonalAllocationRuleOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalAllocationRuleOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalAllocationRuleOut-objects as value to a dart map
  static Map<String, List<PersonalAllocationRuleOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalAllocationRuleOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalAllocationRuleOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'trigger',
    'kind',
    'currency',
    'active',
    'priority',
    'created_at',
    'updated_at',
    'version',
  };
}


class PersonalAllocationRuleOutTriggerEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalAllocationRuleOutTriggerEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const incomeRecorded = PersonalAllocationRuleOutTriggerEnum._(r'income_recorded');

  /// List of all possible values in this [enum][PersonalAllocationRuleOutTriggerEnum].
  static const values = <PersonalAllocationRuleOutTriggerEnum>[
    incomeRecorded,
  ];

  static PersonalAllocationRuleOutTriggerEnum? fromJson(dynamic value) => PersonalAllocationRuleOutTriggerEnumTypeTransformer().decode(value);

  static List<PersonalAllocationRuleOutTriggerEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAllocationRuleOutTriggerEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAllocationRuleOutTriggerEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalAllocationRuleOutTriggerEnum] to String,
/// and [decode] dynamic data back to [PersonalAllocationRuleOutTriggerEnum].
class PersonalAllocationRuleOutTriggerEnumTypeTransformer {
  factory PersonalAllocationRuleOutTriggerEnumTypeTransformer() => _instance ??= const PersonalAllocationRuleOutTriggerEnumTypeTransformer._();

  const PersonalAllocationRuleOutTriggerEnumTypeTransformer._();

  String encode(PersonalAllocationRuleOutTriggerEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalAllocationRuleOutTriggerEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalAllocationRuleOutTriggerEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'income_recorded': return PersonalAllocationRuleOutTriggerEnum.incomeRecorded;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalAllocationRuleOutTriggerEnumTypeTransformer] instance.
  static PersonalAllocationRuleOutTriggerEnumTypeTransformer? _instance;
}



class PersonalAllocationRuleOutKindEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalAllocationRuleOutKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const percentage = PersonalAllocationRuleOutKindEnum._(r'percentage');
  static const fixed = PersonalAllocationRuleOutKindEnum._(r'fixed');

  /// List of all possible values in this [enum][PersonalAllocationRuleOutKindEnum].
  static const values = <PersonalAllocationRuleOutKindEnum>[
    percentage,
    fixed,
  ];

  static PersonalAllocationRuleOutKindEnum? fromJson(dynamic value) => PersonalAllocationRuleOutKindEnumTypeTransformer().decode(value);

  static List<PersonalAllocationRuleOutKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAllocationRuleOutKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAllocationRuleOutKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalAllocationRuleOutKindEnum] to String,
/// and [decode] dynamic data back to [PersonalAllocationRuleOutKindEnum].
class PersonalAllocationRuleOutKindEnumTypeTransformer {
  factory PersonalAllocationRuleOutKindEnumTypeTransformer() => _instance ??= const PersonalAllocationRuleOutKindEnumTypeTransformer._();

  const PersonalAllocationRuleOutKindEnumTypeTransformer._();

  String encode(PersonalAllocationRuleOutKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalAllocationRuleOutKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalAllocationRuleOutKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'percentage': return PersonalAllocationRuleOutKindEnum.percentage;
        case r'fixed': return PersonalAllocationRuleOutKindEnum.fixed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalAllocationRuleOutKindEnumTypeTransformer] instance.
  static PersonalAllocationRuleOutKindEnumTypeTransformer? _instance;
}


