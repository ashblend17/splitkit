//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuditPageOut {
  /// Returns a new [AuditPageOut] instance.
  AuditPageOut({
    this.items = const [],
    required this.total,
    required this.hasMore,
  });

  List<AuditEntryOut> items;

  int total;

  bool hasMore;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AuditPageOut &&
    _deepEquality.equals(other.items, items) &&
    other.total == total &&
    other.hasMore == hasMore;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (items.hashCode) +
    (total.hashCode) +
    (hasMore.hashCode);

  @override
  String toString() => 'AuditPageOut[items=$items, total=$total, hasMore=$hasMore]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'items'] = this.items;
      json[r'total'] = this.total;
      json[r'has_more'] = this.hasMore;
    return json;
  }

  /// Returns a new [AuditPageOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AuditPageOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AuditPageOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AuditPageOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AuditPageOut(
        items: AuditEntryOut.listFromJson(json[r'items']),
        total: mapValueOfType<int>(json, r'total')!,
        hasMore: mapValueOfType<bool>(json, r'has_more')!,
      );
    }
    return null;
  }

  static List<AuditPageOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AuditPageOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuditPageOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AuditPageOut> mapFromJson(dynamic json) {
    final map = <String, AuditPageOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AuditPageOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AuditPageOut-objects as value to a dart map
  static Map<String, List<AuditPageOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AuditPageOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AuditPageOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'items',
    'total',
    'has_more',
  };
}

