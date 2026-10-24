//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalAllocationRuleIn {
  /// Returns a new [PersonalAllocationRuleIn] instance.
  PersonalAllocationRuleIn({
    this.id,
    this.version,
    required this.kind,
    this.percentBp,
    this.amountMinor,
    this.name,
    required this.trigger,
    this.sourceCategoryId,
    this.sourceAccountId,
    this.goalId,
    this.accountId,
    this.active = true,
    this.priority = 0,
  });

  String? id;

  int? version;

  PersonalAllocationRuleInKindEnum kind;

  /// Minimum value: 1
  /// Maximum value: 100000
  int? percentBp;

  /// Maximum value: 9999999999
  int? amountMinor;

  String? name;

  PersonalAllocationRuleInTriggerEnum trigger;

  String? sourceCategoryId;

  String? sourceAccountId;

  String? goalId;

  String? accountId;

  bool active;

  /// Minimum value: 0
  /// Maximum value: 1000
  int priority;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalAllocationRuleIn &&
    other.id == id &&
    other.version == version &&
    other.kind == kind &&
    other.percentBp == percentBp &&
    other.amountMinor == amountMinor &&
    other.name == name &&
    other.trigger == trigger &&
    other.sourceCategoryId == sourceCategoryId &&
    other.sourceAccountId == sourceAccountId &&
    other.goalId == goalId &&
    other.accountId == accountId &&
    other.active == active &&
    other.priority == priority;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (kind.hashCode) +
    (percentBp == null ? 0 : percentBp!.hashCode) +
    (amountMinor == null ? 0 : amountMinor!.hashCode) +
    (name == null ? 0 : name!.hashCode) +
    (trigger.hashCode) +
    (sourceCategoryId == null ? 0 : sourceCategoryId!.hashCode) +
    (sourceAccountId == null ? 0 : sourceAccountId!.hashCode) +
    (goalId == null ? 0 : goalId!.hashCode) +
    (accountId == null ? 0 : accountId!.hashCode) +
    (active.hashCode) +
    (priority.hashCode);

  @override
  String toString() => 'PersonalAllocationRuleIn[id=$id, version=$version, kind=$kind, percentBp=$percentBp, amountMinor=$amountMinor, name=$name, trigger=$trigger, sourceCategoryId=$sourceCategoryId, sourceAccountId=$sourceAccountId, goalId=$goalId, accountId=$accountId, active=$active, priority=$priority]';

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
    return json;
  }

  /// Returns a new [PersonalAllocationRuleIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalAllocationRuleIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalAllocationRuleIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalAllocationRuleIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalAllocationRuleIn(
        id: mapValueOfType<String>(json, r'id'),
        version: mapValueOfType<int>(json, r'version'),
        kind: PersonalAllocationRuleInKindEnum.fromJson(json[r'kind'])!,
        percentBp: mapValueOfType<int>(json, r'percent_bp'),
        amountMinor: mapValueOfType<int>(json, r'amount_minor'),
        name: mapValueOfType<String>(json, r'name'),
        trigger: PersonalAllocationRuleInTriggerEnum.fromJson(json[r'trigger'])!,
        sourceCategoryId: mapValueOfType<String>(json, r'source_category_id'),
        sourceAccountId: mapValueOfType<String>(json, r'source_account_id'),
        goalId: mapValueOfType<String>(json, r'goal_id'),
        accountId: mapValueOfType<String>(json, r'account_id'),
        active: mapValueOfType<bool>(json, r'active') ?? true,
        priority: mapValueOfType<int>(json, r'priority') ?? 0,
      );
    }
    return null;
  }

  static List<PersonalAllocationRuleIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAllocationRuleIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAllocationRuleIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalAllocationRuleIn> mapFromJson(dynamic json) {
    final map = <String, PersonalAllocationRuleIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalAllocationRuleIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalAllocationRuleIn-objects as value to a dart map
  static Map<String, List<PersonalAllocationRuleIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalAllocationRuleIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalAllocationRuleIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'kind',
    'trigger',
  };
}


class PersonalAllocationRuleInKindEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalAllocationRuleInKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const percentage = PersonalAllocationRuleInKindEnum._(r'percentage');
  static const fixed = PersonalAllocationRuleInKindEnum._(r'fixed');

  /// List of all possible values in this [enum][PersonalAllocationRuleInKindEnum].
  static const values = <PersonalAllocationRuleInKindEnum>[
    percentage,
    fixed,
  ];

  static PersonalAllocationRuleInKindEnum? fromJson(dynamic value) => PersonalAllocationRuleInKindEnumTypeTransformer().decode(value);

  static List<PersonalAllocationRuleInKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAllocationRuleInKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAllocationRuleInKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalAllocationRuleInKindEnum] to String,
/// and [decode] dynamic data back to [PersonalAllocationRuleInKindEnum].
class PersonalAllocationRuleInKindEnumTypeTransformer {
  factory PersonalAllocationRuleInKindEnumTypeTransformer() => _instance ??= const PersonalAllocationRuleInKindEnumTypeTransformer._();

  const PersonalAllocationRuleInKindEnumTypeTransformer._();

  String encode(PersonalAllocationRuleInKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalAllocationRuleInKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalAllocationRuleInKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'percentage': return PersonalAllocationRuleInKindEnum.percentage;
        case r'fixed': return PersonalAllocationRuleInKindEnum.fixed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalAllocationRuleInKindEnumTypeTransformer] instance.
  static PersonalAllocationRuleInKindEnumTypeTransformer? _instance;
}



class PersonalAllocationRuleInTriggerEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalAllocationRuleInTriggerEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const incomeRecorded = PersonalAllocationRuleInTriggerEnum._(r'income_recorded');

  /// List of all possible values in this [enum][PersonalAllocationRuleInTriggerEnum].
  static const values = <PersonalAllocationRuleInTriggerEnum>[
    incomeRecorded,
  ];

  static PersonalAllocationRuleInTriggerEnum? fromJson(dynamic value) => PersonalAllocationRuleInTriggerEnumTypeTransformer().decode(value);

  static List<PersonalAllocationRuleInTriggerEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAllocationRuleInTriggerEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAllocationRuleInTriggerEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalAllocationRuleInTriggerEnum] to String,
/// and [decode] dynamic data back to [PersonalAllocationRuleInTriggerEnum].
class PersonalAllocationRuleInTriggerEnumTypeTransformer {
  factory PersonalAllocationRuleInTriggerEnumTypeTransformer() => _instance ??= const PersonalAllocationRuleInTriggerEnumTypeTransformer._();

  const PersonalAllocationRuleInTriggerEnumTypeTransformer._();

  String encode(PersonalAllocationRuleInTriggerEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalAllocationRuleInTriggerEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalAllocationRuleInTriggerEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'income_recorded': return PersonalAllocationRuleInTriggerEnum.incomeRecorded;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalAllocationRuleInTriggerEnumTypeTransformer] instance.
  static PersonalAllocationRuleInTriggerEnumTypeTransformer? _instance;
}


