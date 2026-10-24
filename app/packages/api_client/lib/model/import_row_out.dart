//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportRowOut {
  /// Returns a new [ImportRowOut] instance.
  ImportRowOut({
    required this.line,
    this.date,
    required this.title,
    required this.kind,
    this.payer,
    required this.amountMinor,
    required this.currency,
    this.original,
    this.shares = const [],
    this.category,
    this.issues = const [],
  });

  int line;

  DateTime? date;

  String title;

  ImportRowOutKindEnum kind;

  String? payer;

  int amountMinor;

  String currency;

  String? original;

  List<RowShareOut> shares;

  String? category;

  List<RowIssueOut> issues;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ImportRowOut &&
    other.line == line &&
    other.date == date &&
    other.title == title &&
    other.kind == kind &&
    other.payer == payer &&
    other.amountMinor == amountMinor &&
    other.currency == currency &&
    other.original == original &&
    _deepEquality.equals(other.shares, shares) &&
    other.category == category &&
    _deepEquality.equals(other.issues, issues);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (line.hashCode) +
    (date == null ? 0 : date!.hashCode) +
    (title.hashCode) +
    (kind.hashCode) +
    (payer == null ? 0 : payer!.hashCode) +
    (amountMinor.hashCode) +
    (currency.hashCode) +
    (original == null ? 0 : original!.hashCode) +
    (shares.hashCode) +
    (category == null ? 0 : category!.hashCode) +
    (issues.hashCode);

  @override
  String toString() => 'ImportRowOut[line=$line, date=$date, title=$title, kind=$kind, payer=$payer, amountMinor=$amountMinor, currency=$currency, original=$original, shares=$shares, category=$category, issues=$issues]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'line'] = this.line;
    if (this.date != null) {
      json[r'date'] = _dateFormatter.format(this.date!.toUtc());
    } else {
      json[r'date'] = null;
    }
      json[r'title'] = this.title;
      json[r'kind'] = this.kind;
    if (this.payer != null) {
      json[r'payer'] = this.payer;
    } else {
      json[r'payer'] = null;
    }
      json[r'amount_minor'] = this.amountMinor;
      json[r'currency'] = this.currency;
    if (this.original != null) {
      json[r'original'] = this.original;
    } else {
      json[r'original'] = null;
    }
      json[r'shares'] = this.shares;
    if (this.category != null) {
      json[r'category'] = this.category;
    } else {
      json[r'category'] = null;
    }
      json[r'issues'] = this.issues;
    return json;
  }

  /// Returns a new [ImportRowOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportRowOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ImportRowOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ImportRowOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ImportRowOut(
        line: mapValueOfType<int>(json, r'line')!,
        date: mapDateTime(json, r'date', r''),
        title: mapValueOfType<String>(json, r'title')!,
        kind: ImportRowOutKindEnum.fromJson(json[r'kind'])!,
        payer: mapValueOfType<String>(json, r'payer'),
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        original: mapValueOfType<String>(json, r'original'),
        shares: RowShareOut.listFromJson(json[r'shares']),
        category: mapValueOfType<String>(json, r'category'),
        issues: RowIssueOut.listFromJson(json[r'issues']),
      );
    }
    return null;
  }

  static List<ImportRowOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ImportRowOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportRowOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportRowOut> mapFromJson(dynamic json) {
    final map = <String, ImportRowOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportRowOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportRowOut-objects as value to a dart map
  static Map<String, List<ImportRowOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ImportRowOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportRowOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'line',
    'title',
    'kind',
    'amount_minor',
    'currency',
    'shares',
    'issues',
  };
}


class ImportRowOutKindEnum {
  /// Instantiate a new enum with the provided [value].
  const ImportRowOutKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const expense = ImportRowOutKindEnum._(r'expense');
  static const transfer = ImportRowOutKindEnum._(r'transfer');
  static const income = ImportRowOutKindEnum._(r'income');

  /// List of all possible values in this [enum][ImportRowOutKindEnum].
  static const values = <ImportRowOutKindEnum>[
    expense,
    transfer,
    income,
  ];

  static ImportRowOutKindEnum? fromJson(dynamic value) => ImportRowOutKindEnumTypeTransformer().decode(value);

  static List<ImportRowOutKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ImportRowOutKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportRowOutKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ImportRowOutKindEnum] to String,
/// and [decode] dynamic data back to [ImportRowOutKindEnum].
class ImportRowOutKindEnumTypeTransformer {
  factory ImportRowOutKindEnumTypeTransformer() => _instance ??= const ImportRowOutKindEnumTypeTransformer._();

  const ImportRowOutKindEnumTypeTransformer._();

  String encode(ImportRowOutKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ImportRowOutKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ImportRowOutKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'expense': return ImportRowOutKindEnum.expense;
        case r'transfer': return ImportRowOutKindEnum.transfer;
        case r'income': return ImportRowOutKindEnum.income;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ImportRowOutKindEnumTypeTransformer] instance.
  static ImportRowOutKindEnumTypeTransformer? _instance;
}


