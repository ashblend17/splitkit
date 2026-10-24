//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalReminderStateIn {
  /// Returns a new [PersonalReminderStateIn] instance.
  PersonalReminderStateIn({
    this.id,
    this.version,
    this.dedupKey,
    required this.status,
    this.snoozedUntil,
  });

  String? id;

  int? version;

  String? dedupKey;

  PersonalReminderStateInStatusEnum status;

  DateTime? snoozedUntil;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalReminderStateIn &&
    other.id == id &&
    other.version == version &&
    other.dedupKey == dedupKey &&
    other.status == status &&
    other.snoozedUntil == snoozedUntil;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (dedupKey == null ? 0 : dedupKey!.hashCode) +
    (status.hashCode) +
    (snoozedUntil == null ? 0 : snoozedUntil!.hashCode);

  @override
  String toString() => 'PersonalReminderStateIn[id=$id, version=$version, dedupKey=$dedupKey, status=$status, snoozedUntil=$snoozedUntil]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.version != null) {
      json[r'version'] = this.version;
    } else {
      json[r'version'] = null;
    }
    if (this.dedupKey != null) {
      json[r'dedup_key'] = this.dedupKey;
    } else {
      json[r'dedup_key'] = null;
    }
      json[r'status'] = this.status;
    if (this.snoozedUntil != null) {
      json[r'snoozed_until'] = this.snoozedUntil!.toUtc().toIso8601String();
    } else {
      json[r'snoozed_until'] = null;
    }
    return json;
  }

  /// Returns a new [PersonalReminderStateIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalReminderStateIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalReminderStateIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalReminderStateIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalReminderStateIn(
        id: mapValueOfType<String>(json, r'id'),
        version: mapValueOfType<int>(json, r'version'),
        dedupKey: mapValueOfType<String>(json, r'dedup_key'),
        status: PersonalReminderStateInStatusEnum.fromJson(json[r'status'])!,
        snoozedUntil: mapDateTime(json, r'snoozed_until', r''),
      );
    }
    return null;
  }

  static List<PersonalReminderStateIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalReminderStateIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalReminderStateIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalReminderStateIn> mapFromJson(dynamic json) {
    final map = <String, PersonalReminderStateIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalReminderStateIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalReminderStateIn-objects as value to a dart map
  static Map<String, List<PersonalReminderStateIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalReminderStateIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalReminderStateIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'status',
  };
}


class PersonalReminderStateInStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalReminderStateInStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const dismissed = PersonalReminderStateInStatusEnum._(r'dismissed');
  static const snoozed = PersonalReminderStateInStatusEnum._(r'snoozed');
  static const done = PersonalReminderStateInStatusEnum._(r'done');

  /// List of all possible values in this [enum][PersonalReminderStateInStatusEnum].
  static const values = <PersonalReminderStateInStatusEnum>[
    dismissed,
    snoozed,
    done,
  ];

  static PersonalReminderStateInStatusEnum? fromJson(dynamic value) => PersonalReminderStateInStatusEnumTypeTransformer().decode(value);

  static List<PersonalReminderStateInStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalReminderStateInStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalReminderStateInStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalReminderStateInStatusEnum] to String,
/// and [decode] dynamic data back to [PersonalReminderStateInStatusEnum].
class PersonalReminderStateInStatusEnumTypeTransformer {
  factory PersonalReminderStateInStatusEnumTypeTransformer() => _instance ??= const PersonalReminderStateInStatusEnumTypeTransformer._();

  const PersonalReminderStateInStatusEnumTypeTransformer._();

  String encode(PersonalReminderStateInStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalReminderStateInStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalReminderStateInStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'dismissed': return PersonalReminderStateInStatusEnum.dismissed;
        case r'snoozed': return PersonalReminderStateInStatusEnum.snoozed;
        case r'done': return PersonalReminderStateInStatusEnum.done;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalReminderStateInStatusEnumTypeTransformer] instance.
  static PersonalReminderStateInStatusEnumTypeTransformer? _instance;
}


