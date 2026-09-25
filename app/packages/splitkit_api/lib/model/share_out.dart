//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ShareOut {
  /// Returns a new [ShareOut] instance.
  ShareOut({
    required this.userId,
    required this.shareMinor,
    this.inputValue,
  });

  String userId;

  int shareMinor;

  String? inputValue;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ShareOut &&
    other.userId == userId &&
    other.shareMinor == shareMinor &&
    other.inputValue == inputValue;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (userId.hashCode) +
    (shareMinor.hashCode) +
    (inputValue == null ? 0 : inputValue!.hashCode);

  @override
  String toString() => 'ShareOut[userId=$userId, shareMinor=$shareMinor, inputValue=$inputValue]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'user_id'] = this.userId;
      json[r'share_minor'] = this.shareMinor;
    if (this.inputValue != null) {
      json[r'input_value'] = this.inputValue;
    } else {
      json[r'input_value'] = null;
    }
    return json;
  }

  /// Returns a new [ShareOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ShareOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ShareOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ShareOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ShareOut(
        userId: mapValueOfType<String>(json, r'user_id')!,
        shareMinor: mapValueOfType<int>(json, r'share_minor')!,
        inputValue: mapValueOfType<String>(json, r'input_value'),
      );
    }
    return null;
  }

  static List<ShareOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ShareOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ShareOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ShareOut> mapFromJson(dynamic json) {
    final map = <String, ShareOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ShareOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ShareOut-objects as value to a dart map
  static Map<String, List<ShareOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ShareOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ShareOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'user_id',
    'share_minor',
  };
}

