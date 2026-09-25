//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LayoutOut {
  /// Returns a new [LayoutOut] instance.
  LayoutOut({
    this.cards = const [],
    this.available = const [],
    required this.customised,
  });

  List<LayoutCard> cards;

  List<LayoutCard> available;

  bool customised;

  @override
  bool operator ==(Object other) => identical(this, other) || other is LayoutOut &&
    _deepEquality.equals(other.cards, cards) &&
    _deepEquality.equals(other.available, available) &&
    other.customised == customised;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (cards.hashCode) +
    (available.hashCode) +
    (customised.hashCode);

  @override
  String toString() => 'LayoutOut[cards=$cards, available=$available, customised=$customised]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'cards'] = this.cards;
      json[r'available'] = this.available;
      json[r'customised'] = this.customised;
    return json;
  }

  /// Returns a new [LayoutOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LayoutOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "LayoutOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "LayoutOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return LayoutOut(
        cards: LayoutCard.listFromJson(json[r'cards']),
        available: LayoutCard.listFromJson(json[r'available']),
        customised: mapValueOfType<bool>(json, r'customised')!,
      );
    }
    return null;
  }

  static List<LayoutOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LayoutOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LayoutOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LayoutOut> mapFromJson(dynamic json) {
    final map = <String, LayoutOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LayoutOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LayoutOut-objects as value to a dart map
  static Map<String, List<LayoutOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<LayoutOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LayoutOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'cards',
    'available',
    'customised',
  };
}

