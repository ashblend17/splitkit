//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalAllocationPlanOut {
  /// Returns a new [PersonalAllocationPlanOut] instance.
  PersonalAllocationPlanOut({
    required this.id,
    required this.sourceTransactionId,
    required this.ruleId,
    required this.snapshotKind,
    this.snapshotPercentBp,
    this.snapshotAmountMinor,
    required this.plannedMinor,
    required this.currency,
    this.goalId,
    this.accountId,
    this.actingAdminId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
  });

  String id;

  String sourceTransactionId;

  String ruleId;

  PersonalAllocationPlanOutSnapshotKindEnum snapshotKind;

  int? snapshotPercentBp;

  int? snapshotAmountMinor;

  int plannedMinor;

  String currency;

  String? goalId;

  String? accountId;

  String? actingAdminId;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? deletedAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalAllocationPlanOut &&
    other.id == id &&
    other.sourceTransactionId == sourceTransactionId &&
    other.ruleId == ruleId &&
    other.snapshotKind == snapshotKind &&
    other.snapshotPercentBp == snapshotPercentBp &&
    other.snapshotAmountMinor == snapshotAmountMinor &&
    other.plannedMinor == plannedMinor &&
    other.currency == currency &&
    other.goalId == goalId &&
    other.accountId == accountId &&
    other.actingAdminId == actingAdminId &&
    other.createdAt == createdAt &&
    other.updatedAt == updatedAt &&
    other.deletedAt == deletedAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (sourceTransactionId.hashCode) +
    (ruleId.hashCode) +
    (snapshotKind.hashCode) +
    (snapshotPercentBp == null ? 0 : snapshotPercentBp!.hashCode) +
    (snapshotAmountMinor == null ? 0 : snapshotAmountMinor!.hashCode) +
    (plannedMinor.hashCode) +
    (currency.hashCode) +
    (goalId == null ? 0 : goalId!.hashCode) +
    (accountId == null ? 0 : accountId!.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (createdAt.hashCode) +
    (updatedAt.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'PersonalAllocationPlanOut[id=$id, sourceTransactionId=$sourceTransactionId, ruleId=$ruleId, snapshotKind=$snapshotKind, snapshotPercentBp=$snapshotPercentBp, snapshotAmountMinor=$snapshotAmountMinor, plannedMinor=$plannedMinor, currency=$currency, goalId=$goalId, accountId=$accountId, actingAdminId=$actingAdminId, createdAt=$createdAt, updatedAt=$updatedAt, deletedAt=$deletedAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'source_transaction_id'] = this.sourceTransactionId;
      json[r'rule_id'] = this.ruleId;
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

  /// Returns a new [PersonalAllocationPlanOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalAllocationPlanOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalAllocationPlanOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalAllocationPlanOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalAllocationPlanOut(
        id: mapValueOfType<String>(json, r'id')!,
        sourceTransactionId: mapValueOfType<String>(json, r'source_transaction_id')!,
        ruleId: mapValueOfType<String>(json, r'rule_id')!,
        snapshotKind: PersonalAllocationPlanOutSnapshotKindEnum.fromJson(json[r'snapshot_kind'])!,
        snapshotPercentBp: mapValueOfType<int>(json, r'snapshot_percent_bp'),
        snapshotAmountMinor: mapValueOfType<int>(json, r'snapshot_amount_minor'),
        plannedMinor: mapValueOfType<int>(json, r'planned_minor')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        goalId: mapValueOfType<String>(json, r'goal_id'),
        accountId: mapValueOfType<String>(json, r'account_id'),
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<PersonalAllocationPlanOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAllocationPlanOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAllocationPlanOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalAllocationPlanOut> mapFromJson(dynamic json) {
    final map = <String, PersonalAllocationPlanOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalAllocationPlanOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalAllocationPlanOut-objects as value to a dart map
  static Map<String, List<PersonalAllocationPlanOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalAllocationPlanOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalAllocationPlanOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'source_transaction_id',
    'rule_id',
    'snapshot_kind',
    'planned_minor',
    'currency',
    'created_at',
    'updated_at',
    'version',
  };
}


class PersonalAllocationPlanOutSnapshotKindEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalAllocationPlanOutSnapshotKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const percentage = PersonalAllocationPlanOutSnapshotKindEnum._(r'percentage');
  static const fixed = PersonalAllocationPlanOutSnapshotKindEnum._(r'fixed');

  /// List of all possible values in this [enum][PersonalAllocationPlanOutSnapshotKindEnum].
  static const values = <PersonalAllocationPlanOutSnapshotKindEnum>[
    percentage,
    fixed,
  ];

  static PersonalAllocationPlanOutSnapshotKindEnum? fromJson(dynamic value) => PersonalAllocationPlanOutSnapshotKindEnumTypeTransformer().decode(value);

  static List<PersonalAllocationPlanOutSnapshotKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalAllocationPlanOutSnapshotKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalAllocationPlanOutSnapshotKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalAllocationPlanOutSnapshotKindEnum] to String,
/// and [decode] dynamic data back to [PersonalAllocationPlanOutSnapshotKindEnum].
class PersonalAllocationPlanOutSnapshotKindEnumTypeTransformer {
  factory PersonalAllocationPlanOutSnapshotKindEnumTypeTransformer() => _instance ??= const PersonalAllocationPlanOutSnapshotKindEnumTypeTransformer._();

  const PersonalAllocationPlanOutSnapshotKindEnumTypeTransformer._();

  String encode(PersonalAllocationPlanOutSnapshotKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalAllocationPlanOutSnapshotKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalAllocationPlanOutSnapshotKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'percentage': return PersonalAllocationPlanOutSnapshotKindEnum.percentage;
        case r'fixed': return PersonalAllocationPlanOutSnapshotKindEnum.fixed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalAllocationPlanOutSnapshotKindEnumTypeTransformer] instance.
  static PersonalAllocationPlanOutSnapshotKindEnumTypeTransformer? _instance;
}


