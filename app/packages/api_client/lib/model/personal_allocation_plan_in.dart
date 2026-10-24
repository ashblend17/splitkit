//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalAllocationPlanIn {
  /// Returns a new [PersonalAllocationPlanIn] instance.
  PersonalAllocationPlanIn({
    this.id,
    this.version,
    this.sourceTransactionId,
    this.ruleId,
    this.goalId,
    this.accountId,
    required this.snapshotKind,
    this.snapshotPercentBp,
    this.snapshotAmountMinor,
    required this.plannedMinor,
  });

  String? id;

  int? version;

  String? sourceTransactionId;

  String? ruleId;

  String? goalId;

  String? accountId;

  PersonalAllocationPlanInSnapshotKindEnum snapshotKind;

  /// Minimum value: 1
  /// Maximum value: 100000
  int? snapshotPercentBp;

  /// Maximum value: 9999999999
  int? snapshotAmountMinor;

  /// Maximum value: 9999999999
  int plannedMinor;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalAllocationPlanIn &&
    other.id == id &&
    other.version == version &&
    other.sourceTransactionId == sourceTransactionId &&
    other.ruleId == ruleId &&
    other.goalId == goalId &&
    other.accountId == accountId &&
    other.snapshotKind == snapshotKind &&
    other.snapshotPercentBp == snapshotPercentBp &&
    other.snapshotAmountMinor == snapshotAmountMinor &&
    other.plannedMinor == plannedMinor;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (sourceTransactionId == null ? 0 : sourceTransactionId!.hashCode) +
    (ruleId == null ? 0 : ruleId!.hashCode) +
    (goalId == null ? 0 : goalId!.hashCode) +
    (accountId == null ? 0 : accountId!.hashCode) +
    (snapshotKind.hashCode) +
    (snapshotPercentBp == null ? 0 : snapshotPercentBp!.hashCode) +
    (snapshotAmountMinor == null ? 0 : snapshotAmountMinor!.hashCode) +
    (plannedMinor.hashCode);

  @override
  String toString() => 'PersonalAllocationPlanIn[id=$id, version=$version, sourceTransactionId=$sourceTransactionId, ruleId=$ruleId, goalId=$goalId, accountId=$accountId, snapshotKind=$snapshotKind, snapshotPercentBp=$snapshotPercentBp, snapshotAmountMinor=$snapshotAmountMinor, plannedMinor=$plannedMinor]';

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
    if (this.sourceTransactionId != null) {
      json[r'source_transaction_id'] = this.sourceTransactionId;
    } else {
      json[r'source_transaction_id'] = null;
    }
    if (this.ruleId != null) {
      json[r'rule_id'] = this.ruleId;
    } else {
      json[r'rule_id'] = null;
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
      json[r'snapshot_kind'] = this.snapshotKind;
    if (this.snapshotPercentBp != null) {
      json[r'snapshot_percent_bp'] = this.snapshotPercentBp;
    } else {
      json[r'snapshot_percent_bp'] = null;
    }
    if (this.snapshotAmountMinor != null) {
      json[r'snapshot_amount_minor'] = this.snapshotAmountMinor;
    } else {
      json[r'snapshot_amount_minor'] = null;
    }
      json[r'planned_minor'] = this.plannedMinor;
    return json;
  }

  /// Returns a new [PersonalAllocationPlanIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalAllocationPlanIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalAllocationPlanIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalAllocationPlanIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalAllocationPlanIn(
        id: mapValueOfType<String>(json, r'id'),
        version: mapValueOfType<int>(json, r'version'),
        sourceTransactionId: mapValueOfType<String>(json, r'source_transaction_id'),
        ruleId: mapValueOfType<String>(json, r'rule_id'),
        goalId: mapValueOfType<String>(json, r'goal_id'),
        accountId: mapValueOfType<String>(json, r'account_id'),
        snapshotKind: PersonalAllocationPlanInSnapshotKindEnum.fromJson(json[r'snapshot_kind'])!,
        snapshotPercentBp: mapValueOfType<int>(json, r'snapshot_percent_bp'),
        snapshotAmountMinor: mapValueOfType<int>(json, r'snapshot_amount_minor'),
        plannedMinor: mapValueOfType<int>(json, r'planned_minor')!,
      );
    }
    return null;
  }

  static List<PersonalAllocationPlanIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAllocationPlanIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAllocationPlanIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalAllocationPlanIn> mapFromJson(dynamic json) {
    final map = <String, PersonalAllocationPlanIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalAllocationPlanIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalAllocationPlanIn-objects as value to a dart map
  static Map<String, List<PersonalAllocationPlanIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalAllocationPlanIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalAllocationPlanIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'snapshot_kind',
    'planned_minor',
  };
}


class PersonalAllocationPlanInSnapshotKindEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalAllocationPlanInSnapshotKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const percentage = PersonalAllocationPlanInSnapshotKindEnum._(r'percentage');
  static const fixed = PersonalAllocationPlanInSnapshotKindEnum._(r'fixed');

  /// List of all possible values in this [enum][PersonalAllocationPlanInSnapshotKindEnum].
  static const values = <PersonalAllocationPlanInSnapshotKindEnum>[
    percentage,
    fixed,
  ];

  static PersonalAllocationPlanInSnapshotKindEnum? fromJson(dynamic value) => PersonalAllocationPlanInSnapshotKindEnumTypeTransformer().decode(value);

  static List<PersonalAllocationPlanInSnapshotKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAllocationPlanInSnapshotKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAllocationPlanInSnapshotKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalAllocationPlanInSnapshotKindEnum] to String,
/// and [decode] dynamic data back to [PersonalAllocationPlanInSnapshotKindEnum].
class PersonalAllocationPlanInSnapshotKindEnumTypeTransformer {
  factory PersonalAllocationPlanInSnapshotKindEnumTypeTransformer() => _instance ??= const PersonalAllocationPlanInSnapshotKindEnumTypeTransformer._();

  const PersonalAllocationPlanInSnapshotKindEnumTypeTransformer._();

  String encode(PersonalAllocationPlanInSnapshotKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalAllocationPlanInSnapshotKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalAllocationPlanInSnapshotKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'percentage': return PersonalAllocationPlanInSnapshotKindEnum.percentage;
        case r'fixed': return PersonalAllocationPlanInSnapshotKindEnum.fixed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalAllocationPlanInSnapshotKindEnumTypeTransformer] instance.
  static PersonalAllocationPlanInSnapshotKindEnumTypeTransformer? _instance;
}


