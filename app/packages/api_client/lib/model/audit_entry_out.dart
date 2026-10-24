//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuditEntryOut {
  /// Returns a new [AuditEntryOut] instance.
  AuditEntryOut({
    required this.id,
    required this.at,
    required this.action,
    required this.entity,
    this.entityId,
    this.actor,
    this.actingAs,
    required this.doneAs,
    required this.summary,
    this.group,
    this.diff = const {},
  });

  String id;

  DateTime at;

  String action;

  String entity;

  String? entityId;

  UserBrief? actor;

  UserBrief? actingAs;

  AuditEntryOutDoneAsEnum doneAs;

  String summary;

  GroupRef? group;

  Map<String, Object> diff;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AuditEntryOut &&
    other.id == id &&
    other.at == at &&
    other.action == action &&
    other.entity == entity &&
    other.entityId == entityId &&
    other.actor == actor &&
    other.actingAs == actingAs &&
    other.doneAs == doneAs &&
    other.summary == summary &&
    other.group == group &&
    _deepEquality.equals(other.diff, diff);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (at.hashCode) +
    (action.hashCode) +
    (entity.hashCode) +
    (entityId == null ? 0 : entityId!.hashCode) +
    (actor == null ? 0 : actor!.hashCode) +
    (actingAs == null ? 0 : actingAs!.hashCode) +
    (doneAs.hashCode) +
    (summary.hashCode) +
    (group == null ? 0 : group!.hashCode) +
    (diff.hashCode);

  @override
  String toString() => 'AuditEntryOut[id=$id, at=$at, action=$action, entity=$entity, entityId=$entityId, actor=$actor, actingAs=$actingAs, doneAs=$doneAs, summary=$summary, group=$group, diff=$diff]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'at'] = this.at.toUtc().toIso8601String();
      json[r'action'] = this.action;
      json[r'entity'] = this.entity;
    if (this.entityId != null) {
      json[r'entity_id'] = this.entityId;
    } else {
      json[r'entity_id'] = null;
    }
    if (this.actor != null) {
      json[r'actor'] = this.actor;
    } else {
      json[r'actor'] = null;
    }
    if (this.actingAs != null) {
      json[r'acting_as'] = this.actingAs;
    } else {
      json[r'acting_as'] = null;
    }
      json[r'done_as'] = this.doneAs;
      json[r'summary'] = this.summary;
    if (this.group != null) {
      json[r'group'] = this.group;
    } else {
      json[r'group'] = null;
    }
      json[r'diff'] = this.diff;
    return json;
  }

  /// Returns a new [AuditEntryOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AuditEntryOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AuditEntryOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AuditEntryOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AuditEntryOut(
        id: mapValueOfType<String>(json, r'id')!,
        at: mapDateTime(json, r'at', r'')!,
        action: mapValueOfType<String>(json, r'action')!,
        entity: mapValueOfType<String>(json, r'entity')!,
        entityId: mapValueOfType<String>(json, r'entity_id'),
        actor: UserBrief.fromJson(json[r'actor']),
        actingAs: UserBrief.fromJson(json[r'acting_as']),
        doneAs: AuditEntryOutDoneAsEnum.fromJson(json[r'done_as'])!,
        summary: mapValueOfType<String>(json, r'summary')!,
        group: GroupRef.fromJson(json[r'group']),
        diff: mapCastOfType<String, Object>(json, r'diff')!,
      );
    }
    return null;
  }

  static List<AuditEntryOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AuditEntryOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuditEntryOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AuditEntryOut> mapFromJson(dynamic json) {
    final map = <String, AuditEntryOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AuditEntryOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AuditEntryOut-objects as value to a dart map
  static Map<String, List<AuditEntryOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AuditEntryOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AuditEntryOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'at',
    'action',
    'entity',
    'done_as',
    'summary',
    'diff',
  };
}


class AuditEntryOutDoneAsEnum {
  /// Instantiate a new enum with the provided [value].
  const AuditEntryOutDoneAsEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const user = AuditEntryOutDoneAsEnum._(r'user');
  static const admin = AuditEntryOutDoneAsEnum._(r'admin');
  static const system = AuditEntryOutDoneAsEnum._(r'system');

  /// List of all possible values in this [enum][AuditEntryOutDoneAsEnum].
  static const values = <AuditEntryOutDoneAsEnum>[
    user,
    admin,
    system,
  ];

  static AuditEntryOutDoneAsEnum? fromJson(dynamic value) => AuditEntryOutDoneAsEnumTypeTransformer().decode(value);

  static List<AuditEntryOutDoneAsEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AuditEntryOutDoneAsEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuditEntryOutDoneAsEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AuditEntryOutDoneAsEnum] to String,
/// and [decode] dynamic data back to [AuditEntryOutDoneAsEnum].
class AuditEntryOutDoneAsEnumTypeTransformer {
  factory AuditEntryOutDoneAsEnumTypeTransformer() => _instance ??= const AuditEntryOutDoneAsEnumTypeTransformer._();

  const AuditEntryOutDoneAsEnumTypeTransformer._();

  String encode(AuditEntryOutDoneAsEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AuditEntryOutDoneAsEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AuditEntryOutDoneAsEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'user': return AuditEntryOutDoneAsEnum.user;
        case r'admin': return AuditEntryOutDoneAsEnum.admin;
        case r'system': return AuditEntryOutDoneAsEnum.system;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AuditEntryOutDoneAsEnumTypeTransformer] instance.
  static AuditEntryOutDoneAsEnumTypeTransformer? _instance;
}


