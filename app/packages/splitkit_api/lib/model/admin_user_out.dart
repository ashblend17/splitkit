//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminUserOut {
  /// Returns a new [AdminUserOut] instance.
  AdminUserOut({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    required this.role,
    required this.currency,
    required this.createdAt,
    required this.isPlaceholder,
    required this.groupCount,
    required this.expenseCount,
    required this.settlementCount,
    required this.personalCount,
    this.balances = const [],
    this.lastActiveAt,
  });

  String id;

  String name;

  String? email;

  String? avatarUrl;

  String role;

  String currency;

  DateTime createdAt;

  bool isPlaceholder;

  int groupCount;

  int expenseCount;

  int settlementCount;

  int personalCount;

  List<MoneyTotal> balances;

  DateTime? lastActiveAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminUserOut &&
    other.id == id &&
    other.name == name &&
    other.email == email &&
    other.avatarUrl == avatarUrl &&
    other.role == role &&
    other.currency == currency &&
    other.createdAt == createdAt &&
    other.isPlaceholder == isPlaceholder &&
    other.groupCount == groupCount &&
    other.expenseCount == expenseCount &&
    other.settlementCount == settlementCount &&
    other.personalCount == personalCount &&
    _deepEquality.equals(other.balances, balances) &&
    other.lastActiveAt == lastActiveAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode) +
    (email == null ? 0 : email!.hashCode) +
    (avatarUrl == null ? 0 : avatarUrl!.hashCode) +
    (role.hashCode) +
    (currency.hashCode) +
    (createdAt.hashCode) +
    (isPlaceholder.hashCode) +
    (groupCount.hashCode) +
    (expenseCount.hashCode) +
    (settlementCount.hashCode) +
    (personalCount.hashCode) +
    (balances.hashCode) +
    (lastActiveAt == null ? 0 : lastActiveAt!.hashCode);

  @override
  String toString() => 'AdminUserOut[id=$id, name=$name, email=$email, avatarUrl=$avatarUrl, role=$role, currency=$currency, createdAt=$createdAt, isPlaceholder=$isPlaceholder, groupCount=$groupCount, expenseCount=$expenseCount, settlementCount=$settlementCount, personalCount=$personalCount, balances=$balances, lastActiveAt=$lastActiveAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
    if (this.email != null) {
      json[r'email'] = this.email;
    } else {
      json[r'email'] = null;
    }
    if (this.avatarUrl != null) {
      json[r'avatar_url'] = this.avatarUrl;
    } else {
      json[r'avatar_url'] = null;
    }
      json[r'role'] = this.role;
      json[r'currency'] = this.currency;
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
      json[r'is_placeholder'] = this.isPlaceholder;
      json[r'group_count'] = this.groupCount;
      json[r'expense_count'] = this.expenseCount;
      json[r'settlement_count'] = this.settlementCount;
      json[r'personal_count'] = this.personalCount;
      json[r'balances'] = this.balances;
    if (this.lastActiveAt != null) {
      json[r'last_active_at'] = this.lastActiveAt!.toUtc().toIso8601String();
    } else {
      json[r'last_active_at'] = null;
    }
    return json;
  }

  /// Returns a new [AdminUserOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminUserOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminUserOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminUserOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminUserOut(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        email: mapValueOfType<String>(json, r'email'),
        avatarUrl: mapValueOfType<String>(json, r'avatar_url'),
        role: mapValueOfType<String>(json, r'role')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        createdAt: mapDateTime(json, r'created_at', r'')!,
        isPlaceholder: mapValueOfType<bool>(json, r'is_placeholder')!,
        groupCount: mapValueOfType<int>(json, r'group_count')!,
        expenseCount: mapValueOfType<int>(json, r'expense_count')!,
        settlementCount: mapValueOfType<int>(json, r'settlement_count')!,
        personalCount: mapValueOfType<int>(json, r'personal_count')!,
        balances: MoneyTotal.listFromJson(json[r'balances']),
        lastActiveAt: mapDateTime(json, r'last_active_at', r''),
      );
    }
    return null;
  }

  static List<AdminUserOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminUserOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminUserOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminUserOut> mapFromJson(dynamic json) {
    final map = <String, AdminUserOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminUserOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminUserOut-objects as value to a dart map
  static Map<String, List<AdminUserOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminUserOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminUserOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
    'role',
    'currency',
    'created_at',
    'is_placeholder',
    'group_count',
    'expense_count',
    'settlement_count',
    'personal_count',
    'balances',
  };
}

