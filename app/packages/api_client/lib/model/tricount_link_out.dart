//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TricountLinkOut {
  /// Returns a new [TricountLinkOut] instance.
  TricountLinkOut({
    required this.groupId,
    required this.shareLink,
    required this.state,
    this.lastError,
    this.warnings = const [],
    this.lastSyncedAt,
    required this.linkedAt,
    required this.linkedBy,
    this.conflicts = const [],
  });

  String groupId;

  String shareLink;

  TricountLinkOutStateEnum state;

  String? lastError;

  List<String> warnings;

  DateTime? lastSyncedAt;

  DateTime linkedAt;

  UserBrief linkedBy;

  List<TricountConflictOut> conflicts;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TricountLinkOut &&
    other.groupId == groupId &&
    other.shareLink == shareLink &&
    other.state == state &&
    other.lastError == lastError &&
    _deepEquality.equals(other.warnings, warnings) &&
    other.lastSyncedAt == lastSyncedAt &&
    other.linkedAt == linkedAt &&
    other.linkedBy == linkedBy &&
    _deepEquality.equals(other.conflicts, conflicts);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (groupId.hashCode) +
    (shareLink.hashCode) +
    (state.hashCode) +
    (lastError == null ? 0 : lastError!.hashCode) +
    (warnings.hashCode) +
    (lastSyncedAt == null ? 0 : lastSyncedAt!.hashCode) +
    (linkedAt.hashCode) +
    (linkedBy.hashCode) +
    (conflicts.hashCode);

  @override
  String toString() => 'TricountLinkOut[groupId=$groupId, shareLink=$shareLink, state=$state, lastError=$lastError, warnings=$warnings, lastSyncedAt=$lastSyncedAt, linkedAt=$linkedAt, linkedBy=$linkedBy, conflicts=$conflicts]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'group_id'] = this.groupId;
      json[r'share_link'] = this.shareLink;
      json[r'state'] = this.state;
    if (this.lastError != null) {
      json[r'last_error'] = this.lastError;
    } else {
      json[r'last_error'] = null;
    }
      json[r'warnings'] = this.warnings;
    if (this.lastSyncedAt != null) {
      json[r'last_synced_at'] = this.lastSyncedAt!.toUtc().toIso8601String();
    } else {
      json[r'last_synced_at'] = null;
    }
      json[r'linked_at'] = this.linkedAt.toUtc().toIso8601String();
      json[r'linked_by'] = this.linkedBy;
      json[r'conflicts'] = this.conflicts;
    return json;
  }

  /// Returns a new [TricountLinkOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TricountLinkOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "TricountLinkOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "TricountLinkOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return TricountLinkOut(
        groupId: mapValueOfType<String>(json, r'group_id')!,
        shareLink: mapValueOfType<String>(json, r'share_link')!,
        state: TricountLinkOutStateEnum.fromJson(json[r'state'])!,
        lastError: mapValueOfType<String>(json, r'last_error'),
        warnings: json[r'warnings'] is Iterable
            ? (json[r'warnings'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        lastSyncedAt: mapDateTime(json, r'last_synced_at', r''),
        linkedAt: mapDateTime(json, r'linked_at', r'')!,
        linkedBy: UserBrief.fromJson(json[r'linked_by'])!,
        conflicts: TricountConflictOut.listFromJson(json[r'conflicts']),
      );
    }
    return null;
  }

  static List<TricountLinkOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TricountLinkOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TricountLinkOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TricountLinkOut> mapFromJson(dynamic json) {
    final map = <String, TricountLinkOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TricountLinkOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TricountLinkOut-objects as value to a dart map
  static Map<String, List<TricountLinkOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TricountLinkOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TricountLinkOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'group_id',
    'share_link',
    'state',
    'warnings',
    'linked_at',
    'linked_by',
    'conflicts',
  };
}


class TricountLinkOutStateEnum {
  /// Instantiate a new enum with the provided [value].
  const TricountLinkOutStateEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const syncing = TricountLinkOutStateEnum._(r'syncing');
  static const ok = TricountLinkOutStateEnum._(r'ok');
  static const error = TricountLinkOutStateEnum._(r'error');

  /// List of all possible values in this [enum][TricountLinkOutStateEnum].
  static const values = <TricountLinkOutStateEnum>[
    syncing,
    ok,
    error,
  ];

  static TricountLinkOutStateEnum? fromJson(dynamic value) => TricountLinkOutStateEnumTypeTransformer().decode(value);

  static List<TricountLinkOutStateEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TricountLinkOutStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TricountLinkOutStateEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [TricountLinkOutStateEnum] to String,
/// and [decode] dynamic data back to [TricountLinkOutStateEnum].
class TricountLinkOutStateEnumTypeTransformer {
  factory TricountLinkOutStateEnumTypeTransformer() => _instance ??= const TricountLinkOutStateEnumTypeTransformer._();

  const TricountLinkOutStateEnumTypeTransformer._();

  String encode(TricountLinkOutStateEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a TricountLinkOutStateEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  TricountLinkOutStateEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'syncing': return TricountLinkOutStateEnum.syncing;
        case r'ok': return TricountLinkOutStateEnum.ok;
        case r'error': return TricountLinkOutStateEnum.error;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [TricountLinkOutStateEnumTypeTransformer] instance.
  static TricountLinkOutStateEnumTypeTransformer? _instance;
}


