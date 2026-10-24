//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TricountConflictOut {
  /// Returns a new [TricountConflictOut] instance.
  TricountConflictOut({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.entity,
    required this.local,
    required this.tricount,
    required this.createdAt,
  });

  String id;

  String groupId;

  String groupName;

  TricountConflictOutEntityEnum entity;

  ConflictSideOut local;

  ConflictSideOut tricount;

  DateTime createdAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TricountConflictOut &&
    other.id == id &&
    other.groupId == groupId &&
    other.groupName == groupName &&
    other.entity == entity &&
    other.local == local &&
    other.tricount == tricount &&
    other.createdAt == createdAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (groupId.hashCode) +
    (groupName.hashCode) +
    (entity.hashCode) +
    (local.hashCode) +
    (tricount.hashCode) +
    (createdAt.hashCode);

  @override
  String toString() => 'TricountConflictOut[id=$id, groupId=$groupId, groupName=$groupName, entity=$entity, local=$local, tricount=$tricount, createdAt=$createdAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'group_id'] = this.groupId;
      json[r'group_name'] = this.groupName;
      json[r'entity'] = this.entity;
      json[r'local'] = this.local;
      json[r'tricount'] = this.tricount;
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [TricountConflictOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TricountConflictOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "TricountConflictOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "TricountConflictOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return TricountConflictOut(
        id: mapValueOfType<String>(json, r'id')!,
        groupId: mapValueOfType<String>(json, r'group_id')!,
        groupName: mapValueOfType<String>(json, r'group_name')!,
        entity: TricountConflictOutEntityEnum.fromJson(json[r'entity'])!,
        local: ConflictSideOut.fromJson(json[r'local'])!,
        tricount: ConflictSideOut.fromJson(json[r'tricount'])!,
        createdAt: mapDateTime(json, r'created_at', r'')!,
      );
    }
    return null;
  }

  static List<TricountConflictOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TricountConflictOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TricountConflictOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TricountConflictOut> mapFromJson(dynamic json) {
    final map = <String, TricountConflictOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TricountConflictOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TricountConflictOut-objects as value to a dart map
  static Map<String, List<TricountConflictOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TricountConflictOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TricountConflictOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'group_id',
    'group_name',
    'entity',
    'local',
    'tricount',
    'created_at',
  };
}


class TricountConflictOutEntityEnum {
  /// Instantiate a new enum with the provided [value].
  const TricountConflictOutEntityEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const expense = TricountConflictOutEntityEnum._(r'expense');
  static const payment = TricountConflictOutEntityEnum._(r'payment');

  /// List of all possible values in this [enum][TricountConflictOutEntityEnum].
  static const values = <TricountConflictOutEntityEnum>[
    expense,
    payment,
  ];

  static TricountConflictOutEntityEnum? fromJson(dynamic value) => TricountConflictOutEntityEnumTypeTransformer().decode(value);

  static List<TricountConflictOutEntityEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TricountConflictOutEntityEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TricountConflictOutEntityEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [TricountConflictOutEntityEnum] to String,
/// and [decode] dynamic data back to [TricountConflictOutEntityEnum].
class TricountConflictOutEntityEnumTypeTransformer {
  factory TricountConflictOutEntityEnumTypeTransformer() => _instance ??= const TricountConflictOutEntityEnumTypeTransformer._();

  const TricountConflictOutEntityEnumTypeTransformer._();

  String encode(TricountConflictOutEntityEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a TricountConflictOutEntityEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  TricountConflictOutEntityEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'expense': return TricountConflictOutEntityEnum.expense;
        case r'payment': return TricountConflictOutEntityEnum.payment;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [TricountConflictOutEntityEnumTypeTransformer] instance.
  static TricountConflictOutEntityEnumTypeTransformer? _instance;
}


