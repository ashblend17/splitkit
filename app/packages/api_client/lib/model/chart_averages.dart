//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ChartAverages {
  /// Returns a new [ChartAverages] instance.
  ChartAverages({
    required this.label,
    required this.nowLabel,
    required this.unit,
    this.rows = const [],
  });

  String label;

  String nowLabel;

  ChartAveragesUnitEnum unit;

  List<ChartAverage> rows;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ChartAverages &&
    other.label == label &&
    other.nowLabel == nowLabel &&
    other.unit == unit &&
    _deepEquality.equals(other.rows, rows);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (label.hashCode) +
    (nowLabel.hashCode) +
    (unit.hashCode) +
    (rows.hashCode);

  @override
  String toString() => 'ChartAverages[label=$label, nowLabel=$nowLabel, unit=$unit, rows=$rows]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'label'] = this.label;
      json[r'now_label'] = this.nowLabel;
      json[r'unit'] = this.unit;
      json[r'rows'] = this.rows;
    return json;
  }

  /// Returns a new [ChartAverages] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ChartAverages? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ChartAverages[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ChartAverages[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ChartAverages(
        label: mapValueOfType<String>(json, r'label')!,
        nowLabel: mapValueOfType<String>(json, r'now_label')!,
        unit: ChartAveragesUnitEnum.fromJson(json[r'unit'])!,
        rows: ChartAverage.listFromJson(json[r'rows']),
      );
    }
    return null;
  }

  static List<ChartAverages> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ChartAverages>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ChartAverages.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ChartAverages> mapFromJson(dynamic json) {
    final map = <String, ChartAverages>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ChartAverages.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ChartAverages-objects as value to a dart map
  static Map<String, List<ChartAverages>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ChartAverages>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ChartAverages.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'label',
    'now_label',
    'unit',
    'rows',
  };
}


class ChartAveragesUnitEnum {
  /// Instantiate a new enum with the provided [value].
  const ChartAveragesUnitEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const week = ChartAveragesUnitEnum._(r'week');
  static const month = ChartAveragesUnitEnum._(r'month');

  /// List of all possible values in this [enum][ChartAveragesUnitEnum].
  static const values = <ChartAveragesUnitEnum>[
    week,
    month,
  ];

  static ChartAveragesUnitEnum? fromJson(dynamic value) => ChartAveragesUnitEnumTypeTransformer().decode(value);

  static List<ChartAveragesUnitEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ChartAveragesUnitEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ChartAveragesUnitEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ChartAveragesUnitEnum] to String,
/// and [decode] dynamic data back to [ChartAveragesUnitEnum].
class ChartAveragesUnitEnumTypeTransformer {
  factory ChartAveragesUnitEnumTypeTransformer() => _instance ??= const ChartAveragesUnitEnumTypeTransformer._();

  const ChartAveragesUnitEnumTypeTransformer._();

  String encode(ChartAveragesUnitEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ChartAveragesUnitEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ChartAveragesUnitEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'week': return ChartAveragesUnitEnum.week;
        case r'month': return ChartAveragesUnitEnum.month;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ChartAveragesUnitEnumTypeTransformer] instance.
  static ChartAveragesUnitEnumTypeTransformer? _instance;
}


