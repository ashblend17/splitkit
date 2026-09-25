//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SplitPreviewOut {
  /// Returns a new [SplitPreviewOut] instance.
  SplitPreviewOut({
    required this.ok,
    required this.remainingMinor,
    required this.message,
    this.remainingPercent,
    this.shares = const [],
  });

  bool ok;

  int remainingMinor;

  String message;

  String? remainingPercent;

  List<ShareOut> shares;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SplitPreviewOut &&
    other.ok == ok &&
    other.remainingMinor == remainingMinor &&
    other.message == message &&
    other.remainingPercent == remainingPercent &&
    _deepEquality.equals(other.shares, shares);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (ok.hashCode) +
    (remainingMinor.hashCode) +
    (message.hashCode) +
    (remainingPercent == null ? 0 : remainingPercent!.hashCode) +
    (shares.hashCode);

  @override
  String toString() => 'SplitPreviewOut[ok=$ok, remainingMinor=$remainingMinor, message=$message, remainingPercent=$remainingPercent, shares=$shares]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'ok'] = this.ok;
      json[r'remaining_minor'] = this.remainingMinor;
      json[r'message'] = this.message;
    if (this.remainingPercent != null) {
      json[r'remaining_percent'] = this.remainingPercent;
    } else {
      json[r'remaining_percent'] = null;
    }
      json[r'shares'] = this.shares;
    return json;
  }

  /// Returns a new [SplitPreviewOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SplitPreviewOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SplitPreviewOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SplitPreviewOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SplitPreviewOut(
        ok: mapValueOfType<bool>(json, r'ok')!,
        remainingMinor: mapValueOfType<int>(json, r'remaining_minor')!,
        message: mapValueOfType<String>(json, r'message')!,
        remainingPercent: mapValueOfType<String>(json, r'remaining_percent'),
        shares: ShareOut.listFromJson(json[r'shares']),
      );
    }
    return null;
  }

  static List<SplitPreviewOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SplitPreviewOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SplitPreviewOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SplitPreviewOut> mapFromJson(dynamic json) {
    final map = <String, SplitPreviewOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SplitPreviewOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SplitPreviewOut-objects as value to a dart map
  static Map<String, List<SplitPreviewOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SplitPreviewOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SplitPreviewOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'ok',
    'remaining_minor',
    'message',
    'shares',
  };
}

