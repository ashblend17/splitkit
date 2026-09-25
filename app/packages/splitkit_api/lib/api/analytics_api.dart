//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AnalyticsApi {
  AnalyticsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Get Layout
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] scope (required):
  Future<Response> getLayoutWithHttpInfo(String scope,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/analytics/layout/{scope}'
      .replaceAll('{scope}', scope);

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

  /// Get Layout
  ///
  /// Parameters:
  ///
  /// * [String] scope (required):
  Future<LayoutOut?> getLayout(String scope,) async {
    final response = await getLayoutWithHttpInfo(scope,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'LayoutOut',) as LayoutOut;
    
    }
    return null;
  }

  /// Group Dashboard
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [DateTime] on_:
  Future<Response> groupDashboardWithHttpInfo(String groupId, { DateTime? on_, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/analytics/groups/{group_id}'
      .replaceAll('{group_id}', groupId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (on_ != null) {
      queryParams.addAll(_queryParams('', 'on', on_));
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

  /// Group Dashboard
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [DateTime] on_:
  Future<DashboardOut?> groupDashboard(String groupId, { DateTime? on_, }) async {
    final response = await groupDashboardWithHttpInfo(groupId,  on_: on_, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'DashboardOut',) as DashboardOut;
    
    }
    return null;
  }

  /// Personal Dashboard
  ///
  /// One card per row of your analytics layout. `on` is today in your time zone.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] period:
  ///
  /// * [DateTime] on_:
  Future<Response> personalDashboardWithHttpInfo({ String? period, DateTime? on_, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/analytics/personal';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (period != null) {
      queryParams.addAll(_queryParams('', 'period', period));
    }
    if (on_ != null) {
      queryParams.addAll(_queryParams('', 'on', on_));
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

  /// Personal Dashboard
  ///
  /// One card per row of your analytics layout. `on` is today in your time zone.
  ///
  /// Parameters:
  ///
  /// * [String] period:
  ///
  /// * [DateTime] on_:
  Future<DashboardOut?> personalDashboard({ String? period, DateTime? on_, }) async {
    final response = await personalDashboardWithHttpInfo( period: period, on_: on_, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'DashboardOut',) as DashboardOut;
    
    }
    return null;
  }

  /// Reset Layout
  ///
  /// Go back to the default layout.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] scope (required):
  Future<Response> resetLayoutWithHttpInfo(String scope,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/analytics/layout/{scope}'
      .replaceAll('{scope}', scope);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

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

  /// Reset Layout
  ///
  /// Go back to the default layout.
  ///
  /// Parameters:
  ///
  /// * [String] scope (required):
  Future<LayoutOut?> resetLayout(String scope,) async {
    final response = await resetLayoutWithHttpInfo(scope,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'LayoutOut',) as LayoutOut;
    
    }
    return null;
  }

  /// Save Layout
  ///
  /// Replace your layout for this scope (order = list order).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] scope (required):
  ///
  /// * [LayoutIn] layoutIn (required):
  Future<Response> saveLayoutWithHttpInfo(String scope, LayoutIn layoutIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/analytics/layout/{scope}'
      .replaceAll('{scope}', scope);

    // ignore: prefer_final_locals
    Object? postBody = layoutIn;

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

  /// Save Layout
  ///
  /// Replace your layout for this scope (order = list order).
  ///
  /// Parameters:
  ///
  /// * [String] scope (required):
  ///
  /// * [LayoutIn] layoutIn (required):
  Future<LayoutOut?> saveLayout(String scope, LayoutIn layoutIn,) async {
    final response = await saveLayoutWithHttpInfo(scope, layoutIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'LayoutOut',) as LayoutOut;
    
    }
    return null;
  }
}
