//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SyncEntity {
  /// Returns a new [SyncEntity] instance.
  SyncEntity({
    required this.entity,
    required this.entityId,
    this.version,
    this.data = const {},
  });

  String entity;

  String entityId;

  int? version;

  Map<String, Object> data;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SyncEntity &&
    other.entity == entity &&
    other.entityId == entityId &&
    other.version == version &&
    _deepEquality.equals(other.data, data);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (entity.hashCode) +
    (entityId.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (data.hashCode);

  @override
  String toString() => 'SyncEntity[entity=$entity, entityId=$entityId, version=$version, data=$data]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'entity'] = this.entity;
      json[r'entity_id'] = this.entityId;
    if (this.version != null) {
      json[r'version'] = this.version;
    } else {
      json[r'version'] = null;
    }
      json[r'data'] = this.data;
    return json;
  }

  /// Returns a new [SyncEntity] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SyncEntity? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SyncEntity[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SyncEntity[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SyncEntity(
        entity: mapValueOfType<String>(json, r'entity')!,
        entityId: mapValueOfType<String>(json, r'entity_id')!,
        version: mapValueOfType<int>(json, r'version'),
        data: mapCastOfType<String, Object>(json, r'data')!,
      );
    }
    return null;
  }

  static List<SyncEntity> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncEntity>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncEntity.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SyncEntity> mapFromJson(dynamic json) {
    final map = <String, SyncEntity>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SyncEntity.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SyncEntity-objects as value to a dart map
  static Map<String, List<SyncEntity>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SyncEntity>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SyncEntity.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'entity',
    'entity_id',
    'data',
  };
}

