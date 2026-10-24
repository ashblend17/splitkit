//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class BalancesApi {
  BalancesApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Feed
  ///
  /// Expenses and payments, newest first, across your groups or within one group.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId:
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  ///
  /// * [bool] deleted:
  ///   Only deleted items, for a restore/trash view
  ///
  /// * [String] category:
  ///   Category key. Leaves payments out
  ///
  /// * [DateTime] start:
  ///
  /// * [DateTime] end:
  ///
  /// * [bool] unsettled:
  ///   Only expenses you are not square on yet. Leaves payments out
  ///
  /// * [String] q:
  ///   Expense description or a person's name
  Future<Response> feedWithHttpInfo({ String? groupId, int? limit, int? offset, bool? deleted, String? category, DateTime? start, DateTime? end, bool? unsettled, String? q, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/feed';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (groupId != null) {
      queryParams.addAll(_queryParams('', 'group_id', groupId));
    }
    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
    }
    if (offset != null) {
      queryParams.addAll(_queryParams('', 'offset', offset));
    }
    if (deleted != null) {
      queryParams.addAll(_queryParams('', 'deleted', deleted));
    }
    if (category != null) {
      queryParams.addAll(_queryParams('', 'category', category));
    }
    if (start != null) {
      queryParams.addAll(_queryParams('', 'start', start));
    }
    if (end != null) {
      queryParams.addAll(_queryParams('', 'end', end));
    }
    if (unsettled != null) {
      queryParams.addAll(_queryParams('', 'unsettled', unsettled));
    }
    if (q != null) {
      queryParams.addAll(_queryParams('', 'q', q));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Feed
  ///
  /// Expenses and payments, newest first, across your groups or within one group.
  ///
  /// Parameters:
  ///
  /// * [String] groupId:
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  ///
  /// * [bool] deleted:
  ///   Only deleted items, for a restore/trash view
  ///
  /// * [String] category:
  ///   Category key. Leaves payments out
  ///
  /// * [DateTime] start:
  ///
  /// * [DateTime] end:
  ///
  /// * [bool] unsettled:
  ///   Only expenses you are not square on yet. Leaves payments out
  ///
  /// * [String] q:
  ///   Expense description or a person's name
  Future<List<FeedItem>?> feed({ String? groupId, int? limit, int? offset, bool? deleted, String? category, DateTime? start, DateTime? end, bool? unsettled, String? q, }) async {
    final response = await feedWithHttpInfo( groupId: groupId, limit: limit, offset: offset, deleted: deleted, category: category, start: start, end: end, unsettled: unsettled, q: q, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<FeedItem>') as List)
        .cast<FeedItem>()
        .toList(growable: false);

    }
    return null;
  }

  /// Group Balances
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<Response> groupBalancesWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}/balances'
      .replaceAll('{group_id}', groupId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Group Balances
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<GroupBalancesOut?> groupBalances(String groupId,) async {
    final response = await groupBalancesWithHttpInfo(groupId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GroupBalancesOut',) as GroupBalancesOut;
    
    }
    return null;
  }

  /// Overall Balances
  ///
  /// Home: totals, balance with each friend across groups, and your net in each group.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> overallBalancesWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/balances';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Overall Balances
  ///
  /// Home: totals, balance with each friend across groups, and your net in each group.
  Future<OverallBalancesOut?> overallBalances() async {
    final response = await overallBalancesWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'OverallBalancesOut',) as OverallBalancesOut;
    
    }
    return null;
  }
}
