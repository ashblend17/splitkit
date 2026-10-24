//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminApi {
  AdminApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Admin Dashboard
  ///
  /// Totals, the latest audit entries and system facts for the admin home.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> adminDashboardWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/dashboard';

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

  /// Admin Dashboard
  ///
  /// Totals, the latest audit entries and system facts for the admin home.
  Future<AdminDashboardOut?> adminDashboard() async {
    final response = await adminDashboardWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminDashboardOut',) as AdminDashboardOut;
    
    }
    return null;
  }

  /// End Admin Session
  ///
  /// Stop viewing as the user. Works with your admin token or with the view-as token itself; the view-as token stops working straight away.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] sessionId (required):
  Future<Response> endAdminSessionWithHttpInfo(String sessionId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/sessions/{session_id}/end'
      .replaceAll('{session_id}', sessionId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

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

  /// End Admin Session
  ///
  /// Stop viewing as the user. Works with your admin token or with the view-as token itself; the view-as token stops working straight away.
  ///
  /// Parameters:
  ///
  /// * [String] sessionId (required):
  Future<AdminSessionOut?> endAdminSession(String sessionId,) async {
    final response = await endAdminSessionWithHttpInfo(sessionId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminSessionOut',) as AdminSessionOut;
    
    }
    return null;
  }

  /// List Admin Sessions
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [bool] active:
  ///
  /// * [String] adminId:
  ///
  /// * [String] targetUserId:
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  Future<Response> listAdminSessionsWithHttpInfo({ bool? active, String? adminId, String? targetUserId, int? limit, int? offset, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/sessions';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (active != null) {
      queryParams.addAll(_queryParams('', 'active', active));
    }
    if (adminId != null) {
      queryParams.addAll(_queryParams('', 'admin_id', adminId));
    }
    if (targetUserId != null) {
      queryParams.addAll(_queryParams('', 'target_user_id', targetUserId));
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

  /// List Admin Sessions
  ///
  /// Parameters:
  ///
  /// * [bool] active:
  ///
  /// * [String] adminId:
  ///
  /// * [String] targetUserId:
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  Future<AdminSessionsPageOut?> listAdminSessions({ bool? active, String? adminId, String? targetUserId, int? limit, int? offset, }) async {
    final response = await listAdminSessionsWithHttpInfo( active: active, adminId: adminId, targetUserId: targetUserId, limit: limit, offset: offset, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminSessionsPageOut',) as AdminSessionsPageOut;
    
    }
    return null;
  }

  /// List Admin Users
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] q:
  ///   Name or email
  ///
  /// * [String] role:
  ///
  /// * [bool] includePlaceholders:
  ///   Also people without an account
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  Future<Response> listAdminUsersWithHttpInfo({ String? q, String? role, bool? includePlaceholders, int? limit, int? offset, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/users';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (q != null) {
      queryParams.addAll(_queryParams('', 'q', q));
    }
    if (role != null) {
      queryParams.addAll(_queryParams('', 'role', role));
    }
    if (includePlaceholders != null) {
      queryParams.addAll(_queryParams('', 'include_placeholders', includePlaceholders));
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

  /// List Admin Users
  ///
  /// Parameters:
  ///
  /// * [String] q:
  ///   Name or email
  ///
  /// * [String] role:
  ///
  /// * [bool] includePlaceholders:
  ///   Also people without an account
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  Future<AdminUsersPageOut?> listAdminUsers({ String? q, String? role, bool? includePlaceholders, int? limit, int? offset, }) async {
    final response = await listAdminUsersWithHttpInfo( q: q, role: role, includePlaceholders: includePlaceholders, limit: limit, offset: offset, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminUsersPageOut',) as AdminUsersPageOut;
    
    }
    return null;
  }

  /// List Audit Log
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] actorId:
  ///   Who really acted
  ///
  /// * [String] targetUserId:
  ///   Who it was done as: the impersonated user, or the actor
  ///
  /// * [List<String>] entity:
  ///   expense, settlement, group, user, admin_session, import_batch…
  ///
  /// * [bool] adminOnly:
  ///   Only things admins did as someone else
  ///
  /// * [DateTime] start:
  ///   UTC day, included
  ///
  /// * [DateTime] end:
  ///   UTC day, included
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  Future<Response> listAuditLogWithHttpInfo({ String? actorId, String? targetUserId, List<String>? entity, bool? adminOnly, DateTime? start, DateTime? end, int? limit, int? offset, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/audit';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (actorId != null) {
      queryParams.addAll(_queryParams('', 'actor_id', actorId));
    }
    if (targetUserId != null) {
      queryParams.addAll(_queryParams('', 'target_user_id', targetUserId));
    }
    if (entity != null) {
      queryParams.addAll(_queryParams('multi', 'entity', entity));
    }
    if (adminOnly != null) {
      queryParams.addAll(_queryParams('', 'admin_only', adminOnly));
    }
    if (start != null) {
      queryParams.addAll(_queryParams('', 'start', start));
    }
    if (end != null) {
      queryParams.addAll(_queryParams('', 'end', end));
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

  /// List Audit Log
  ///
  /// Parameters:
  ///
  /// * [String] actorId:
  ///   Who really acted
  ///
  /// * [String] targetUserId:
  ///   Who it was done as: the impersonated user, or the actor
  ///
  /// * [List<String>] entity:
  ///   expense, settlement, group, user, admin_session, import_batch…
  ///
  /// * [bool] adminOnly:
  ///   Only things admins did as someone else
  ///
  /// * [DateTime] start:
  ///   UTC day, included
  ///
  /// * [DateTime] end:
  ///   UTC day, included
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  Future<AuditPageOut?> listAuditLog({ String? actorId, String? targetUserId, List<String>? entity, bool? adminOnly, DateTime? start, DateTime? end, int? limit, int? offset, }) async {
    final response = await listAuditLogWithHttpInfo( actorId: actorId, targetUserId: targetUserId, entity: entity, adminOnly: adminOnly, start: start, end: end, limit: limit, offset: offset, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AuditPageOut',) as AuditPageOut;
    
    }
    return null;
  }

  /// Start Admin Session
  ///
  /// View the app as a user. Read-only unless `mode` is `edit`. Returns a token for that user; ends any other session you have open.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AdminSessionIn] adminSessionIn (required):
  Future<Response> startAdminSessionWithHttpInfo(AdminSessionIn adminSessionIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/sessions';

    // ignore: prefer_final_locals
    Object? postBody = adminSessionIn;

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

  /// Start Admin Session
  ///
  /// View the app as a user. Read-only unless `mode` is `edit`. Returns a token for that user; ends any other session you have open.
  ///
  /// Parameters:
  ///
  /// * [AdminSessionIn] adminSessionIn (required):
  Future<AdminSessionStartOut?> startAdminSession(AdminSessionIn adminSessionIn,) async {
    final response = await startAdminSessionWithHttpInfo(adminSessionIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminSessionStartOut',) as AdminSessionStartOut;
    
    }
    return null;
  }

  /// Update Admin Session
  ///
  /// Switch a session you started between read-only and edit. Takes effect at once, on the same token.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] sessionId (required):
  ///
  /// * [AdminSessionUpdate] adminSessionUpdate (required):
  Future<Response> updateAdminSessionWithHttpInfo(String sessionId, AdminSessionUpdate adminSessionUpdate,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/admin/sessions/{session_id}'
      .replaceAll('{session_id}', sessionId);

    // ignore: prefer_final_locals
    Object? postBody = adminSessionUpdate;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PATCH',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Update Admin Session
  ///
  /// Switch a session you started between read-only and edit. Takes effect at once, on the same token.
  ///
  /// Parameters:
  ///
  /// * [String] sessionId (required):
  ///
  /// * [AdminSessionUpdate] adminSessionUpdate (required):
  Future<AdminSessionOut?> updateAdminSession(String sessionId, AdminSessionUpdate adminSessionUpdate,) async {
    final response = await updateAdminSessionWithHttpInfo(sessionId, adminSessionUpdate,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminSessionOut',) as AdminSessionOut;
    
    }
    return null;
  }
}
