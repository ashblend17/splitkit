//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TricountStatusOut {
  /// Returns a new [TricountStatusOut] instance.
  TricountStatusOut({
    required this.linked,
    this.link,
  });

  bool linked;

  TricountLinkOut? link;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TricountStatusOut &&
    other.linked == linked &&
    other.link == link;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (linked.hashCode) +
    (link == null ? 0 : link!.hashCode);

  @override
  String toString() => 'TricountStatusOut[linked=$linked, link=$link]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'linked'] = this.linked;
    if (this.link != null) {
      json[r'link'] = this.link;
    } else {
      json[r'link'] = null;
    }
    return json;
  }

  /// Returns a new [TricountStatusOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TricountStatusOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "TricountStatusOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "TricountStatusOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return TricountStatusOut(
        linked: mapValueOfType<bool>(json, r'linked')!,
        link: TricountLinkOut.fromJson(json[r'link']),
      );
    }
    return null;
  }

  static List<TricountStatusOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TricountStatusOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TricountStatusOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TricountStatusOut> mapFromJson(dynamic json) {
    final map = <String, TricountStatusOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TricountStatusOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TricountStatusOut-objects as value to a dart map
  static Map<String, List<TricountStatusOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TricountStatusOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TricountStatusOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'linked',
  };
}

