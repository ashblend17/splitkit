//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LayoutCard {
  /// Returns a new [LayoutCard] instance.
  LayoutCard({
    required this.type,
    required this.title,
    required this.period,
    required this.source_,
    this.params = const {},
  });

  String type;

  String title;

  String period;

  String source_;

  Map<String, Object> params;

  @override
  bool operator ==(Object other) => identical(this, other) || other is LayoutCard &&
    other.type == type &&
    other.title == title &&
    other.period == period &&
    other.source_ == source_ &&
    _deepEquality.equals(other.params, params);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (type.hashCode) +
    (title.hashCode) +
    (period.hashCode) +
    (source_.hashCode) +
    (params.hashCode);

  @override
  String toString() => 'LayoutCard[type=$type, title=$title, period=$period, source_=$source_, params=$params]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'type'] = this.type;
      json[r'title'] = this.title;
      json[r'period'] = this.period;
      json[r'source'] = this.source_;
      json[r'params'] = this.params;
    return json;
  }

  /// Returns a new [LayoutCard] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LayoutCard? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "LayoutCard[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "LayoutCard[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return LayoutCard(
        type: mapValueOfType<String>(json, r'type')!,
        title: mapValueOfType<String>(json, r'title')!,
        period: mapValueOfType<String>(json, r'period')!,
        source_: mapValueOfType<String>(json, r'source')!,
        params: mapCastOfType<String, Object>(json, r'params') ?? const {},
      );
    }
    return null;
  }

  static List<LayoutCard> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LayoutCard>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LayoutCard.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LayoutCard> mapFromJson(dynamic json) {
    final map = <String, LayoutCard>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LayoutCard.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LayoutCard-objects as value to a dart map
  static Map<String, List<LayoutCard>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<LayoutCard>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LayoutCard.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'type',
    'title',
    'period',
    'source',
  };
}

