//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalBatchResult {
  /// Returns a new [PersonalBatchResult] instance.
  PersonalBatchResult({
    required this.kind,
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

  PersonalBatchResultKindEnum kind;

  PersonalAccountOut? account;

  PersonalTxnOut? transaction;

  PersonalGoalOut? goal;

  PersonalGoalContributionOut? goalContribution;

  PersonalAllocationRuleOut? allocationRule;

  PersonalAllocationPlanOut? allocationPlan;

  PersonalHoldingOut? holding;

  PersonalReminderStateOut? reminderState;

  PersonalReminderScheduleOut? reminderSchedule;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalBatchResult &&
    other.kind == kind &&
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
  String toString() => 'PersonalBatchResult[kind=$kind, account=$account, transaction=$transaction, goal=$goal, goalContribution=$goalContribution, allocationRule=$allocationRule, allocationPlan=$allocationPlan, holding=$holding, reminderState=$reminderState, reminderSchedule=$reminderSchedule]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'kind'] = this.kind;
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

  /// Returns a new [PersonalBatchResult] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalBatchResult? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalBatchResult[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalBatchResult[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalBatchResult(
        kind: PersonalBatchResultKindEnum.fromJson(json[r'kind'])!,
        account: PersonalAccountOut.fromJson(json[r'account']),
        transaction: PersonalTxnOut.fromJson(json[r'transaction']),
        goal: PersonalGoalOut.fromJson(json[r'goal']),
        goalContribution: PersonalGoalContributionOut.fromJson(json[r'goal_contribution']),
        allocationRule: PersonalAllocationRuleOut.fromJson(json[r'allocation_rule']),
        allocationPlan: PersonalAllocationPlanOut.fromJson(json[r'allocation_plan']),
        holding: PersonalHoldingOut.fromJson(json[r'holding']),
        reminderState: PersonalReminderStateOut.fromJson(json[r'reminder_state']),
        reminderSchedule: PersonalReminderScheduleOut.fromJson(json[r'reminder_schedule']),
      );
    }
    return null;
  }

  static List<PersonalBatchResult> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalBatchResult>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalBatchResult.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalBatchResult> mapFromJson(dynamic json) {
    final map = <String, PersonalBatchResult>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalBatchResult.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalBatchResult-objects as value to a dart map
  static Map<String, List<PersonalBatchResult>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalBatchResult>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalBatchResult.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'kind',
  };
}


class PersonalBatchResultKindEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalBatchResultKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const account = PersonalBatchResultKindEnum._(r'account');
  static const transaction = PersonalBatchResultKindEnum._(r'transaction');
  static const goal = PersonalBatchResultKindEnum._(r'goal');
  static const goalContribution = PersonalBatchResultKindEnum._(r'goal_contribution');
  static const allocationRule = PersonalBatchResultKindEnum._(r'allocation_rule');
  static const allocationPlan = PersonalBatchResultKindEnum._(r'allocation_plan');
  static const holding = PersonalBatchResultKindEnum._(r'holding');
  static const reminderState = PersonalBatchResultKindEnum._(r'reminder_state');
  static const reminderSchedule = PersonalBatchResultKindEnum._(r'reminder_schedule');

  /// List of all possible values in this [enum][PersonalBatchResultKindEnum].
  static const values = <PersonalBatchResultKindEnum>[
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

  static PersonalBatchResultKindEnum? fromJson(dynamic value) => PersonalBatchResultKindEnumTypeTransformer().decode(value);

  static List<PersonalBatchResultKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalBatchResultKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalBatchResultKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalBatchResultKindEnum] to String,
/// and [decode] dynamic data back to [PersonalBatchResultKindEnum].
class PersonalBatchResultKindEnumTypeTransformer {
  factory PersonalBatchResultKindEnumTypeTransformer() => _instance ??= const PersonalBatchResultKindEnumTypeTransformer._();

  const PersonalBatchResultKindEnumTypeTransformer._();

  String encode(PersonalBatchResultKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalBatchResultKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalBatchResultKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'account': return PersonalBatchResultKindEnum.account;
        case r'transaction': return PersonalBatchResultKindEnum.transaction;
        case r'goal': return PersonalBatchResultKindEnum.goal;
        case r'goal_contribution': return PersonalBatchResultKindEnum.goalContribution;
        case r'allocation_rule': return PersonalBatchResultKindEnum.allocationRule;
        case r'allocation_plan': return PersonalBatchResultKindEnum.allocationPlan;
        case r'holding': return PersonalBatchResultKindEnum.holding;
        case r'reminder_state': return PersonalBatchResultKindEnum.reminderState;
        case r'reminder_schedule': return PersonalBatchResultKindEnum.reminderSchedule;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalBatchResultKindEnumTypeTransformer] instance.
  static PersonalBatchResultKindEnumTypeTransformer? _instance;
}


