//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SettleUpPlanOut {
  /// Returns a new [SettleUpPlanOut] instance.
  SettleUpPlanOut({
    required this.friend,
    required this.currency,
    required this.netMinor,
    this.groups = const [],
  });

  UserBrief friend;

  String currency;

  int netMinor;

  List<FriendGroupBalance> groups;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SettleUpPlanOut &&
    other.friend == friend &&
    other.currency == currency &&
    other.netMinor == netMinor &&
    _deepEquality.equals(other.groups, groups);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (friend.hashCode) +
    (currency.hashCode) +
    (netMinor.hashCode) +
    (groups.hashCode);

  @override
  String toString() => 'SettleUpPlanOut[friend=$friend, currency=$currency, netMinor=$netMinor, groups=$groups]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'friend'] = this.friend;
      json[r'currency'] = this.currency;
      json[r'net_minor'] = this.netMinor;
      json[r'groups'] = this.groups;
    return json;
  }

  /// Returns a new [SettleUpPlanOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SettleUpPlanOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SettleUpPlanOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SettleUpPlanOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SettleUpPlanOut(
        friend: UserBrief.fromJson(json[r'friend'])!,
        currency: mapValueOfType<String>(json, r'currency')!,
        netMinor: mapValueOfType<int>(json, r'net_minor')!,
        groups: FriendGroupBalance.listFromJson(json[r'groups']),
      );
    }
    return null;
  }

  static List<SettleUpPlanOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SettleUpPlanOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SettleUpPlanOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SettleUpPlanOut> mapFromJson(dynamic json) {
    final map = <String, SettleUpPlanOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SettleUpPlanOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SettleUpPlanOut-objects as value to a dart map
  static Map<String, List<SettleUpPlanOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SettleUpPlanOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SettleUpPlanOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'friend',
    'currency',
    'net_minor',
    'groups',
  };
}

