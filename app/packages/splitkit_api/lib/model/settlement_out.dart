//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SettlementOut {
  /// Returns a new [SettlementOut] instance.
  SettlementOut({
    required this.id,
    required this.groupId,
    required this.fromUser,
    required this.toUser,
    required this.amountMinor,
    required this.currency,
    required this.date,
    required this.method,
    this.note,
    required this.createdBy,
    this.actingAdminId,
    required this.createdAt,
    this.deletedAt,
    required this.version,
  });

  String id;

  String groupId;

  UserBrief fromUser;

  UserBrief toUser;

  int amountMinor;

  String currency;

  DateTime date;

  SettlementOutMethodEnum method;

  String? note;

  UserBrief createdBy;

  String? actingAdminId;

  DateTime createdAt;

  DateTime? deletedAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SettlementOut &&
    other.id == id &&
    other.groupId == groupId &&
    other.fromUser == fromUser &&
    other.toUser == toUser &&
    other.amountMinor == amountMinor &&
    other.currency == currency &&
    other.date == date &&
    other.method == method &&
    other.note == note &&
    other.createdBy == createdBy &&
    other.actingAdminId == actingAdminId &&
    other.createdAt == createdAt &&
    other.deletedAt == deletedAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (groupId.hashCode) +
    (fromUser.hashCode) +
    (toUser.hashCode) +
    (amountMinor.hashCode) +
    (currency.hashCode) +
    (date.hashCode) +
    (method.hashCode) +
    (note == null ? 0 : note!.hashCode) +
    (createdBy.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (createdAt.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'SettlementOut[id=$id, groupId=$groupId, fromUser=$fromUser, toUser=$toUser, amountMinor=$amountMinor, currency=$currency, date=$date, method=$method, note=$note, createdBy=$createdBy, actingAdminId=$actingAdminId, createdAt=$createdAt, deletedAt=$deletedAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'group_id'] = this.groupId;
      json[r'from_user'] = this.fromUser;
      json[r'to_user'] = this.toUser;
      json[r'amount_minor'] = this.amountMinor;
      json[r'currency'] = this.currency;
      json[r'date'] = _dateFormatter.format(this.date.toUtc());
      json[r'method'] = this.method;
    if (this.note != null) {
      json[r'note'] = this.note;
    } else {
      json[r'note'] = null;
    }
      json[r'created_by'] = this.createdBy;
    if (this.actingAdminId != null) {
      json[r'acting_admin_id'] = this.actingAdminId;
    } else {
      json[r'acting_admin_id'] = null;
    }
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
    if (this.deletedAt != null) {
      json[r'deleted_at'] = this.deletedAt!.toUtc().toIso8601String();
    } else {
      json[r'deleted_at'] = null;
    }
      json[r'version'] = this.version;
    return json;
  }

  /// Returns a new [SettlementOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SettlementOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SettlementOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SettlementOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SettlementOut(
        id: mapValueOfType<String>(json, r'id')!,
        groupId: mapValueOfType<String>(json, r'group_id')!,
        fromUser: UserBrief.fromJson(json[r'from_user'])!,
        toUser: UserBrief.fromJson(json[r'to_user'])!,
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        date: mapDateTime(json, r'date', r'')!,
        method: SettlementOutMethodEnum.fromJson(json[r'method'])!,
        note: mapValueOfType<String>(json, r'note'),
        createdBy: UserBrief.fromJson(json[r'created_by'])!,
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<SettlementOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SettlementOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SettlementOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SettlementOut> mapFromJson(dynamic json) {
    final map = <String, SettlementOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SettlementOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SettlementOut-objects as value to a dart map
  static Map<String, List<SettlementOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SettlementOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SettlementOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'group_id',
    'from_user',
    'to_user',
    'amount_minor',
    'currency',
    'date',
    'method',
    'created_by',
    'created_at',
    'version',
  };
}


class SettlementOutMethodEnum {
  /// Instantiate a new enum with the provided [value].
  const SettlementOutMethodEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const upi = SettlementOutMethodEnum._(r'upi');
  static const cash = SettlementOutMethodEnum._(r'cash');
  static const bank = SettlementOutMethodEnum._(r'bank');
  static const other = SettlementOutMethodEnum._(r'other');

  /// List of all possible values in this [enum][SettlementOutMethodEnum].
  static const values = <SettlementOutMethodEnum>[
    upi,
    cash,
    bank,
    other,
  ];

  static SettlementOutMethodEnum? fromJson(dynamic value) => SettlementOutMethodEnumTypeTransformer().decode(value);

  static List<SettlementOutMethodEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SettlementOutMethodEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SettlementOutMethodEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SettlementOutMethodEnum] to String,
/// and [decode] dynamic data back to [SettlementOutMethodEnum].
class SettlementOutMethodEnumTypeTransformer {
  factory SettlementOutMethodEnumTypeTransformer() => _instance ??= const SettlementOutMethodEnumTypeTransformer._();

  const SettlementOutMethodEnumTypeTransformer._();

  String encode(SettlementOutMethodEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SettlementOutMethodEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SettlementOutMethodEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'upi': return SettlementOutMethodEnum.upi;
        case r'cash': return SettlementOutMethodEnum.cash;
        case r'bank': return SettlementOutMethodEnum.bank;
        case r'other': return SettlementOutMethodEnum.other;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SettlementOutMethodEnumTypeTransformer] instance.
  static SettlementOutMethodEnumTypeTransformer? _instance;
}


