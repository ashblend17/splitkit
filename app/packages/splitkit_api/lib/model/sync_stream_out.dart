//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SyncStreamOut {
  /// Returns a new [SyncStreamOut] instance.
  SyncStreamOut({
    required this.stream,
    required this.status,
    required this.headSeq,
    this.changes = const [],
    required this.hasMore,
  });

  String stream;

  SyncStreamOutStatusEnum status;

  int headSeq;

  List<SyncChange> changes;

  bool hasMore;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SyncStreamOut &&
    other.stream == stream &&
    other.status == status &&
    other.headSeq == headSeq &&
    _deepEquality.equals(other.changes, changes) &&
    other.hasMore == hasMore;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (stream.hashCode) +
    (status.hashCode) +
    (headSeq.hashCode) +
    (changes.hashCode) +
    (hasMore.hashCode);

  @override
  String toString() => 'SyncStreamOut[stream=$stream, status=$status, headSeq=$headSeq, changes=$changes, hasMore=$hasMore]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'stream'] = this.stream;
      json[r'status'] = this.status;
      json[r'head_seq'] = this.headSeq;
      json[r'changes'] = this.changes;
      json[r'has_more'] = this.hasMore;
    return json;
  }

  /// Returns a new [SyncStreamOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SyncStreamOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SyncStreamOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SyncStreamOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SyncStreamOut(
        stream: mapValueOfType<String>(json, r'stream')!,
        status: SyncStreamOutStatusEnum.fromJson(json[r'status'])!,
        headSeq: mapValueOfType<int>(json, r'head_seq')!,
        changes: SyncChange.listFromJson(json[r'changes']),
        hasMore: mapValueOfType<bool>(json, r'has_more')!,
      );
    }
    return null;
  }

  static List<SyncStreamOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncStreamOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncStreamOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SyncStreamOut> mapFromJson(dynamic json) {
    final map = <String, SyncStreamOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SyncStreamOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SyncStreamOut-objects as value to a dart map
  static Map<String, List<SyncStreamOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SyncStreamOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SyncStreamOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'stream',
    'status',
    'head_seq',
    'changes',
    'has_more',
  };
}


class SyncStreamOutStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const SyncStreamOutStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const ok = SyncStreamOutStatusEnum._(r'ok');
  static const snapshotRequired = SyncStreamOutStatusEnum._(r'snapshot_required');
  static const gone = SyncStreamOutStatusEnum._(r'gone');

  /// List of all possible values in this [enum][SyncStreamOutStatusEnum].
  static const values = <SyncStreamOutStatusEnum>[
    ok,
    snapshotRequired,
    gone,
  ];

  static SyncStreamOutStatusEnum? fromJson(dynamic value) => SyncStreamOutStatusEnumTypeTransformer().decode(value);

  static List<SyncStreamOutStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncStreamOutStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncStreamOutStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SyncStreamOutStatusEnum] to String,
/// and [decode] dynamic data back to [SyncStreamOutStatusEnum].
class SyncStreamOutStatusEnumTypeTransformer {
  factory SyncStreamOutStatusEnumTypeTransformer() => _instance ??= const SyncStreamOutStatusEnumTypeTransformer._();

  const SyncStreamOutStatusEnumTypeTransformer._();

  String encode(SyncStreamOutStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SyncStreamOutStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SyncStreamOutStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'ok': return SyncStreamOutStatusEnum.ok;
        case r'snapshot_required': return SyncStreamOutStatusEnum.snapshotRequired;
        case r'gone': return SyncStreamOutStatusEnum.gone;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SyncStreamOutStatusEnumTypeTransformer] instance.
  static SyncStreamOutStatusEnumTypeTransformer? _instance;
}


