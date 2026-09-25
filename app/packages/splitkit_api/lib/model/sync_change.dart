//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SyncChange {
  /// Returns a new [SyncChange] instance.
  SyncChange({
    required this.seq,
    required this.action,
    required this.entity,
    required this.entityId,
    required this.op,
    this.version,
    this.data = const {},
    this.actorId,
    this.actingAdminId,
    required this.at,
  });

  int seq;

  String action;

  String entity;

  String entityId;

  SyncChangeOpEnum op;

  int? version;

  Map<String, Object>? data;

  String? actorId;

  String? actingAdminId;

  DateTime at;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SyncChange &&
    other.seq == seq &&
    other.action == action &&
    other.entity == entity &&
    other.entityId == entityId &&
    other.op == op &&
    other.version == version &&
    _deepEquality.equals(other.data, data) &&
    other.actorId == actorId &&
    other.actingAdminId == actingAdminId &&
    other.at == at;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (seq.hashCode) +
    (action.hashCode) +
    (entity.hashCode) +
    (entityId.hashCode) +
    (op.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (data == null ? 0 : data!.hashCode) +
    (actorId == null ? 0 : actorId!.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (at.hashCode);

  @override
  String toString() => 'SyncChange[seq=$seq, action=$action, entity=$entity, entityId=$entityId, op=$op, version=$version, data=$data, actorId=$actorId, actingAdminId=$actingAdminId, at=$at]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'seq'] = this.seq;
      json[r'action'] = this.action;
      json[r'entity'] = this.entity;
      json[r'entity_id'] = this.entityId;
      json[r'op'] = this.op;
    if (this.version != null) {
      json[r'version'] = this.version;
    } else {
      json[r'version'] = null;
    }
    if (this.data != null) {
      json[r'data'] = this.data;
    } else {
      json[r'data'] = null;
    }
    if (this.actorId != null) {
      json[r'actor_id'] = this.actorId;
    } else {
      json[r'actor_id'] = null;
    }
    if (this.actingAdminId != null) {
      json[r'acting_admin_id'] = this.actingAdminId;
    } else {
      json[r'acting_admin_id'] = null;
    }
      json[r'at'] = this.at.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [SyncChange] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SyncChange? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SyncChange[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SyncChange[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SyncChange(
        seq: mapValueOfType<int>(json, r'seq')!,
        action: mapValueOfType<String>(json, r'action')!,
        entity: mapValueOfType<String>(json, r'entity')!,
        entityId: mapValueOfType<String>(json, r'entity_id')!,
        op: SyncChangeOpEnum.fromJson(json[r'op'])!,
        version: mapValueOfType<int>(json, r'version'),
        data: mapCastOfType<String, Object>(json, r'data') ?? const {},
        actorId: mapValueOfType<String>(json, r'actor_id'),
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        at: mapDateTime(json, r'at', r'')!,
      );
    }
    return null;
  }

  static List<SyncChange> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncChange>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncChange.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SyncChange> mapFromJson(dynamic json) {
    final map = <String, SyncChange>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SyncChange.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SyncChange-objects as value to a dart map
  static Map<String, List<SyncChange>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SyncChange>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SyncChange.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'seq',
    'action',
    'entity',
    'entity_id',
    'op',
    'at',
  };
}


class SyncChangeOpEnum {
  /// Instantiate a new enum with the provided [value].
  const SyncChangeOpEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const upsert = SyncChangeOpEnum._(r'upsert');
  static const delete = SyncChangeOpEnum._(r'delete');

  /// List of all possible values in this [enum][SyncChangeOpEnum].
  static const values = <SyncChangeOpEnum>[
    upsert,
    delete,
  ];

  static SyncChangeOpEnum? fromJson(dynamic value) => SyncChangeOpEnumTypeTransformer().decode(value);

  static List<SyncChangeOpEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncChangeOpEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncChangeOpEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SyncChangeOpEnum] to String,
/// and [decode] dynamic data back to [SyncChangeOpEnum].
class SyncChangeOpEnumTypeTransformer {
  factory SyncChangeOpEnumTypeTransformer() => _instance ??= const SyncChangeOpEnumTypeTransformer._();

  const SyncChangeOpEnumTypeTransformer._();

  String encode(SyncChangeOpEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SyncChangeOpEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SyncChangeOpEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'upsert': return SyncChangeOpEnum.upsert;
        case r'delete': return SyncChangeOpEnum.delete;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SyncChangeOpEnumTypeTransformer] instance.
  static SyncChangeOpEnumTypeTransformer? _instance;
}


