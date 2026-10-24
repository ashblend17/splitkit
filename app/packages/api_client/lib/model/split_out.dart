//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SplitOut {
  /// Returns a new [SplitOut] instance.
  SplitOut({
    required this.user,
    required this.shareMinor,
    this.inputValue,
    required this.status,
  });

  UserBrief user;

  int shareMinor;

  String? inputValue;

  SplitOutStatusEnum status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SplitOut &&
    other.user == user &&
    other.shareMinor == shareMinor &&
    other.inputValue == inputValue &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (user.hashCode) +
    (shareMinor.hashCode) +
    (inputValue == null ? 0 : inputValue!.hashCode) +
    (status.hashCode);

  @override
  String toString() => 'SplitOut[user=$user, shareMinor=$shareMinor, inputValue=$inputValue, status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'user'] = this.user;
      json[r'share_minor'] = this.shareMinor;
    if (this.inputValue != null) {
      json[r'input_value'] = this.inputValue;
    } else {
      json[r'input_value'] = null;
    }
      json[r'status'] = this.status;
    return json;
  }

  /// Returns a new [SplitOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SplitOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SplitOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SplitOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SplitOut(
        user: UserBrief.fromJson(json[r'user'])!,
        shareMinor: mapValueOfType<int>(json, r'share_minor')!,
        inputValue: mapValueOfType<String>(json, r'input_value'),
        status: SplitOutStatusEnum.fromJson(json[r'status'])!,
      );
    }
    return null;
  }

  static List<SplitOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SplitOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SplitOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SplitOut> mapFromJson(dynamic json) {
    final map = <String, SplitOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SplitOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SplitOut-objects as value to a dart map
  static Map<String, List<SplitOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SplitOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SplitOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'user',
    'share_minor',
    'status',
  };
}


class SplitOutStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const SplitOutStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const paid = SplitOutStatusEnum._(r'paid');
  static const owes = SplitOutStatusEnum._(r'owes');
  static const settled = SplitOutStatusEnum._(r'settled');

  /// List of all possible values in this [enum][SplitOutStatusEnum].
  static const values = <SplitOutStatusEnum>[
    paid,
    owes,
    settled,
  ];

  static SplitOutStatusEnum? fromJson(dynamic value) => SplitOutStatusEnumTypeTransformer().decode(value);

  static List<SplitOutStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SplitOutStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SplitOutStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SplitOutStatusEnum] to String,
/// and [decode] dynamic data back to [SplitOutStatusEnum].
class SplitOutStatusEnumTypeTransformer {
  factory SplitOutStatusEnumTypeTransformer() => _instance ??= const SplitOutStatusEnumTypeTransformer._();

  const SplitOutStatusEnumTypeTransformer._();

  String encode(SplitOutStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SplitOutStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SplitOutStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'paid': return SplitOutStatusEnum.paid;
        case r'owes': return SplitOutStatusEnum.owes;
        case r'settled': return SplitOutStatusEnum.settled;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SplitOutStatusEnumTypeTransformer] instance.
  static SplitOutStatusEnumTypeTransformer? _instance;
}


