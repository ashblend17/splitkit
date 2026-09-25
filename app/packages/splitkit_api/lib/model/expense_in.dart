//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ExpenseIn {
  /// Returns a new [ExpenseIn] instance.
  ExpenseIn({
    this.id,
    this.version,
    required this.description,
    required this.amountMinor,
    required this.payerId,
    required this.date,
    this.categoryId,
    this.notes,
    required this.split,
  });

  String? id;

  int? version;

  String description;

  int amountMinor;

  String payerId;

  DateTime date;

  String? categoryId;

  String? notes;

  SplitIn split;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ExpenseIn &&
    other.id == id &&
    other.version == version &&
    other.description == description &&
    other.amountMinor == amountMinor &&
    other.payerId == payerId &&
    other.date == date &&
    other.categoryId == categoryId &&
    other.notes == notes &&
    other.split == split;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id == null ? 0 : id!.hashCode) +
    (version == null ? 0 : version!.hashCode) +
    (description.hashCode) +
    (amountMinor.hashCode) +
    (payerId.hashCode) +
    (date.hashCode) +
    (categoryId == null ? 0 : categoryId!.hashCode) +
    (notes == null ? 0 : notes!.hashCode) +
    (split.hashCode);

  @override
  String toString() => 'ExpenseIn[id=$id, version=$version, description=$description, amountMinor=$amountMinor, payerId=$payerId, date=$date, categoryId=$categoryId, notes=$notes, split=$split]';

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
      json[r'description'] = this.description;
      json[r'amount_minor'] = this.amountMinor;
      json[r'payer_id'] = this.payerId;
      json[r'date'] = _dateFormatter.format(this.date.toUtc());
    if (this.categoryId != null) {
      json[r'category_id'] = this.categoryId;
    } else {
      json[r'category_id'] = null;
    }
    if (this.notes != null) {
      json[r'notes'] = this.notes;
    } else {
      json[r'notes'] = null;
    }
      json[r'split'] = this.split;
    return json;
  }

  /// Returns a new [ExpenseIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ExpenseIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ExpenseIn[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ExpenseIn[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ExpenseIn(
        id: mapValueOfType<String>(json, r'id'),
        version: mapValueOfType<int>(json, r'version'),
        description: mapValueOfType<String>(json, r'description')!,
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
        payerId: mapValueOfType<String>(json, r'payer_id')!,
        date: mapDateTime(json, r'date', r'')!,
        categoryId: mapValueOfType<String>(json, r'category_id'),
        notes: mapValueOfType<String>(json, r'notes'),
        split: SplitIn.fromJson(json[r'split'])!,
      );
    }
    return null;
  }

  static List<ExpenseIn> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ExpenseIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ExpenseIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ExpenseIn> mapFromJson(dynamic json) {
    final map = <String, ExpenseIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ExpenseIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ExpenseIn-objects as value to a dart map
  static Map<String, List<ExpenseIn>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ExpenseIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ExpenseIn.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'description',
    'amount_minor',
    'payer_id',
    'date',
    'split',
  };
}

