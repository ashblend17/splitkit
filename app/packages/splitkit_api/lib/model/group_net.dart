//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupNet {
  /// Returns a new [GroupNet] instance.
  GroupNet({
    required this.groupId,
    required this.name,
    required this.currency,
    required this.netMinor,
  });

  String groupId;

  String name;

  String currency;

  int netMinor;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GroupNet &&
    other.groupId == groupId &&
    other.name == name &&
    other.currency == currency &&
    other.netMinor == netMinor;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (groupId.hashCode) +
    (name.hashCode) +
    (currency.hashCode) +
    (netMinor.hashCode);

  @override
  String toString() => 'GroupNet[groupId=$groupId, name=$name, currency=$currency, netMinor=$netMinor]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'group_id'] = this.groupId;
      json[r'name'] = this.name;
      json[r'currency'] = this.currency;
      json[r'net_minor'] = this.netMinor;
    return json;
  }

  /// Returns a new [GroupNet] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GroupNet? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GroupNet[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GroupNet[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GroupNet(
        groupId: mapValueOfType<String>(json, r'group_id')!,
        name: mapValueOfType<String>(json, r'name')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        netMinor: mapValueOfType<int>(json, r'net_minor')!,
      );
    }
    return null;
  }

  static List<GroupNet> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupNet>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupNet.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GroupNet> mapFromJson(dynamic json) {
    final map = <String, GroupNet>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GroupNet.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GroupNet-objects as value to a dart map
  static Map<String, List<GroupNet>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GroupNet>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GroupNet.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'group_id',
    'name',
    'currency',
    'net_minor',
  };
}

