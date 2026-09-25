//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class PersonalApi {
  PersonalApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Create Personal
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PersonalTxnIn] personalTxnIn (required):
  Future<Response> createPersonalWithHttpInfo(PersonalTxnIn personalTxnIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/transactions';

    // ignore: prefer_final_locals
    Object? postBody = personalTxnIn;

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

  /// Create Personal
  ///
  /// Parameters:
  ///
  /// * [PersonalTxnIn] personalTxnIn (required):
  Future<PersonalTxnOut?> createPersonal(PersonalTxnIn personalTxnIn,) async {
    final response = await createPersonalWithHttpInfo(personalTxnIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalTxnOut',) as PersonalTxnOut;
    
    }
    return null;
  }

  /// Delete Personal
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] txnId (required):
  ///
  /// * [int] version:
  Future<Response> deletePersonalWithHttpInfo(String txnId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/transactions/{txn_id}'
      .replaceAll('{txn_id}', txnId);

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

  /// Delete Personal
  ///
  /// Parameters:
  ///
  /// * [String] txnId (required):
  ///
  /// * [int] version:
  Future<PersonalTxnOut?> deletePersonal(String txnId, { int? version, }) async {
    final response = await deletePersonalWithHttpInfo(txnId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalTxnOut',) as PersonalTxnOut;
    
    }
    return null;
  }

  /// Get Personal
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] txnId (required):
  Future<Response> getPersonalWithHttpInfo(String txnId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/transactions/{txn_id}'
      .replaceAll('{txn_id}', txnId);

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

  /// Get Personal
  ///
  /// Parameters:
  ///
  /// * [String] txnId (required):
  Future<PersonalTxnOut?> getPersonal(String txnId,) async {
    final response = await getPersonalWithHttpInfo(txnId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalTxnOut',) as PersonalTxnOut;
    
    }
    return null;
  }

  /// List Personal
  ///
  /// Your own income and spending (only you see these), newest first, with totals.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] start:
  ///
  /// * [DateTime] end:
  ///
  /// * [String] type:
  ///
  /// * [List<String>] category:
  ///   Category keys, repeatable
  ///
  /// * [bool] deleted:
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  Future<Response> listPersonalWithHttpInfo({ DateTime? start, DateTime? end, String? type, List<String>? category, bool? deleted, int? limit, int? offset, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/transactions';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (start != null) {
      queryParams.addAll(_queryParams('', 'start', start));
    }
    if (end != null) {
      queryParams.addAll(_queryParams('', 'end', end));
    }
    if (type != null) {
      queryParams.addAll(_queryParams('', 'type', type));
    }
    if (category != null) {
      queryParams.addAll(_queryParams('multi', 'category', category));
    }
    if (deleted != null) {
      queryParams.addAll(_queryParams('', 'deleted', deleted));
    }
    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
    }
    if (offset != null) {
      queryParams.addAll(_queryParams('', 'offset', offset));
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

  /// List Personal
  ///
  /// Your own income and spending (only you see these), newest first, with totals.
  ///
  /// Parameters:
  ///
  /// * [DateTime] start:
  ///
  /// * [DateTime] end:
  ///
  /// * [String] type:
  ///
  /// * [List<String>] category:
  ///   Category keys, repeatable
  ///
  /// * [bool] deleted:
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  Future<PersonalListOut?> listPersonal({ DateTime? start, DateTime? end, String? type, List<String>? category, bool? deleted, int? limit, int? offset, }) async {
    final response = await listPersonalWithHttpInfo( start: start, end: end, type: type, category: category, deleted: deleted, limit: limit, offset: offset, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalListOut',) as PersonalListOut;
    
    }
    return null;
  }

  /// Personal Summary
  ///
  /// One month at a glance. `month` is any date inside it (default: this month).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] month:
  Future<Response> personalSummaryWithHttpInfo({ DateTime? month, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/summary';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (month != null) {
      queryParams.addAll(_queryParams('', 'month', month));
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

  /// Personal Summary
  ///
  /// One month at a glance. `month` is any date inside it (default: this month).
  ///
  /// Parameters:
  ///
  /// * [DateTime] month:
  Future<PersonalSummaryOut?> personalSummary({ DateTime? month, }) async {
    final response = await personalSummaryWithHttpInfo( month: month, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalSummaryOut',) as PersonalSummaryOut;
    
    }
    return null;
  }

  /// Restore Personal
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] txnId (required):
  ///
  /// * [int] version:
  Future<Response> restorePersonalWithHttpInfo(String txnId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/transactions/{txn_id}/restore'
      .replaceAll('{txn_id}', txnId);

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

  /// Restore Personal
  ///
  /// Parameters:
  ///
  /// * [String] txnId (required):
  ///
  /// * [int] version:
  Future<PersonalTxnOut?> restorePersonal(String txnId, { int? version, }) async {
    final response = await restorePersonalWithHttpInfo(txnId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalTxnOut',) as PersonalTxnOut;
    
    }
    return null;
  }

  /// Update Personal
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] txnId (required):
  ///
  /// * [PersonalTxnIn] personalTxnIn (required):
  Future<Response> updatePersonalWithHttpInfo(String txnId, PersonalTxnIn personalTxnIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/transactions/{txn_id}'
      .replaceAll('{txn_id}', txnId);

    // ignore: prefer_final_locals
    Object? postBody = personalTxnIn;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Update Personal
  ///
  /// Parameters:
  ///
  /// * [String] txnId (required):
  ///
  /// * [PersonalTxnIn] personalTxnIn (required):
  Future<PersonalTxnOut?> updatePersonal(String txnId, PersonalTxnIn personalTxnIn,) async {
    final response = await updatePersonalWithHttpInfo(txnId, personalTxnIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalTxnOut',) as PersonalTxnOut;
    
    }
    return null;
  }
}
