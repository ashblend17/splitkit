//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupOut {
  /// Returns a new [GroupOut] instance.
  GroupOut({
    required this.id,
    required this.name,
    required this.icon,
    required this.currency,
    required this.createdAt,
    this.archivedAt,
    this.members = const [],
    required this.totalSpentMinor,
    required this.myNetMinor,
    this.lastActivityAt,
    required this.version,
  });

  String id;

  String name;

  String icon;

  String currency;

  DateTime createdAt;

  DateTime? archivedAt;

  List<MemberOut> members;

  int totalSpentMinor;

  int myNetMinor;

  DateTime? lastActivityAt;

  int version;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GroupOut &&
    other.id == id &&
    other.name == name &&
    other.icon == icon &&
    other.currency == currency &&
    other.createdAt == createdAt &&
    other.archivedAt == archivedAt &&
    _deepEquality.equals(other.members, members) &&
    other.totalSpentMinor == totalSpentMinor &&
    other.myNetMinor == myNetMinor &&
    other.lastActivityAt == lastActivityAt &&
    other.version == version;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode) +
    (icon.hashCode) +
    (currency.hashCode) +
    (createdAt.hashCode) +
    (archivedAt == null ? 0 : archivedAt!.hashCode) +
    (members.hashCode) +
    (totalSpentMinor.hashCode) +
    (myNetMinor.hashCode) +
    (lastActivityAt == null ? 0 : lastActivityAt!.hashCode) +
    (version.hashCode);

  @override
  String toString() => 'GroupOut[id=$id, name=$name, icon=$icon, currency=$currency, createdAt=$createdAt, archivedAt=$archivedAt, members=$members, totalSpentMinor=$totalSpentMinor, myNetMinor=$myNetMinor, lastActivityAt=$lastActivityAt, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
      json[r'icon'] = this.icon;
      json[r'currency'] = this.currency;
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
    if (this.archivedAt != null) {
      json[r'archived_at'] = this.archivedAt!.toUtc().toIso8601String();
    } else {
      json[r'archived_at'] = null;
    }
      json[r'members'] = this.members;
      json[r'total_spent_minor'] = this.totalSpentMinor;
      json[r'my_net_minor'] = this.myNetMinor;
    if (this.lastActivityAt != null) {
      json[r'last_activity_at'] = this.lastActivityAt!.toUtc().toIso8601String();
    } else {
      json[r'last_activity_at'] = null;
    }
      json[r'version'] = this.version;
    return json;
  }

  /// Returns a new [GroupOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GroupOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GroupOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GroupOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GroupOut(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        icon: mapValueOfType<String>(json, r'icon')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        createdAt: mapDateTime(json, r'created_at', r'')!,
        archivedAt: mapDateTime(json, r'archived_at', r''),
        members: MemberOut.listFromJson(json[r'members']),
        totalSpentMinor: mapValueOfType<int>(json, r'total_spent_minor')!,
        myNetMinor: mapValueOfType<int>(json, r'my_net_minor')!,
        lastActivityAt: mapDateTime(json, r'last_activity_at', r''),
        version: mapValueOfType<int>(json, r'version')!,
      );
    }
    return null;
  }

  static List<GroupOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GroupOut> mapFromJson(dynamic json) {
    final map = <String, GroupOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GroupOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GroupOut-objects as value to a dart map
  static Map<String, List<GroupOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GroupOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GroupOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
    'icon',
    'currency',
    'created_at',
    'members',
    'total_spent_minor',
    'my_net_minor',
    'version',
  };
}

