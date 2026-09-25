//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SettlementIn {
  /// Returns a new [SettlementIn] instance.
  SettlementIn({
    this.id,
    required this.fromUser,
    required this.toUser,
    required this.amountMinor,
    required this.date,
    required this.method,
    this.note,
  });

  String? id;

  String fromUser;

  String toUser;

  int amountMinor;

  DateTime date;

  SettlementInMethodEnum method;

  String? note;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SettlementIn &&
    other.id == id &&
    other.fromUser == fromUser &&
    other.toUser == toUser &&
    other.amountMinor == amountMinor &&
    other.date == date &&
    other.method == method &&
    other.note == note;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (fromUser.hashCode) +
    (toUser.hashCode) +
    (amountMinor.hashCode) +
    (date.hashCode) +
    (method.hashCode) +
    (note == null ? 0 : note!.hashCode);

  @override
  String toString() => 'SettlementIn[id=$id, fromUser=$fromUser, toUser=$toUser, amountMinor=$amountMinor, date=$date, method=$method, note=$note]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
      json[r'from_user'] = this.fromUser;
      json[r'to_user'] = this.toUser;
      json[r'amount_minor'] = this.amountMinor;
      json[r'date'] = _dateFormatter.format(this.date.toUtc());
      json[r'method'] = this.method;
    if (this.note != null) {
      json[r'note'] = this.note;
    } else {
      json[r'note'] = null;
    }
    return json;
  }

  /// Returns a new [SettlementIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SettlementIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SettlementIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SettlementIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SettlementIn(
        id: mapValueOfType<String>(json, r'id'),
        fromUser: mapValueOfType<String>(json, r'from_user')!,
        toUser: mapValueOfType<String>(json, r'to_user')!,
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
        date: mapDateTime(json, r'date', r'')!,
        method: SettlementInMethodEnum.fromJson(json[r'method'])!,
        note: mapValueOfType<String>(json, r'note'),
      );
    }
    return null;
  }

  static List<SettlementIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SettlementIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SettlementIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SettlementIn> mapFromJson(dynamic json) {
    final map = <String, SettlementIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SettlementIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SettlementIn-objects as value to a dart map
  static Map<String, List<SettlementIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SettlementIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SettlementIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'from_user',
    'to_user',
    'amount_minor',
    'date',
    'method',
  };
}


class SettlementInMethodEnum {
  /// Instantiate a new enum with the provided [value].
  const SettlementInMethodEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const upi = SettlementInMethodEnum._(r'upi');
  static const cash = SettlementInMethodEnum._(r'cash');
  static const bank = SettlementInMethodEnum._(r'bank');
  static const other = SettlementInMethodEnum._(r'other');

  /// List of all possible values in this [enum][SettlementInMethodEnum].
  static const values = <SettlementInMethodEnum>[
    upi,
    cash,
    bank,
    other,
  ];

  static SettlementInMethodEnum? fromJson(dynamic value) => SettlementInMethodEnumTypeTransformer().decode(value);

  static List<SettlementInMethodEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SettlementInMethodEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SettlementInMethodEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SettlementInMethodEnum] to String,
/// and [decode] dynamic data back to [SettlementInMethodEnum].
class SettlementInMethodEnumTypeTransformer {
  factory SettlementInMethodEnumTypeTransformer() => _instance ??= const SettlementInMethodEnumTypeTransformer._();

  const SettlementInMethodEnumTypeTransformer._();

  String encode(SettlementInMethodEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SettlementInMethodEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SettlementInMethodEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'upi': return SettlementInMethodEnum.upi;
        case r'cash': return SettlementInMethodEnum.cash;
        case r'bank': return SettlementInMethodEnum.bank;
        case r'other': return SettlementInMethodEnum.other;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SettlementInMethodEnumTypeTransformer] instance.
  static SettlementInMethodEnumTypeTransformer? _instance;
}


