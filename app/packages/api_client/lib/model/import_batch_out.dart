//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportBatchOut {
  /// Returns a new [ImportBatchOut] instance.
  ImportBatchOut({
    required this.id,
    required this.source_,
    required this.fileName,
    this.groupId,
    this.groupName,
    required this.createdAt,
    this.undoneAt,
    required this.stats,
  });

  String id;

  String source_;

  String fileName;

  String? groupId;

  String? groupName;

  DateTime createdAt;

  DateTime? undoneAt;

  ImportStatsOut stats;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ImportBatchOut &&
    other.id == id &&
    other.source_ == source_ &&
    other.fileName == fileName &&
    other.groupId == groupId &&
    other.groupName == groupName &&
    other.createdAt == createdAt &&
    other.undoneAt == undoneAt &&
    other.stats == stats;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (source_.hashCode) +
    (fileName.hashCode) +
    (groupId == null ? 0 : groupId!.hashCode) +
    (groupName == null ? 0 : groupName!.hashCode) +
    (createdAt.hashCode) +
    (undoneAt == null ? 0 : undoneAt!.hashCode) +
    (stats.hashCode);

  @override
  String toString() => 'ImportBatchOut[id=$id, source_=$source_, fileName=$fileName, groupId=$groupId, groupName=$groupName, createdAt=$createdAt, undoneAt=$undoneAt, stats=$stats]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'source'] = this.source_;
      json[r'file_name'] = this.fileName;
    if (this.groupId != null) {
      json[r'group_id'] = this.groupId;
    } else {
      json[r'group_id'] = null;
    }
    if (this.groupName != null) {
      json[r'group_name'] = this.groupName;
    } else {
      json[r'group_name'] = null;
    }
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
    if (this.undoneAt != null) {
      json[r'undone_at'] = this.undoneAt!.toUtc().toIso8601String();
    } else {
      json[r'undone_at'] = null;
    }
      json[r'stats'] = this.stats;
    return json;
  }

  /// Returns a new [ImportBatchOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportBatchOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ImportBatchOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ImportBatchOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ImportBatchOut(
        id: mapValueOfType<String>(json, r'id')!,
        source_: mapValueOfType<String>(json, r'source')!,
        fileName: mapValueOfType<String>(json, r'file_name')!,
        groupId: mapValueOfType<String>(json, r'group_id'),
        groupName: mapValueOfType<String>(json, r'group_name'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        undoneAt: mapDateTime(json, r'undone_at', r''),
        stats: ImportStatsOut.fromJson(json[r'stats'])!,
      );
    }
    return null;
  }

  static List<ImportBatchOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ImportBatchOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportBatchOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportBatchOut> mapFromJson(dynamic json) {
    final map = <String, ImportBatchOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportBatchOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportBatchOut-objects as value to a dart map
  static Map<String, List<ImportBatchOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ImportBatchOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportBatchOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'source',
    'file_name',
    'created_at',
    'stats',
  };
}

