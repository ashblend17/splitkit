//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportStatsOut {
  /// Returns a new [ImportStatsOut] instance.
  ImportStatsOut({
    required this.expenses,
    required this.expenseTotalMinor,
    required this.transfers,
    required this.transferTotalMinor,
    required this.people,
    required this.placeholders,
    required this.skipped,
    required this.currency,
    required this.createdGroup,
    this.review = const [],
    this.skippedRows = const [],
  });

  int expenses;

  int expenseTotalMinor;

  int transfers;

  int transferTotalMinor;

  int people;

  int placeholders;

  int skipped;

  String currency;

  bool createdGroup;

  List<ReviewItemOut> review;

  List<String> skippedRows;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ImportStatsOut &&
    other.expenses == expenses &&
    other.expenseTotalMinor == expenseTotalMinor &&
    other.transfers == transfers &&
    other.transferTotalMinor == transferTotalMinor &&
    other.people == people &&
    other.placeholders == placeholders &&
    other.skipped == skipped &&
    other.currency == currency &&
    other.createdGroup == createdGroup &&
    _deepEquality.equals(other.review, review) &&
    _deepEquality.equals(other.skippedRows, skippedRows);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expenses.hashCode) +
    (expenseTotalMinor.hashCode) +
    (transfers.hashCode) +
    (transferTotalMinor.hashCode) +
    (people.hashCode) +
    (placeholders.hashCode) +
    (skipped.hashCode) +
    (currency.hashCode) +
    (createdGroup.hashCode) +
    (review.hashCode) +
    (skippedRows.hashCode);

  @override
  String toString() => 'ImportStatsOut[expenses=$expenses, expenseTotalMinor=$expenseTotalMinor, transfers=$transfers, transferTotalMinor=$transferTotalMinor, people=$people, placeholders=$placeholders, skipped=$skipped, currency=$currency, createdGroup=$createdGroup, review=$review, skippedRows=$skippedRows]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expenses'] = this.expenses;
      json[r'expense_total_minor'] = this.expenseTotalMinor;
      json[r'transfers'] = this.transfers;
      json[r'transfer_total_minor'] = this.transferTotalMinor;
      json[r'people'] = this.people;
      json[r'placeholders'] = this.placeholders;
      json[r'skipped'] = this.skipped;
      json[r'currency'] = this.currency;
      json[r'created_group'] = this.createdGroup;
      json[r'review'] = this.review;
      json[r'skipped_rows'] = this.skippedRows;
    return json;
  }

  /// Returns a new [ImportStatsOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportStatsOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ImportStatsOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ImportStatsOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ImportStatsOut(
        expenses: mapValueOfType<int>(json, r'expenses')!,
        expenseTotalMinor: mapValueOfType<int>(json, r'expense_total_minor')!,
        transfers: mapValueOfType<int>(json, r'transfers')!,
        transferTotalMinor: mapValueOfType<int>(json, r'transfer_total_minor')!,
        people: mapValueOfType<int>(json, r'people')!,
        placeholders: mapValueOfType<int>(json, r'placeholders')!,
        skipped: mapValueOfType<int>(json, r'skipped')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        createdGroup: mapValueOfType<bool>(json, r'created_group')!,
        review: ReviewItemOut.listFromJson(json[r'review']),
        skippedRows: json[r'skipped_rows'] is Iterable
            ? (json[r'skipped_rows'] as Iterable).cast<String>().toList(growable: false)
            : const [],
      );
    }
    return null;
  }

  static List<ImportStatsOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ImportStatsOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportStatsOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportStatsOut> mapFromJson(dynamic json) {
    final map = <String, ImportStatsOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportStatsOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportStatsOut-objects as value to a dart map
  static Map<String, List<ImportStatsOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ImportStatsOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportStatsOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expenses',
    'expense_total_minor',
    'transfers',
    'transfer_total_minor',
    'people',
    'placeholders',
    'skipped',
    'currency',
    'created_group',
    'review',
    'skipped_rows',
  };
}

