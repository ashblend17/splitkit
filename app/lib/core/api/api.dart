import 'dart:convert';

import 'package:api_client/api.dart';

import '../config.dart';

export 'package:api_client/api.dart';

/// The generated client (app/packages/api_client, from api/openapi.json) plus bearer auth.
/// Regenerate with `tool/gen_api_client.sh`; never edit the generated package by hand.
class Api {
  Api({String? origin, String? token}) : client = ApiClient(basePath: origin ?? AppConfig.apiOrigin) {
    this.token = token;
  }

  final ApiClient client;

  set token(String? value) {
    if (value == null) {
      client.defaultHeaderMap.remove('Authorization');
    } else {
      client.addDefaultHeader('Authorization', 'Bearer $value');
    }
  }

  late final auth = AuthApi(client);
  late final users = UsersApi(client);
  late final groups = GroupsApi(client);
  late final categories = CategoriesApi(client);
  late final splits = SplitsApi(client);
  late final expenses = ExpensesApi(client);
  late final settlements = SettlementsApi(client);
  late final balances = BalancesApi(client);
  late final personal = PersonalApi(client);
  late final analytics = AnalyticsApi(client);
  late final sync = SyncApi(client);
  late final tricount = TricountApi(client); // features/tricount_sync
  late final system = SystemApi(client);
}

/// The human message from the API's error body ({"error": {"code", "message"}}), for showing
/// as-is, or a generic fallback.
String apiErrorMessage(Object error) {
  if (error is ApiException && error.message != null) {
    try {
      final body = jsonDecode(error.message!);
      if (body is Map && body['error'] is Map) {
        final message = (body['error'] as Map)['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } on FormatException {
      // Not JSON (proxy error page, timeout text): fall through.
    }
  }
  return 'Something went wrong. Please try again.';
}

/// The `code` of an API error ("no_account", "version_conflict"…), or null.
String? apiErrorCode(Object error) {
  if (error is ApiException && error.message != null) {
    try {
      final body = jsonDecode(error.message!);
      if (body is Map && body['error'] is Map) return (body['error'] as Map)['code'] as String?;
    } on FormatException {
      return null;
    }
  }
  return null;
}

/// A calendar date for the API, in bodies and query strings alike. The generated client sends
/// `date.toUtc()`, which turns local midnight in India into the previous day, so API dates
/// must be built in UTC (the API accepts a timestamp at exactly midnight UTC as a date).
DateTime apiDate(DateTime day) => DateTime.utc(day.year, day.month, day.day);
