//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class SettlementsApi {
  SettlementsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Create Settlement
  ///
  /// Record a payment between two members. It never changes any expense.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [SettlementIn] settlementIn (required):
  Future<Response> createSettlementWithHttpInfo(String groupId, SettlementIn settlementIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}/settlements'
      .replaceAll('{group_id}', groupId);

    // ignore: prefer_final_locals
    Object? postBody = settlementIn;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Create Settlement
  ///
  /// Record a payment between two members. It never changes any expense.
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [SettlementIn] settlementIn (required):
  Future<SettlementOut?> createSettlement(String groupId, SettlementIn settlementIn,) async {
    final response = await createSettlementWithHttpInfo(groupId, settlementIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SettlementOut',) as SettlementOut;
    
    }
    return null;
  }

  /// Delete Settlement
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] settlementId (required):
  ///
  /// * [int] version:
  Future<Response> deleteSettlementWithHttpInfo(String settlementId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/settlements/{settlement_id}'
      .replaceAll('{settlement_id}', settlementId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (version != null) {
      queryParams.addAll(_queryParams('', 'version', version));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Delete Settlement
  ///
  /// Parameters:
  ///
  /// * [String] settlementId (required):
  ///
  /// * [int] version:
  Future<SettlementOut?> deleteSettlement(String settlementId, { int? version, }) async {
    final response = await deleteSettlementWithHttpInfo(settlementId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SettlementOut',) as SettlementOut;
    
    }
    return null;
  }

  /// Get Settlement
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] settlementId (required):
  Future<Response> getSettlementWithHttpInfo(String settlementId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/settlements/{settlement_id}'
      .replaceAll('{settlement_id}', settlementId);

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

  /// Get Settlement
  ///
  /// Parameters:
  ///
  /// * [String] settlementId (required):
  Future<SettlementOut?> getSettlement(String settlementId,) async {
    final response = await getSettlementWithHttpInfo(settlementId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SettlementOut',) as SettlementOut;
    
    }
    return null;
  }

  /// List Settlements
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<Response> listSettlementsWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}/settlements'
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

  /// List Settlements
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<List<SettlementOut>?> listSettlements(String groupId,) async {
    final response = await listSettlementsWithHttpInfo(groupId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<SettlementOut>') as List)
        .cast<SettlementOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// Restore Settlement
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] settlementId (required):
  ///
  /// * [int] version:
  Future<Response> restoreSettlementWithHttpInfo(String settlementId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/settlements/{settlement_id}/restore'
      .replaceAll('{settlement_id}', settlementId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (version != null) {
      queryParams.addAll(_queryParams('', 'version', version));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Restore Settlement
  ///
  /// Parameters:
  ///
  /// * [String] settlementId (required):
  ///
  /// * [int] version:
  Future<SettlementOut?> restoreSettlement(String settlementId, { int? version, }) async {
    final response = await restoreSettlementWithHttpInfo(settlementId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SettlementOut',) as SettlementOut;
    
    }
    return null;
  }

  /// Settle Up
  ///
  /// Settle with a friend across groups: one settlement per group, saved together.  Without `amount_minor` every shared group ends at zero. With it, the payment pays down the groups owed in its direction, oldest first.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [SettleUpIn] settleUpIn (required):
  Future<Response> settleUpWithHttpInfo(String userId, SettleUpIn settleUpIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/friends/{user_id}/settle-up'
      .replaceAll('{user_id}', userId);

    // ignore: prefer_final_locals
    Object? postBody = settleUpIn;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Settle Up
  ///
  /// Settle with a friend across groups: one settlement per group, saved together.  Without `amount_minor` every shared group ends at zero. With it, the payment pays down the groups owed in its direction, oldest first.
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [SettleUpIn] settleUpIn (required):
  Future<SettleUpOut?> settleUp(String userId, SettleUpIn settleUpIn,) async {
    final response = await settleUpWithHttpInfo(userId, settleUpIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SettleUpOut',) as SettleUpOut;
    
    }
    return null;
  }

  /// Settle Up Plan
  ///
  /// Your balance with a friend in each group you share, for the \"Settle up\" sheet.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [String] currency:
  Future<Response> settleUpPlanWithHttpInfo(String userId, { String? currency, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/friends/{user_id}/settle-up'
      .replaceAll('{user_id}', userId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (currency != null) {
      queryParams.addAll(_queryParams('', 'currency', currency));
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

  /// Settle Up Plan
  ///
  /// Your balance with a friend in each group you share, for the \"Settle up\" sheet.
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [String] currency:
  Future<SettleUpPlanOut?> settleUpPlan(String userId, { String? currency, }) async {
    final response = await settleUpPlanWithHttpInfo(userId,  currency: currency, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SettleUpPlanOut',) as SettleUpPlanOut;
    
    }
    return null;
  }
}
