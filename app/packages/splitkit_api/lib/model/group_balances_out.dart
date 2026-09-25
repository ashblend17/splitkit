//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupBalancesOut {
  /// Returns a new [GroupBalancesOut] instance.
  GroupBalancesOut({
    required this.groupId,
    required this.currency,
    required this.netMinor,
    required this.youOweMinor,
    required this.youAreOwedMinor,
    this.people = const [],
    this.members = const [],
    this.suggested = const [],
  });

  String groupId;

  String currency;

  int netMinor;

  int youOweMinor;

  int youAreOwedMinor;

  List<PersonBalance> people;

  List<PersonBalance> members;

  List<SuggestedPayment> suggested;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GroupBalancesOut &&
    other.groupId == groupId &&
    other.currency == currency &&
    other.netMinor == netMinor &&
    other.youOweMinor == youOweMinor &&
    other.youAreOwedMinor == youAreOwedMinor &&
    _deepEquality.equals(other.people, people) &&
    _deepEquality.equals(other.members, members) &&
    _deepEquality.equals(other.suggested, suggested);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (groupId.hashCode) +
    (currency.hashCode) +
    (netMinor.hashCode) +
    (youOweMinor.hashCode) +
    (youAreOwedMinor.hashCode) +
    (people.hashCode) +
    (members.hashCode) +
    (suggested.hashCode);

  @override
  String toString() => 'GroupBalancesOut[groupId=$groupId, currency=$currency, netMinor=$netMinor, youOweMinor=$youOweMinor, youAreOwedMinor=$youAreOwedMinor, people=$people, members=$members, suggested=$suggested]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'group_id'] = this.groupId;
      json[r'currency'] = this.currency;
      json[r'net_minor'] = this.netMinor;
      json[r'you_owe_minor'] = this.youOweMinor;
      json[r'you_are_owed_minor'] = this.youAreOwedMinor;
      json[r'people'] = this.people;
      json[r'members'] = this.members;
      json[r'suggested'] = this.suggested;
    return json;
  }

  /// Returns a new [GroupBalancesOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GroupBalancesOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GroupBalancesOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GroupBalancesOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GroupBalancesOut(
        groupId: mapValueOfType<String>(json, r'group_id')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        netMinor: mapValueOfType<int>(json, r'net_minor')!,
        youOweMinor: mapValueOfType<int>(json, r'you_owe_minor')!,
        youAreOwedMinor: mapValueOfType<int>(json, r'you_are_owed_minor')!,
        people: PersonBalance.listFromJson(json[r'people']),
        members: PersonBalance.listFromJson(json[r'members']),
        suggested: SuggestedPayment.listFromJson(json[r'suggested']),
      );
    }
    return null;
  }

  static List<GroupBalancesOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupBalancesOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupBalancesOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GroupBalancesOut> mapFromJson(dynamic json) {
    final map = <String, GroupBalancesOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GroupBalancesOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GroupBalancesOut-objects as value to a dart map
  static Map<String, List<GroupBalancesOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GroupBalancesOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GroupBalancesOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'group_id',
    'currency',
    'net_minor',
    'you_owe_minor',
    'you_are_owed_minor',
    'people',
    'members',
    'suggested',
  };
}

