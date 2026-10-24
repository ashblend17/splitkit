//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AccountOut {
  /// Returns a new [AccountOut] instance.
  AccountOut({
    required this.account,
    required this.currency,
    this.balanceMinor,
    this.balanceAt,
    required this.count,
  });

  String account;

  String currency;

  int? balanceMinor;

  DateTime? balanceAt;

  int count;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AccountOut &&
    other.account == account &&
    other.currency == currency &&
    other.balanceMinor == balanceMinor &&
    other.balanceAt == balanceAt &&
    other.count == count;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (account.hashCode) +
    (currency.hashCode) +
    (balanceMinor == null ? 0 : balanceMinor!.hashCode) +
    (balanceAt == null ? 0 : balanceAt!.hashCode) +
    (count.hashCode);

  @override
  String toString() => 'AccountOut[account=$account, currency=$currency, balanceMinor=$balanceMinor, balanceAt=$balanceAt, count=$count]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'account'] = this.account;
      json[r'currency'] = this.currency;
    if (this.balanceMinor != null) {
      json[r'balance_minor'] = this.balanceMinor;
    } else {
      json[r'balance_minor'] = null;
    }
    if (this.balanceAt != null) {
      json[r'balance_at'] = this.balanceAt!.toUtc().toIso8601String();
    } else {
      json[r'balance_at'] = null;
    }
      json[r'count'] = this.count;
    return json;
  }

  /// Returns a new [AccountOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AccountOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AccountOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AccountOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AccountOut(
        account: mapValueOfType<String>(json, r'account')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        balanceMinor: mapValueOfType<int>(json, r'balance_minor'),
        balanceAt: mapDateTime(json, r'balance_at', r''),
        count: mapValueOfType<int>(json, r'count')!,
      );
    }
    return null;
  }

  static List<AccountOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AccountOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AccountOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AccountOut> mapFromJson(dynamic json) {
    final map = <String, AccountOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AccountOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AccountOut-objects as value to a dart map
  static Map<String, List<AccountOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AccountOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AccountOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'account',
    'currency',
    'count',
  };
}

