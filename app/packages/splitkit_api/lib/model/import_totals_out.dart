//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportTotalsOut {
  /// Returns a new [ImportTotalsOut] instance.
  ImportTotalsOut({
    required this.expenses,
    required this.expenseTotalMinor,
    required this.transfers,
    required this.transferTotalMinor,
    required this.skipped,
    this.firstDate,
    this.lastDate,
  });

  int expenses;

  int expenseTotalMinor;

  int transfers;

  int transferTotalMinor;

  int skipped;

  DateTime? firstDate;

  DateTime? lastDate;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ImportTotalsOut &&
    other.expenses == expenses &&
    other.expenseTotalMinor == expenseTotalMinor &&
    other.transfers == transfers &&
    other.transferTotalMinor == transferTotalMinor &&
    other.skipped == skipped &&
    other.firstDate == firstDate &&
    other.lastDate == lastDate;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expenses.hashCode) +
    (expenseTotalMinor.hashCode) +
    (transfers.hashCode) +
    (transferTotalMinor.hashCode) +
    (skipped.hashCode) +
    (firstDate == null ? 0 : firstDate!.hashCode) +
    (lastDate == null ? 0 : lastDate!.hashCode);

  @override
  String toString() => 'ImportTotalsOut[expenses=$expenses, expenseTotalMinor=$expenseTotalMinor, transfers=$transfers, transferTotalMinor=$transferTotalMinor, skipped=$skipped, firstDate=$firstDate, lastDate=$lastDate]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expenses'] = this.expenses;
      json[r'expense_total_minor'] = this.expenseTotalMinor;
      json[r'transfers'] = this.transfers;
      json[r'transfer_total_minor'] = this.transferTotalMinor;
      json[r'skipped'] = this.skipped;
    if (this.firstDate != null) {
      json[r'first_date'] = _dateFormatter.format(this.firstDate!.toUtc());
    } else {
      json[r'first_date'] = null;
    }
    if (this.lastDate != null) {
      json[r'last_date'] = _dateFormatter.format(this.lastDate!.toUtc());
    } else {
      json[r'last_date'] = null;
    }
    return json;
  }

  /// Returns a new [ImportTotalsOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportTotalsOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ImportTotalsOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ImportTotalsOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ImportTotalsOut(
        expenses: mapValueOfType<int>(json, r'expenses')!,
        expenseTotalMinor: mapValueOfType<int>(json, r'expense_total_minor')!,
        transfers: mapValueOfType<int>(json, r'transfers')!,
        transferTotalMinor: mapValueOfType<int>(json, r'transfer_total_minor')!,
        skipped: mapValueOfType<int>(json, r'skipped')!,
        firstDate: mapDateTime(json, r'first_date', r''),
        lastDate: mapDateTime(json, r'last_date', r''),
      );
    }
    return null;
  }

  static List<ImportTotalsOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ImportTotalsOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportTotalsOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportTotalsOut> mapFromJson(dynamic json) {
    final map = <String, ImportTotalsOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportTotalsOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportTotalsOut-objects as value to a dart map
  static Map<String, List<ImportTotalsOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ImportTotalsOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportTotalsOut.listFromJson(entry.value, growable: growable,);
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
    'skipped',
  };
}

