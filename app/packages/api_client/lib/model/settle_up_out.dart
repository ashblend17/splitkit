//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SettleUpOut {
  /// Returns a new [SettleUpOut] instance.
  SettleUpOut({
    this.settlements = const [],
    required this.remainingNetMinor,
  });

  List<SettlementOut> settlements;

  int remainingNetMinor;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SettleUpOut &&
    _deepEquality.equals(other.settlements, settlements) &&
    other.remainingNetMinor == remainingNetMinor;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (settlements.hashCode) +
    (remainingNetMinor.hashCode);

  @override
  String toString() => 'SettleUpOut[settlements=$settlements, remainingNetMinor=$remainingNetMinor]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'settlements'] = this.settlements;
      json[r'remaining_net_minor'] = this.remainingNetMinor;
    return json;
  }

  /// Returns a new [SettleUpOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SettleUpOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SettleUpOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SettleUpOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SettleUpOut(
        settlements: SettlementOut.listFromJson(json[r'settlements']),
        remainingNetMinor: mapValueOfType<int>(json, r'remaining_net_minor')!,
      );
    }
    return null;
  }

  static List<SettleUpOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SettleUpOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SettleUpOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SettleUpOut> mapFromJson(dynamic json) {
    final map = <String, SettleUpOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SettleUpOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SettleUpOut-objects as value to a dart map
  static Map<String, List<SettleUpOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SettleUpOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SettleUpOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'settlements',
    'remaining_net_minor',
  };
}

