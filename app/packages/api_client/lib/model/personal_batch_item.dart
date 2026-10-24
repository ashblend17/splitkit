//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalBatchItem {
  /// Returns a new [PersonalBatchItem] instance.
  PersonalBatchItem({
    required this.kind,
    required this.op,
    required this.id,
    this.version,
    this.account,
    this.transaction,
    this.goal,
    this.goalContribution,
    this.allocationRule,
    this.allocationPlan,
    this.holding,
    this.reminderState,
    this.reminderSchedule,
  });

  PersonalBatchItemKindEnum kind;

  PersonalBatchItemOpEnum op;

  String id;

  int? version;

  PersonalAccountIn? account;

  PersonalTxnIn? transaction;

  PersonalGoalIn? goal;

  PersonalGoalContributionIn? goalContribution;

  PersonalAllocationRuleIn? allocationRule;

  PersonalAllocationPlanIn? allocationPlan;

  PersonalHoldingIn? holding;

  PersonalReminderStateIn? reminderState;

  PersonalReminderScheduleIn? reminderSchedule;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalBatchItem &&
    other.kind == kind &&
    other.op == op &&
    other.id == id &&
    other.version == version &&
    other.account == account &&
    other.transaction == transaction &&
    other.goal == goal &&
    other.goalContribution == goalContribution &&
    other.allocationRule == allocationRule &&
    other.allocationPlan == allocationPlan &&
    other.holding == holding &&
    other.reminderState == reminderState &&
    other.reminderSchedule == reminderSchedule;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (kind.hashCode) +
    (op.hashCode) +
    (id.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (account == null ? 0 : account!.hashCode) +
    (transaction == null ? 0 : transaction!.hashCode) +
    (goal == null ? 0 : goal!.hashCode) +
    (goalContribution == null ? 0 : goalContribution!.hashCode) +
    (allocationRule == null ? 0 : allocationRule!.hashCode) +
    (allocationPlan == null ? 0 : allocationPlan!.hashCode) +
    (holding == null ? 0 : holding!.hashCode) +
    (reminderState == null ? 0 : reminderState!.hashCode) +
    (reminderSchedule == null ? 0 : reminderSchedule!.hashCode);

  @override
  String toString() => 'PersonalBatchItem[kind=$kind, op=$op, id=$id, version=$version, account=$account, transaction=$transaction, goal=$goal, goalContribution=$goalContribution, allocationRule=$allocationRule, allocationPlan=$allocationPlan, holding=$holding, reminderState=$reminderState, reminderSchedule=$reminderSchedule]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'kind'] = this.kind;
      json[r'op'] = this.op;
      json[r'id'] = this.id;
    if (this.version != null) {
      json[r'version'] = this.version;
    } else {
      json[r'version'] = null;
    }
    if (this.account != null) {
      json[r'account'] = this.account;
    } else {
      json[r'account'] = null;
    }
    if (this.transaction != null) {
      json[r'transaction'] = this.transaction;
    } else {
      json[r'transaction'] = null;
    }
    if (this.goal != null) {
      json[r'goal'] = this.goal;
    } else {
      json[r'goal'] = null;
    }
    if (this.goalContribution != null) {
      json[r'goal_contribution'] = this.goalContribution;
    } else {
      json[r'goal_contribution'] = null;
    }
    if (this.allocationRule != null) {
      json[r'allocation_rule'] = this.allocationRule;
    } else {
      json[r'allocation_rule'] = null;
    }
    if (this.allocationPlan != null) {
      json[r'allocation_plan'] = this.allocationPlan;
    } else {
      json[r'allocation_plan'] = null;
    }
    if (this.holding != null) {
      json[r'holding'] = this.holding;
    } else {
      json[r'holding'] = null;
    }
    if (this.reminderState != null) {
      json[r'reminder_state'] = this.reminderState;
    } else {
      json[r'reminder_state'] = null;
    }
    if (this.reminderSchedule != null) {
      json[r'reminder_schedule'] = this.reminderSchedule;
    } else {
      json[r'reminder_schedule'] = null;
    }
    return json;
  }

  /// Returns a new [PersonalBatchItem] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalBatchItem? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalBatchItem[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalBatchItem[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalBatchItem(
        kind: PersonalBatchItemKindEnum.fromJson(json[r'kind'])!,
        op: PersonalBatchItemOpEnum.fromJson(json[r'op'])!,
        id: mapValueOfType<String>(json, r'id')!,
        version: mapValueOfType<int>(json, r'version'),
        account: PersonalAccountIn.fromJson(json[r'account']),
        transaction: PersonalTxnIn.fromJson(json[r'transaction']),
        goal: PersonalGoalIn.fromJson(json[r'goal']),
        goalContribution: PersonalGoalContributionIn.fromJson(json[r'goal_contribution']),
        allocationRule: PersonalAllocationRuleIn.fromJson(json[r'allocation_rule']),
        allocationPlan: PersonalAllocationPlanIn.fromJson(json[r'allocation_plan']),
        holding: PersonalHoldingIn.fromJson(json[r'holding']),
        reminderState: PersonalReminderStateIn.fromJson(json[r'reminder_state']),
        reminderSchedule: PersonalReminderScheduleIn.fromJson(json[r'reminder_schedule']),
      );
    }
    return null;
  }

  static List<PersonalBatchItem> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalBatchItem>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalBatchItem.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalBatchItem> mapFromJson(dynamic json) {
    final map = <String, PersonalBatchItem>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalBatchItem.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalBatchItem-objects as value to a dart map
  static Map<String, List<PersonalBatchItem>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalBatchItem>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalBatchItem.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'kind',
    'op',
    'id',
  };
}


class PersonalBatchItemKindEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalBatchItemKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const account = PersonalBatchItemKindEnum._(r'account');
  static const transaction = PersonalBatchItemKindEnum._(r'transaction');
  static const goal = PersonalBatchItemKindEnum._(r'goal');
  static const goalContribution = PersonalBatchItemKindEnum._(r'goal_contribution');
  static const allocationRule = PersonalBatchItemKindEnum._(r'allocation_rule');
  static const allocationPlan = PersonalBatchItemKindEnum._(r'allocation_plan');
  static const holding = PersonalBatchItemKindEnum._(r'holding');
  static const reminderState = PersonalBatchItemKindEnum._(r'reminder_state');
  static const reminderSchedule = PersonalBatchItemKindEnum._(r'reminder_schedule');

  /// List of all possible values in this [enum][PersonalBatchItemKindEnum].
  static const values = <PersonalBatchItemKindEnum>[
    account,
    transaction,
    goal,
    goalContribution,
    allocationRule,
    allocationPlan,
    holding,
    reminderState,
    reminderSchedule,
  ];

  static PersonalBatchItemKindEnum? fromJson(dynamic value) => PersonalBatchItemKindEnumTypeTransformer().decode(value);

  static List<PersonalBatchItemKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalBatchItemKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalBatchItemKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalBatchItemKindEnum] to String,
/// and [decode] dynamic data back to [PersonalBatchItemKindEnum].
class PersonalBatchItemKindEnumTypeTransformer {
  factory PersonalBatchItemKindEnumTypeTransformer() => _instance ??= const PersonalBatchItemKindEnumTypeTransformer._();

  const PersonalBatchItemKindEnumTypeTransformer._();

  String encode(PersonalBatchItemKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalBatchItemKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalBatchItemKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'account': return PersonalBatchItemKindEnum.account;
        case r'transaction': return PersonalBatchItemKindEnum.transaction;
        case r'goal': return PersonalBatchItemKindEnum.goal;
        case r'goal_contribution': return PersonalBatchItemKindEnum.goalContribution;
        case r'allocation_rule': return PersonalBatchItemKindEnum.allocationRule;
        case r'allocation_plan': return PersonalBatchItemKindEnum.allocationPlan;
        case r'holding': return PersonalBatchItemKindEnum.holding;
        case r'reminder_state': return PersonalBatchItemKindEnum.reminderState;
        case r'reminder_schedule': return PersonalBatchItemKindEnum.reminderSchedule;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalBatchItemKindEnumTypeTransformer] instance.
  static PersonalBatchItemKindEnumTypeTransformer? _instance;
}



class PersonalBatchItemOpEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalBatchItemOpEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const create = PersonalBatchItemOpEnum._(r'create');
  static const update = PersonalBatchItemOpEnum._(r'update');
  static const delete = PersonalBatchItemOpEnum._(r'delete');

  /// List of all possible values in this [enum][PersonalBatchItemOpEnum].
  static const values = <PersonalBatchItemOpEnum>[
    create,
    update,
    delete,
  ];

  static PersonalBatchItemOpEnum? fromJson(dynamic value) => PersonalBatchItemOpEnumTypeTransformer().decode(value);

  static List<PersonalBatchItemOpEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalBatchItemOpEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalBatchItemOpEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalBatchItemOpEnum] to String,
/// and [decode] dynamic data back to [PersonalBatchItemOpEnum].
class PersonalBatchItemOpEnumTypeTransformer {
  factory PersonalBatchItemOpEnumTypeTransformer() => _instance ??= const PersonalBatchItemOpEnumTypeTransformer._();

  const PersonalBatchItemOpEnumTypeTransformer._();

  String encode(PersonalBatchItemOpEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalBatchItemOpEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalBatchItemOpEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'create': return PersonalBatchItemOpEnum.create;
        case r'update': return PersonalBatchItemOpEnum.update;
        case r'delete': return PersonalBatchItemOpEnum.delete;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalBatchItemOpEnumTypeTransformer] instance.
  static PersonalBatchItemOpEnumTypeTransformer? _instance;
}


