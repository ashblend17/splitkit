//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TricountLinkPreviewOut {
  /// Returns a new [TricountLinkPreviewOut] instance.
  TricountLinkPreviewOut({
    required this.title,
    required this.currency,
    required this.expenses,
    required this.payments,
    required this.unsupported,
    this.people = const [],
    this.problem,
  });

  String title;

  String currency;

  int expenses;

  int payments;

  int unsupported;

  List<TricountPersonOut> people;

  String? problem;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TricountLinkPreviewOut &&
    other.title == title &&
    other.currency == currency &&
    other.expenses == expenses &&
    other.payments == payments &&
    other.unsupported == unsupported &&
    _deepEquality.equals(other.people, people) &&
    other.problem == problem;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (title.hashCode) +
    (currency.hashCode) +
    (expenses.hashCode) +
    (payments.hashCode) +
    (unsupported.hashCode) +
    (people.hashCode) +
    (problem == null ? 0 : problem!.hashCode);

  @override
  String toString() => 'TricountLinkPreviewOut[title=$title, currency=$currency, expenses=$expenses, payments=$payments, unsupported=$unsupported, people=$people, problem=$problem]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'title'] = this.title;
      json[r'currency'] = this.currency;
      json[r'expenses'] = this.expenses;
      json[r'payments'] = this.payments;
      json[r'unsupported'] = this.unsupported;
      json[r'people'] = this.people;
    if (this.problem != null) {
      json[r'problem'] = this.problem;
    } else {
      json[r'problem'] = null;
    }
    return json;
  }

  /// Returns a new [TricountLinkPreviewOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TricountLinkPreviewOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "TricountLinkPreviewOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "TricountLinkPreviewOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return TricountLinkPreviewOut(
        title: mapValueOfType<String>(json, r'title')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        expenses: mapValueOfType<int>(json, r'expenses')!,
        payments: mapValueOfType<int>(json, r'payments')!,
        unsupported: mapValueOfType<int>(json, r'unsupported')!,
        people: TricountPersonOut.listFromJson(json[r'people']),
        problem: mapValueOfType<String>(json, r'problem'),
      );
    }
    return null;
  }

  static List<TricountLinkPreviewOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TricountLinkPreviewOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TricountLinkPreviewOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TricountLinkPreviewOut> mapFromJson(dynamic json) {
    final map = <String, TricountLinkPreviewOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TricountLinkPreviewOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TricountLinkPreviewOut-objects as value to a dart map
  static Map<String, List<TricountLinkPreviewOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TricountLinkPreviewOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TricountLinkPreviewOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'title',
    'currency',
    'expenses',
    'payments',
    'unsupported',
    'people',
  };
}

