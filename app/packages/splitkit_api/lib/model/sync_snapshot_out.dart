//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SyncSnapshotOut {
  /// Returns a new [SyncSnapshotOut] instance.
  SyncSnapshotOut({
    required this.stream,
    required this.headSeq,
    this.entities = const [],
  });

  String stream;

  int headSeq;

  List<SyncEntity> entities;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SyncSnapshotOut &&
    other.stream == stream &&
    other.headSeq == headSeq &&
    _deepEquality.equals(other.entities, entities);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (stream.hashCode) +
    (headSeq.hashCode) +
    (entities.hashCode);

  @override
  String toString() => 'SyncSnapshotOut[stream=$stream, headSeq=$headSeq, entities=$entities]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'stream'] = this.stream;
      json[r'head_seq'] = this.headSeq;
      json[r'entities'] = this.entities;
    return json;
  }

  /// Returns a new [SyncSnapshotOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SyncSnapshotOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SyncSnapshotOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SyncSnapshotOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SyncSnapshotOut(
        stream: mapValueOfType<String>(json, r'stream')!,
        headSeq: mapValueOfType<int>(json, r'head_seq')!,
        entities: SyncEntity.listFromJson(json[r'entities']),
      );
    }
    return null;
  }

  static List<SyncSnapshotOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncSnapshotOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncSnapshotOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SyncSnapshotOut> mapFromJson(dynamic json) {
    final map = <String, SyncSnapshotOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SyncSnapshotOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SyncSnapshotOut-objects as value to a dart map
  static Map<String, List<SyncSnapshotOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SyncSnapshotOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SyncSnapshotOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'stream',
    'head_seq',
    'entities',
  };
}

