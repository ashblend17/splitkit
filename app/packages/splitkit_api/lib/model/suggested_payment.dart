//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SuggestedPayment {
  /// Returns a new [SuggestedPayment] instance.
  SuggestedPayment({
    required this.fromUser,
    required this.toUser,
    required this.amountMinor,
  });

  UserBrief fromUser;

  UserBrief toUser;

  int amountMinor;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SuggestedPayment &&
    other.fromUser == fromUser &&
    other.toUser == toUser &&
    other.amountMinor == amountMinor;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (fromUser.hashCode) +
    (toUser.hashCode) +
    (amountMinor.hashCode);

  @override
  String toString() => 'SuggestedPayment[fromUser=$fromUser, toUser=$toUser, amountMinor=$amountMinor]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'from_user'] = this.fromUser;
      json[r'to_user'] = this.toUser;
      json[r'amount_minor'] = this.amountMinor;
    return json;
  }

  /// Returns a new [SuggestedPayment] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SuggestedPayment? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SuggestedPayment[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SuggestedPayment[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SuggestedPayment(
        fromUser: UserBrief.fromJson(json[r'from_user'])!,
        toUser: UserBrief.fromJson(json[r'to_user'])!,
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
      );
    }
    return null;
  }

  static List<SuggestedPayment> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SuggestedPayment>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SuggestedPayment.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SuggestedPayment> mapFromJson(dynamic json) {
    final map = <String, SuggestedPayment>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SuggestedPayment.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SuggestedPayment-objects as value to a dart map
  static Map<String, List<SuggestedPayment>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SuggestedPayment>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SuggestedPayment.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'from_user',
    'to_user',
    'amount_minor',
  };
}

