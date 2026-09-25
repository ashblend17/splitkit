//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SystemOut {
  /// Returns a new [SystemOut] instance.
  SystemOut({
    required this.apiVersion,
    required this.database,
    required this.databaseBytes,
    this.lastImportAt,
    this.lastImportSource,
  });

  String apiVersion;

  String database;

  int databaseBytes;

  DateTime? lastImportAt;

  String? lastImportSource;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SystemOut &&
    other.apiVersion == apiVersion &&
    other.database == database &&
    other.databaseBytes == databaseBytes &&
    other.lastImportAt == lastImportAt &&
    other.lastImportSource == lastImportSource;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (apiVersion.hashCode) +
    (database.hashCode) +
    (databaseBytes.hashCode) +
    (lastImportAt == null ? 0 : lastImportAt!.hashCode) +
    (lastImportSource == null ? 0 : lastImportSource!.hashCode);

  @override
  String toString() => 'SystemOut[apiVersion=$apiVersion, database=$database, databaseBytes=$databaseBytes, lastImportAt=$lastImportAt, lastImportSource=$lastImportSource]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'api_version'] = this.apiVersion;
      json[r'database'] = this.database;
      json[r'database_bytes'] = this.databaseBytes;
    if (this.lastImportAt != null) {
      json[r'last_import_at'] = this.lastImportAt!.toUtc().toIso8601String();
    } else {
      json[r'last_import_at'] = null;
    }
    if (this.lastImportSource != null) {
      json[r'last_import_source'] = this.lastImportSource;
    } else {
      json[r'last_import_source'] = null;
    }
    return json;
  }

  /// Returns a new [SystemOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SystemOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SystemOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SystemOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SystemOut(
        apiVersion: mapValueOfType<String>(json, r'api_version')!,
        database: mapValueOfType<String>(json, r'database')!,
        databaseBytes: mapValueOfType<int>(json, r'database_bytes')!,
        lastImportAt: mapDateTime(json, r'last_import_at', r''),
        lastImportSource: mapValueOfType<String>(json, r'last_import_source'),
      );
    }
    return null;
  }

  static List<SystemOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SystemOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SystemOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SystemOut> mapFromJson(dynamic json) {
    final map = <String, SystemOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SystemOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SystemOut-objects as value to a dart map
  static Map<String, List<SystemOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SystemOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SystemOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'api_version',
    'database',
    'database_bytes',
  };
}

