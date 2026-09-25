//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AnalyticsCardOut {
  /// Returns a new [AnalyticsCardOut] instance.
  AnalyticsCardOut({
    required this.id,
    required this.type,
    required this.title,
    required this.periodLabel,
    required this.source_,
    this.headline,
    this.bars = const [],
    this.rows = const [],
    this.stat,
  });

  String id;

  String type;

  String title;

  String periodLabel;

  String source_;

  String? headline;

  List<ChartBar> bars;

  List<ChartRow> rows;

  ChartStat? stat;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AnalyticsCardOut &&
    other.id == id &&
    other.type == type &&
    other.title == title &&
    other.periodLabel == periodLabel &&
    other.source_ == source_ &&
    other.headline == headline &&
    _deepEquality.equals(other.bars, bars) &&
    _deepEquality.equals(other.rows, rows) &&
    other.stat == stat;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (type.hashCode) +
    (title.hashCode) +
    (periodLabel.hashCode) +
    (source_.hashCode) +
    (headline == null ? 0 : headline!.hashCode) +
    (bars.hashCode) +
    (rows.hashCode) +
    (stat == null ? 0 : stat!.hashCode);

  @override
  String toString() => 'AnalyticsCardOut[id=$id, type=$type, title=$title, periodLabel=$periodLabel, source_=$source_, headline=$headline, bars=$bars, rows=$rows, stat=$stat]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'type'] = this.type;
      json[r'title'] = this.title;
      json[r'period_label'] = this.periodLabel;
      json[r'source'] = this.source_;
    if (this.headline != null) {
      json[r'headline'] = this.headline;
    } else {
      json[r'headline'] = null;
    }
      json[r'bars'] = this.bars;
      json[r'rows'] = this.rows;
    if (this.stat != null) {
      json[r'stat'] = this.stat;
    } else {
      json[r'stat'] = null;
    }
    return json;
  }

  /// Returns a new [AnalyticsCardOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AnalyticsCardOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AnalyticsCardOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AnalyticsCardOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AnalyticsCardOut(
        id: mapValueOfType<String>(json, r'id')!,
        type: mapValueOfType<String>(json, r'type')!,
        title: mapValueOfType<String>(json, r'title')!,
        periodLabel: mapValueOfType<String>(json, r'period_label')!,
        source_: mapValueOfType<String>(json, r'source')!,
        headline: mapValueOfType<String>(json, r'headline'),
        bars: ChartBar.listFromJson(json[r'bars']),
        rows: ChartRow.listFromJson(json[r'rows']),
        stat: ChartStat.fromJson(json[r'stat']),
      );
    }
    return null;
  }

  static List<AnalyticsCardOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AnalyticsCardOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AnalyticsCardOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AnalyticsCardOut> mapFromJson(dynamic json) {
    final map = <String, AnalyticsCardOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AnalyticsCardOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AnalyticsCardOut-objects as value to a dart map
  static Map<String, List<AnalyticsCardOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AnalyticsCardOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AnalyticsCardOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'type',
    'title',
    'period_label',
    'source',
  };
}

