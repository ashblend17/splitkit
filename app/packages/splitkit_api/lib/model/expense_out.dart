//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ExpenseOut {
  /// Returns a new [ExpenseOut] instance.
  ExpenseOut({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amountMinor,
    required this.currency,
    required this.payer,
    required this.date,
    this.category,
    this.notes,
    required this.splitMethod,
    this.splits = const [],
    required this.myShareMinor,
    required this.myNetMinor,
    required this.createdBy,
    this.actingAdminId,
    this.importBatchId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
  });

  String id;

  String groupId;

  String description;

  int amountMinor;

  String currency;

  UserBrief payer;

  DateTime date;

  CategoryOut? category;

  String? notes;

  String splitMethod;

  List<SplitOut> splits;

  int myShareMinor;

  int myNetMinor;

  UserBrief createdBy;

  String? actingAdminId;

  String? importBatchId;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? deletedAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ExpenseOut &&
    other.id == id &&
    other.groupId == groupId &&
    other.description == description &&
    other.amountMinor == amountMinor &&
    other.currency == currency &&
    other.payer == payer &&
    other.date == date &&
    other.category == category &&
    other.notes == notes &&
    other.splitMethod == splitMethod &&
    _deepEquality.equals(other.splits, splits) &&
    other.myShareMinor == myShareMinor &&
    other.myNetMinor == myNetMinor &&
    other.createdBy == createdBy &&
    other.actingAdminId == actingAdminId &&
    other.importBatchId == importBatchId &&
    other.createdAt == createdAt &&
    other.updatedAt == updatedAt &&
    other.deletedAt == deletedAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (groupId.hashCode) +
    (description.hashCode) +
    (amountMinor.hashCode) +
    (currency.hashCode) +
    (payer.hashCode) +
    (date.hashCode) +
    (category == null ? 0 : category!.hashCode) +
    (notes == null ? 0 : notes!.hashCode) +
    (splitMethod.hashCode) +
    (splits.hashCode) +
    (myShareMinor.hashCode) +
    (myNetMinor.hashCode) +
    (createdBy.hashCode) +
    (actingAdminId == null ? 0 : actingAdminId!.hashCode) +
    (importBatchId == null ? 0 : importBatchId!.hashCode) +
    (createdAt.hashCode) +
    (updatedAt.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'ExpenseOut[id=$id, groupId=$groupId, description=$description, amountMinor=$amountMinor, currency=$currency, payer=$payer, date=$date, category=$category, notes=$notes, splitMethod=$splitMethod, splits=$splits, myShareMinor=$myShareMinor, myNetMinor=$myNetMinor, createdBy=$createdBy, actingAdminId=$actingAdminId, importBatchId=$importBatchId, createdAt=$createdAt, updatedAt=$updatedAt, deletedAt=$deletedAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'group_id'] = this.groupId;
      json[r'description'] = this.description;
      json[r'amount_minor'] = this.amountMinor;
      json[r'currency'] = this.currency;
      json[r'payer'] = this.payer;
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
      json[r'split_method'] = this.splitMethod;
      json[r'splits'] = this.splits;
      json[r'my_share_minor'] = this.myShareMinor;
      json[r'my_net_minor'] = this.myNetMinor;
      json[r'created_by'] = this.createdBy;
    if (this.actingAdminId != null) {
      json[r'acting_admin_id'] = this.actingAdminId;
    } else {
      json[r'acting_admin_id'] = null;
    }
    if (this.importBatchId != null) {
      json[r'import_batch_id'] = this.importBatchId;
    } else {
      json[r'import_batch_id'] = null;
    }
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
      json[r'updated_at'] = this.updatedAt.toUtc().toIso8601String();
    if (this.deletedAt != null) {
      json[r'deleted_at'] = this.deletedAt!.toUtc().toIso8601String();
    } else {
      json[r'deleted_at'] = null;
    }
      json[r'version'] = this.version;
    return json;
  }

  /// Returns a new [ExpenseOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ExpenseOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ExpenseOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ExpenseOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ExpenseOut(
        id: mapValueOfType<String>(json, r'id')!,
        groupId: mapValueOfType<String>(json, r'group_id')!,
        description: mapValueOfType<String>(json, r'description')!,
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        payer: UserBrief.fromJson(json[r'payer'])!,
        date: mapDateTime(json, r'date', r'')!,
        category: CategoryOut.fromJson(json[r'category']),
        notes: mapValueOfType<String>(json, r'notes'),
        splitMethod: mapValueOfType<String>(json, r'split_method')!,
        splits: SplitOut.listFromJson(json[r'splits']),
        myShareMinor: mapValueOfType<int>(json, r'my_share_minor')!,
        myNetMinor: mapValueOfType<int>(json, r'my_net_minor')!,
        createdBy: UserBrief.fromJson(json[r'created_by'])!,
        actingAdminId: mapValueOfType<String>(json, r'acting_admin_id'),
        importBatchId: mapValueOfType<String>(json, r'import_batch_id'),
        createdAt: mapDateTime(json, r'created_at', r'')!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<ExpenseOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ExpenseOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ExpenseOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ExpenseOut> mapFromJson(dynamic json) {
    final map = <String, ExpenseOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ExpenseOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ExpenseOut-objects as value to a dart map
  static Map<String, List<ExpenseOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ExpenseOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ExpenseOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'group_id',
    'description',
    'amount_minor',
    'currency',
    'payer',
    'date',
    'split_method',
    'splits',
    'my_share_minor',
    'my_net_minor',
    'created_by',
    'created_at',
    'updated_at',
    'version',
  };
}

