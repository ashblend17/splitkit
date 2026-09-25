//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

library openapi.api;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

part 'api_client.dart';
part 'api_helper.dart';
part 'api_exception.dart';
part 'auth/authentication.dart';
part 'auth/api_key_auth.dart';
part 'auth/oauth.dart';
part 'auth/http_basic_auth.dart';
part 'auth/http_bearer_auth.dart';

part 'api/analytics_api.dart';
part 'api/auth_api.dart';
part 'api/balances_api.dart';
part 'api/categories_api.dart';
part 'api/expenses_api.dart';
part 'api/groups_api.dart';
part 'api/personal_api.dart';
part 'api/settlements_api.dart';
part 'api/splits_api.dart';
part 'api/sync_api.dart';
part 'api/system_api.dart';
part 'api/users_api.dart';

part 'model/add_member_in.dart';
part 'model/analytics_card_out.dart';
part 'model/category_in.dart';
part 'model/category_out.dart';
part 'model/category_total.dart';
part 'model/chart_bar.dart';
part 'model/chart_row.dart';
part 'model/chart_stat.dart';
part 'model/currency_totals.dart';
part 'model/dashboard_out.dart';
part 'model/error_body.dart';
part 'model/error_response.dart';
part 'model/expense_in.dart';
part 'model/expense_out.dart';
part 'model/feed_item.dart';
part 'model/friend_balance.dart';
part 'model/friend_group_balance.dart';
part 'model/group_balances_out.dart';
part 'model/group_in.dart';
part 'model/group_net.dart';
part 'model/group_out.dart';
part 'model/group_update.dart';
part 'model/http_validation_error.dart';
part 'model/history_entry.dart';
part 'model/layout_card.dart';
part 'model/layout_in.dart';
part 'model/layout_out.dart';
part 'model/login_in.dart';
part 'model/member_out.dart';
part 'model/overall_balances_out.dart';
part 'model/person_balance.dart';
part 'model/personal_list_out.dart';
part 'model/personal_summary_out.dart';
part 'model/personal_txn_in.dart';
part 'model/personal_txn_out.dart';
part 'model/register_in.dart';
part 'model/settle_up_in.dart';
part 'model/settle_up_out.dart';
part 'model/settle_up_plan_out.dart';
part 'model/settlement_in.dart';
part 'model/settlement_out.dart';
part 'model/share_out.dart';
part 'model/split_in.dart';
part 'model/split_input_in.dart';
part 'model/split_method_out.dart';
part 'model/split_out.dart';
part 'model/split_preview_in.dart';
part 'model/split_preview_out.dart';
part 'model/suggested_payment.dart';
part 'model/sync_change.dart';
part 'model/sync_entity.dart';
part 'model/sync_in.dart';
part 'model/sync_out.dart';
part 'model/sync_snapshot_out.dart';
part 'model/sync_stream_out.dart';
part 'model/token_out.dart';
part 'model/user_brief.dart';
part 'model/user_out.dart';
part 'model/user_update.dart';
part 'model/validation_error.dart';


/// An [ApiClient] instance that uses the default values obtained from
/// the OpenAPI specification file.
var defaultApiClient = ApiClient();

const _delimiters = {'csv': ',', 'ssv': ' ', 'tsv': '\t', 'pipes': '|'};
const _dateEpochMarker = 'epoch';
const _deepEquality = DeepCollectionEquality();
final _dateFormatter = DateFormat('yyyy-MM-dd');
final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

bool _isEpochMarker(String? pattern) => pattern == _dateEpochMarker || pattern == '/$_dateEpochMarker/';
