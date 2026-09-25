//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class DashboardOut {
  /// Returns a new [DashboardOut] instance.
  DashboardOut({
    required this.scope,
    required this.currency,
    this.subtitle,
    this.cards = const [],
  });

  DashboardOutScopeEnum scope;

  String currency;

  String? subtitle;

  List<AnalyticsCardOut> cards;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DashboardOut &&
    other.scope == scope &&
    other.currency == currency &&
    other.subtitle == subtitle &&
    _deepEquality.equals(other.cards, cards);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (scope.hashCode) +
    (currency.hashCode) +
    (subtitle == null ? 0 : subtitle!.hashCode) +
    (cards.hashCode);

  @override
  String toString() => 'DashboardOut[scope=$scope, currency=$currency, subtitle=$subtitle, cards=$cards]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'scope'] = this.scope;
      json[r'currency'] = this.currency;
    if (this.subtitle != null) {
      json[r'subtitle'] = this.subtitle;
    } else {
      json[r'subtitle'] = null;
    }
      json[r'cards'] = this.cards;
    return json;
  }

  /// Returns a new [DashboardOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DashboardOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "DashboardOut[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "DashboardOut[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return DashboardOut(
        scope: DashboardOutScopeEnum.fromJson(json[r'scope'])!,
        currency: mapValueOfType<String>(json, r'currency')!,
        subtitle: mapValueOfType<String>(json, r'subtitle'),
        cards: AnalyticsCardOut.listFromJson(json[r'cards']),
      );
    }
    return null;
  }

  static List<DashboardOut> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DashboardOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DashboardOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DashboardOut> mapFromJson(dynamic json) {
    final map = <String, DashboardOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DashboardOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DashboardOut-objects as value to a dart map
  static Map<String, List<DashboardOut>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DashboardOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DashboardOut.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'scope',
    'currency',
    'cards',
  };
}


class DashboardOutScopeEnum {
  /// Instantiate a new enum with the provided [value].
  const DashboardOutScopeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const personal = DashboardOutScopeEnum._(r'personal');
  static const group = DashboardOutScopeEnum._(r'group');

  /// List of all possible values in this [enum][DashboardOutScopeEnum].
  static const values = <DashboardOutScopeEnum>[
    personal,
    group,
  ];

  static DashboardOutScopeEnum? fromJson(dynamic value) => DashboardOutScopeEnumTypeTransformer().decode(value);

  static List<DashboardOutScopeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DashboardOutScopeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DashboardOutScopeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DashboardOutScopeEnum] to String,
/// and [decode] dynamic data back to [DashboardOutScopeEnum].
class DashboardOutScopeEnumTypeTransformer {
  factory DashboardOutScopeEnumTypeTransformer() => _instance ??= const DashboardOutScopeEnumTypeTransformer._();

  const DashboardOutScopeEnumTypeTransformer._();

  String encode(DashboardOutScopeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a DashboardOutScopeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DashboardOutScopeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'personal': return DashboardOutScopeEnum.personal;
        case r'group': return DashboardOutScopeEnum.group;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [DashboardOutScopeEnumTypeTransformer] instance.
  static DashboardOutScopeEnumTypeTransformer? _instance;
}


