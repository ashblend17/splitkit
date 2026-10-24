//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class FeedItem {
  /// Returns a new [FeedItem] instance.
  FeedItem({
    required this.kind,
    required this.id,
    required this.groupId,
    required this.groupName,
    this.title,
    required this.date,
    required this.createdAt,
    required this.amountMinor,
    required this.currency,
    this.category,
    required this.payer,
    this.toUser,
    required this.method,
    required this.participantCount,
    required this.myShareMinor,
    required this.myNetMinor,
    required this.settled,
    required this.byAdmin,
    this.deletedAt,
  });

  FeedItemKindEnum kind;

  String id;

  String groupId;

  String groupName;

  String? title;

  DateTime date;

  DateTime createdAt;

  int amountMinor;

  String currency;

  CategoryOut? category;

  UserBrief payer;

  UserBrief? toUser;

  String method;

  int participantCount;

  int myShareMinor;

  int myNetMinor;

  bool settled;

  bool byAdmin;

  DateTime? deletedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is FeedItem &&
    other.kind == kind &&
    other.id == id &&
    other.groupId == groupId &&
    other.groupName == groupName &&
    other.title == title &&
    other.date == date &&
    other.createdAt == createdAt &&
    other.amountMinor == amountMinor &&
    other.currency == currency &&
    other.category == category &&
    other.payer == payer &&
    other.toUser == toUser &&
    other.method == method &&
    other.participantCount == participantCount &&
    other.myShareMinor == myShareMinor &&
    other.myNetMinor == myNetMinor &&
    other.settled == settled &&
    other.byAdmin == byAdmin &&
    other.deletedAt == deletedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (kind.hashCode) +
    (id.hashCode) +
    (groupId.hashCode) +
    (groupName.hashCode) +
    (title == null ? 0 : title!.hashCode) +
    (date.hashCode) +
    (createdAt.hashCode) +
    (amountMinor.hashCode) +
    (currency.hashCode) +
    (category == null ? 0 : category!.hashCode) +
    (payer.hashCode) +
    (toUser == null ? 0 : toUser!.hashCode) +
    (method.hashCode) +
    (participantCount.hashCode) +
    (myShareMinor.hashCode) +
    (myNetMinor.hashCode) +
    (settled.hashCode) +
    (byAdmin.hashCode) +
    (deletedAt == null ? 0 : deletedAt!.hashCode);

  @override
  String toString() => 'FeedItem[kind=$kind, id=$id, groupId=$groupId, groupName=$groupName, title=$title, date=$date, createdAt=$createdAt, amountMinor=$amountMinor, currency=$currency, category=$category, payer=$payer, toUser=$toUser, method=$method, participantCount=$participantCount, myShareMinor=$myShareMinor, myNetMinor=$myNetMinor, settled=$settled, byAdmin=$byAdmin, deletedAt=$deletedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'kind'] = this.kind;
      json[r'id'] = this.id;
      json[r'group_id'] = this.groupId;
      json[r'group_name'] = this.groupName;
    if (this.title != null) {
      json[r'title'] = this.title;
    } else {
      json[r'title'] = null;
    }
      json[r'date'] = _dateFormatter.format(this.date.toUtc());
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
      json[r'amount_minor'] = this.amountMinor;
      json[r'currency'] = this.currency;
    if (this.category != null) {
      json[r'category'] = this.category;
    } else {
      json[r'category'] = null;
    }
      json[r'payer'] = this.payer;
    if (this.toUser != null) {
      json[r'to_user'] = this.toUser;
    } else {
      json[r'to_user'] = null;
    }
      json[r'method'] = this.method;
      json[r'participant_count'] = this.participantCount;
      json[r'my_share_minor'] = this.myShareMinor;
      json[r'my_net_minor'] = this.myNetMinor;
      json[r'settled'] = this.settled;
      json[r'by_admin'] = this.byAdmin;
    if (this.deletedAt != null) {
      json[r'deleted_at'] = this.deletedAt!.toUtc().toIso8601String();
    } else {
      json[r'deleted_at'] = null;
    }
    return json;
  }

  /// Returns a new [FeedItem] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FeedItem? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "FeedItem[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "FeedItem[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return FeedItem(
        kind: FeedItemKindEnum.fromJson(json[r'kind'])!,
        id: mapValueOfType<String>(json, r'id')!,
        groupId: mapValueOfType<String>(json, r'group_id')!,
        groupName: mapValueOfType<String>(json, r'group_name')!,
        title: mapValueOfType<String>(json, r'title'),
        date: mapDateTime(json, r'date', r'')!,
        createdAt: mapDateTime(json, r'created_at', r'')!,
        amountMinor: mapValueOfType<int>(json, r'amount_minor')!,
        currency: mapValueOfType<String>(json, r'currency')!,
        category: CategoryOut.fromJson(json[r'category']),
        payer: UserBrief.fromJson(json[r'payer'])!,
        toUser: UserBrief.fromJson(json[r'to_user']),
        method: mapValueOfType<String>(json, r'method')!,
        participantCount: mapValueOfType<int>(json, r'participant_count')!,
        myShareMinor: mapValueOfType<int>(json, r'my_share_minor')!,
        myNetMinor: mapValueOfType<int>(json, r'my_net_minor')!,
        settled: mapValueOfType<bool>(json, r'settled')!,
        byAdmin: mapValueOfType<bool>(json, r'by_admin')!,
        deletedAt: mapDateTime(json, r'deleted_at', r''),
      );
    }
    return null;
  }

  static List<FeedItem> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FeedItem>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FeedItem.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FeedItem> mapFromJson(dynamic json) {
    final map = <String, FeedItem>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FeedItem.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FeedItem-objects as value to a dart map
  static Map<String, List<FeedItem>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<FeedItem>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FeedItem.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'kind',
    'id',
    'group_id',
    'group_name',
    'date',
    'created_at',
    'amount_minor',
    'currency',
    'payer',
    'method',
    'participant_count',
    'my_share_minor',
    'my_net_minor',
    'settled',
    'by_admin',
  };
}


class FeedItemKindEnum {
  /// Instantiate a new enum with the provided [value].
  const FeedItemKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const expense = FeedItemKindEnum._(r'expense');
  static const settlement = FeedItemKindEnum._(r'settlement');

  /// List of all possible values in this [enum][FeedItemKindEnum].
  static const values = <FeedItemKindEnum>[
    expense,
    settlement,
  ];

  static FeedItemKindEnum? fromJson(dynamic value) => FeedItemKindEnumTypeTransformer().decode(value);

  static List<FeedItemKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FeedItemKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FeedItemKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [FeedItemKindEnum] to String,
/// and [decode] dynamic data back to [FeedItemKindEnum].
class FeedItemKindEnumTypeTransformer {
  factory FeedItemKindEnumTypeTransformer() => _instance ??= const FeedItemKindEnumTypeTransformer._();

  const FeedItemKindEnumTypeTransformer._();

  String encode(FeedItemKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a FeedItemKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  FeedItemKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'expense': return FeedItemKindEnum.expense;
        case r'settlement': return FeedItemKindEnum.settlement;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [FeedItemKindEnumTypeTransformer] instance.
  static FeedItemKindEnumTypeTransformer? _instance;
}


