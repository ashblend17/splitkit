//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminDashboardOut {
  /// Returns a new [AdminDashboardOut] instance.
  AdminDashboardOut({
    required this.users,
    required this.admins,
    required this.placeholders,
    required this.groups,
    required this.groupsActiveWeek,
    required this.expenses,
    required this.expensesImported,
    this.expenseVolume = const [],
    required this.settlements,
    this.settlementVolume = const [],
    required this.personalTransactions,
    required this.personalUsers,
    required this.openSessions,
    this.recent = const [],
    required this.system,
  });

  int users;

  int admins;

  int placeholders;

  int groups;

  int groupsActiveWeek;

  int expenses;

  int expensesImported;

  List<MoneyTotal> expenseVolume;

  int settlements;

  List<MoneyTotal> settlementVolume;

  int personalTransactions;

  int personalUsers;

  int openSessions;

  List<AuditEntryOut> recent;

  SystemOut system;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminDashboardOut &&
    other.users == users &&
    other.admins == admins &&
    other.placeholders == placeholders &&
    other.groups == groups &&
    other.groupsActiveWeek == groupsActiveWeek &&
    other.expenses == expenses &&
    other.expensesImported == expensesImported &&
    _deepEquality.equals(other.expenseVolume, expenseVolume) &&
    other.settlements == settlements &&
    _deepEquality.equals(other.settlementVolume, settlementVolume) &&
    other.personalTransactions == personalTransactions &&
    other.personalUsers == personalUsers &&
    other.openSessions == openSessions &&
    _deepEquality.equals(other.recent, recent) &&
    other.system == system;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (users.hashCode) +
    (admins.hashCode) +
    (placeholders.hashCode) +
    (groups.hashCode) +
    (groupsActiveWeek.hashCode) +
    (expenses.hashCode) +
    (expensesImported.hashCode) +
    (expenseVolume.hashCode) +
    (settlements.hashCode) +
    (settlementVolume.hashCode) +
    (personalTransactions.hashCode) +
    (personalUsers.hashCode) +
    (openSessions.hashCode) +
    (recent.hashCode) +
    (system.hashCode);

  @override
  String toString() => 'AdminDashboardOut[users=$users, admins=$admins, placeholders=$placeholders, groups=$groups, groupsActiveWeek=$groupsActiveWeek, expenses=$expenses, expensesImported=$expensesImported, expenseVolume=$expenseVolume, settlements=$settlements, settlementVolume=$settlementVolume, personalTransactions=$personalTransactions, personalUsers=$personalUsers, openSessions=$openSessions, recent=$recent, system=$system]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'users'] = this.users;
      json[r'admins'] = this.admins;
      json[r'placeholders'] = this.placeholders;
      json[r'groups'] = this.groups;
      json[r'groups_active_week'] = this.groupsActiveWeek;
      json[r'expenses'] = this.expenses;
      json[r'expenses_imported'] = this.expensesImported;
      json[r'expense_volume'] = this.expenseVolume;
      json[r'settlements'] = this.settlements;
      json[r'settlement_volume'] = this.settlementVolume;
      json[r'personal_transactions'] = this.personalTransactions;
      json[r'personal_users'] = this.personalUsers;
      json[r'open_sessions'] = this.openSessions;
      json[r'recent'] = this.recent;
      json[r'system'] = this.system;
    return json;
  }

  /// Returns a new [AdminDashboardOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminDashboardOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminDashboardOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminDashboardOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminDashboardOut(
        users: mapValueOfType<int>(json, r'users')!,
        admins: mapValueOfType<int>(json, r'admins')!,
        placeholders: mapValueOfType<int>(json, r'placeholders')!,
        groups: mapValueOfType<int>(json, r'groups')!,
        groupsActiveWeek: mapValueOfType<int>(json, r'groups_active_week')!,
        expenses: mapValueOfType<int>(json, r'expenses')!,
        expensesImported: mapValueOfType<int>(json, r'expenses_imported')!,
        expenseVolume: MoneyTotal.listFromJson(json[r'expense_volume']),
        settlements: mapValueOfType<int>(json, r'settlements')!,
        settlementVolume: MoneyTotal.listFromJson(json[r'settlement_volume']),
        personalTransactions: mapValueOfType<int>(json, r'personal_transactions')!,
        personalUsers: mapValueOfType<int>(json, r'personal_users')!,
        openSessions: mapValueOfType<int>(json, r'open_sessions')!,
        recent: AuditEntryOut.listFromJson(json[r'recent']),
        system: SystemOut.fromJson(json[r'system'])!,
      );
    }
    return null;
  }

  static List<AdminDashboardOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminDashboardOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminDashboardOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminDashboardOut> mapFromJson(dynamic json) {
    final map = <String, AdminDashboardOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminDashboardOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminDashboardOut-objects as value to a dart map
  static Map<String, List<AdminDashboardOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminDashboardOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminDashboardOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'users',
    'admins',
    'placeholders',
    'groups',
    'groups_active_week',
    'expenses',
    'expenses_imported',
    'expense_volume',
    'settlements',
    'settlement_volume',
    'personal_transactions',
    'personal_users',
    'open_sessions',
    'recent',
    'system',
  };
}

