//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PersonalTxnOut {
  /// Returns a new [PersonalTxnOut] instance.
  PersonalTxnOut({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.currency,
    required this.description,
    required this.date,
    this.category,
    this.notes,
    this.actingAdminId,
    required this.createdAt,
    this.deletedAt,
    required this.version,
  });

  String id;

  PersonalTxnOutTypeEnum type;

  int amountMinor;

  String currency;

  String description;

  DateTime date;

  CategoryOut? category;

  String? notes;

  String? actingAdminId;

  DateTime createdAt;

  DateTime? deletedAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PersonalTxnOut &&
    other.id == id &&
    other.type == type &&
    other.amountMinor == amountMinor &&
    other.currency == currency &&
    other.description == description &&
    other.date == date &&
    other.category == category &&
    other.notes == notes &&
    other.actingAdminId == actingAdminId &&
    other.createdAt == createdAt &&
    other.deletedAt == deletedAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (type.hashCode) +
    (amountMinor.hashCode) +
    (currency.hashCode) +
    (description.hashCode) +
    (date.hashCode) +
    (category == null ? 0 : category!.hashCode) +
    (notes == null ? 0 : notes!.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (createdAt.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'PersonalTxnOut[id=$id, type=$type, amountMinor=$amountMinor, currency=$currency, description=$description, date=$date, category=$category, notes=$notes, actingAdminId=$actingAdminId, createdAt=$createdAt, deletedAt=$deletedAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'type'] = this.type;
      json[r'amount_minor'] = this.amountMinor;
      json[r'currency'] = this.currency;
      json[r'description'] = this.description;
      json[r'date'] = _dateFormatter.format(this.date.toUtc());
    if (this.category != null) {
      json[r'category'] = this.category;
    } else {
      json[r'category'] = null;
    }
    if (this.notes != null) {
      json[r'notes'] = this.notes;
    } else {
      json[r'notes'] = null;
    }
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

  /// Returns a new [PersonalTxnOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PersonalTxnOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PersonalTxnOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PersonalTxnOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PersonalTxnOut(
        id: mapValueOfType<String>(json, r'id')!,
        type: PersonalTxnOutTypeEnum.fromJson(json[r'type'])!,
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        description: mapValueOfType<String>(json, r'description')!,
        date: mapDateTime(json, r'date', r'')!,
        category: CategoryOut.fromJson(json[r'category']),
        notes: mapValueOfType<String>(json, r'notes'),
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<PersonalTxnOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalTxnOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalTxnOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PersonalTxnOut> mapFromJson(dynamic json) {
    final map = <String, PersonalTxnOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PersonalTxnOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PersonalTxnOut-objects as value to a dart map
  static Map<String, List<PersonalTxnOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PersonalTxnOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PersonalTxnOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'type',
    'amount_minor',
    'currency',
    'description',
    'date',
    'created_at',
    'version',
  };
}


class PersonalTxnOutTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const PersonalTxnOutTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const income = PersonalTxnOutTypeEnum._(r'income');
  static const expense = PersonalTxnOutTypeEnum._(r'expense');

  /// List of all possible values in this [enum][PersonalTxnOutTypeEnum].
  static const values = <PersonalTxnOutTypeEnum>[
    income,
    expense,
  ];

  static PersonalTxnOutTypeEnum? fromJson(dynamic value) => PersonalTxnOutTypeEnumTypeTransformer().decode(value);

  static List<PersonalTxnOutTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PersonalTxnOutTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PersonalTxnOutTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PersonalTxnOutTypeEnum] to String,
/// and [decode] dynamic data back to [PersonalTxnOutTypeEnum].
class PersonalTxnOutTypeEnumTypeTransformer {
  factory PersonalTxnOutTypeEnumTypeTransformer() => _instance ??= const PersonalTxnOutTypeEnumTypeTransformer._();

  const PersonalTxnOutTypeEnumTypeTransformer._();

  String encode(PersonalTxnOutTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PersonalTxnOutTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PersonalTxnOutTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'income': return PersonalTxnOutTypeEnum.income;
        case r'expense': return PersonalTxnOutTypeEnum.expense;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PersonalTxnOutTypeEnumTypeTransformer] instance.
  static PersonalTxnOutTypeEnumTypeTransformer? _instance;
}


