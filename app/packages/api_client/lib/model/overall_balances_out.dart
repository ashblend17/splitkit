//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class OverallBalancesOut {
  /// Returns a new [OverallBalancesOut] instance.
  OverallBalancesOut({
    this.totals = const [],
    this.friends = const [],
    this.groups = const [],
  });

  List<CurrencyTotals> totals;

  List<FriendBalance> friends;

  List<GroupNet> groups;

  @override
  bool operator ==(Object other) => identical(this, other) || other is OverallBalancesOut &&
    _deepEquality.equals(other.totals, totals) &&
    _deepEquality.equals(other.friends, friends) &&
    _deepEquality.equals(other.groups, groups);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (totals.hashCode) +
    (friends.hashCode) +
    (groups.hashCode);

  @override
  String toString() => 'OverallBalancesOut[totals=$totals, friends=$friends, groups=$groups]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'totals'] = this.totals;
      json[r'friends'] = this.friends;
      json[r'groups'] = this.groups;
    return json;
  }

  /// Returns a new [OverallBalancesOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static OverallBalancesOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "OverallBalancesOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "OverallBalancesOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return OverallBalancesOut(
        totals: CurrencyTotals.listFromJson(json[r'totals']),
        friends: FriendBalance.listFromJson(json[r'friends']),
        groups: GroupNet.listFromJson(json[r'groups']),
      );
    }
    return null;
  }

  static List<OverallBalancesOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OverallBalancesOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OverallBalancesOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, OverallBalancesOut> mapFromJson(dynamic json) {
    final map = <String, OverallBalancesOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = OverallBalancesOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of OverallBalancesOut-objects as value to a dart map
  static Map<String, List<OverallBalancesOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<OverallBalancesOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = OverallBalancesOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'totals',
    'friends',
    'groups',
  };
}

