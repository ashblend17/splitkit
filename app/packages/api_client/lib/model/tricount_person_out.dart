//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TricountPersonOut {
  /// Returns a new [TricountPersonOut] instance.
  TricountPersonOut({
    required this.memberUuid,
    required this.name,
    this.suggested,
    required this.state,
  });

  String memberUuid;

  String name;

  UserBrief? suggested;

  TricountPersonOutStateEnum state;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TricountPersonOut &&
    other.memberUuid == memberUuid &&
    other.name == name &&
    other.suggested == suggested &&
    other.state == state;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (memberUuid.hashCode) +
    (name.hashCode) +
    (suggested == null ? 0 : suggested!.hashCode) +
    (state.hashCode);

  @override
  String toString() => 'TricountPersonOut[memberUuid=$memberUuid, name=$name, suggested=$suggested, state=$state]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'member_uuid'] = this.memberUuid;
      json[r'name'] = this.name;
    if (this.suggested != null) {
      json[r'suggested'] = this.suggested;
    } else {
      json[r'suggested'] = null;
    }
      json[r'state'] = this.state;
    return json;
  }

  /// Returns a new [TricountPersonOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TricountPersonOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "TricountPersonOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "TricountPersonOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return TricountPersonOut(
        memberUuid: mapValueOfType<String>(json, r'member_uuid')!,
        name: mapValueOfType<String>(json, r'name')!,
        suggested: UserBrief.fromJson(json[r'suggested']),
        state: TricountPersonOutStateEnum.fromJson(json[r'state'])!,
      );
    }
    return null;
  }

  static List<TricountPersonOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TricountPersonOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TricountPersonOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TricountPersonOut> mapFromJson(dynamic json) {
    final map = <String, TricountPersonOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TricountPersonOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TricountPersonOut-objects as value to a dart map
  static Map<String, List<TricountPersonOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TricountPersonOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TricountPersonOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'member_uuid',
    'name',
    'state',
  };
}


class TricountPersonOutStateEnum {
  /// Instantiate a new enum with the provided [value].
  const TricountPersonOutStateEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const you = TricountPersonOutStateEnum._(r'you');
  static const matched = TricountPersonOutStateEnum._(r'matched');
  static const suggested = TricountPersonOutStateEnum._(r'suggested');
  static const unmatched = TricountPersonOutStateEnum._(r'unmatched');

  /// List of all possible values in this [enum][TricountPersonOutStateEnum].
  static const values = <TricountPersonOutStateEnum>[
    you,
    matched,
    suggested,
    unmatched,
  ];

  static TricountPersonOutStateEnum? fromJson(dynamic value) => TricountPersonOutStateEnumTypeTransformer().decode(value);

  static List<TricountPersonOutStateEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TricountPersonOutStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TricountPersonOutStateEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [TricountPersonOutStateEnum] to String,
/// and [decode] dynamic data back to [TricountPersonOutStateEnum].
class TricountPersonOutStateEnumTypeTransformer {
  factory TricountPersonOutStateEnumTypeTransformer() => _instance ??= const TricountPersonOutStateEnumTypeTransformer._();

  const TricountPersonOutStateEnumTypeTransformer._();

  String encode(TricountPersonOutStateEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a TricountPersonOutStateEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  TricountPersonOutStateEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'you': return TricountPersonOutStateEnum.you;
        case r'matched': return TricountPersonOutStateEnum.matched;
        case r'suggested': return TricountPersonOutStateEnum.suggested;
        case r'unmatched': return TricountPersonOutStateEnum.unmatched;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [TricountPersonOutStateEnumTypeTransformer] instance.
  static TricountPersonOutStateEnumTypeTransformer? _instance;
}


