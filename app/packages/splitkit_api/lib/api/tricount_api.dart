//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class TricountApi {
  TricountApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Get Tricount Link
  ///
  /// Whether the group is kept in sync with a tricount, how the last pass went, and the conflicts waiting for someone to pick a side.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<Response> getTricountLinkWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}/tricount'
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

  /// Get Tricount Link
  ///
  /// Whether the group is kept in sync with a tricount, how the last pass went, and the conflicts waiting for someone to pick a side.
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<TricountStatusOut?> getTricountLink(String groupId,) async {
    final response = await getTricountLinkWithHttpInfo(groupId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TricountStatusOut',) as TricountStatusOut;
    
    }
    return null;
  }

  /// Link Tricount
  ///
  /// Keep this group in sync with a tricount: an existing one (`link`) or a new one made from the group (`create`). The first pass runs right after; the status says \"syncing\" until it's done.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [TricountLinkIn] tricountLinkIn (required):
  Future<Response> linkTricountWithHttpInfo(String groupId, TricountLinkIn tricountLinkIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}/tricount'
      .replaceAll('{group_id}', groupId);

    // ignore: prefer_final_locals
    Object? postBody = tricountLinkIn;

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

  /// Link Tricount
  ///
  /// Keep this group in sync with a tricount: an existing one (`link`) or a new one made from the group (`create`). The first pass runs right after; the status says \"syncing\" until it's done.
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [TricountLinkIn] tricountLinkIn (required):
  Future<TricountStatusOut?> linkTricount(String groupId, TricountLinkIn tricountLinkIn,) async {
    final response = await linkTricountWithHttpInfo(groupId, tricountLinkIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TricountStatusOut',) as TricountStatusOut;
    
    }
    return null;
  }

  /// List Tricount Conflicts
  ///
  /// Entries changed in both apps since they last agreed, in your groups.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> listTricountConflictsWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/tricount/conflicts';

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

  /// List Tricount Conflicts
  ///
  /// Entries changed in both apps since they last agreed, in your groups.
  Future<List<TricountConflictOut>?> listTricountConflicts() async {
    final response = await listTricountConflictsWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<TricountConflictOut>') as List)
        .cast<TricountConflictOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// Preview Tricount Link
  ///
  /// Read a tricount by its share link (without joining it) and suggest who its people are in this group. Changes nothing.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [TricountLinkPreviewIn] tricountLinkPreviewIn (required):
  Future<Response> previewTricountLinkWithHttpInfo(String groupId, TricountLinkPreviewIn tricountLinkPreviewIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}/tricount/preview'
      .replaceAll('{group_id}', groupId);

    // ignore: prefer_final_locals
    Object? postBody = tricountLinkPreviewIn;

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

  /// Preview Tricount Link
  ///
  /// Read a tricount by its share link (without joining it) and suggest who its people are in this group. Changes nothing.
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [TricountLinkPreviewIn] tricountLinkPreviewIn (required):
  Future<TricountLinkPreviewOut?> previewTricountLink(String groupId, TricountLinkPreviewIn tricountLinkPreviewIn,) async {
    final response = await previewTricountLinkWithHttpInfo(groupId, tricountLinkPreviewIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TricountLinkPreviewOut',) as TricountLinkPreviewOut;
    
    }
    return null;
  }

  /// Resolve Tricount Conflict
  ///
  /// Keep Splitkit's or Tricount's version. The other app is updated before this returns (unless Tricount can't be reached; then the worker retries).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] conflictId (required):
  ///
  /// * [ResolveConflictIn] resolveConflictIn (required):
  Future<Response> resolveTricountConflictWithHttpInfo(String conflictId, ResolveConflictIn resolveConflictIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/tricount/conflicts/{conflict_id}/resolve'
      .replaceAll('{conflict_id}', conflictId);

    // ignore: prefer_final_locals
    Object? postBody = resolveConflictIn;

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

  /// Resolve Tricount Conflict
  ///
  /// Keep Splitkit's or Tricount's version. The other app is updated before this returns (unless Tricount can't be reached; then the worker retries).
  ///
  /// Parameters:
  ///
  /// * [String] conflictId (required):
  ///
  /// * [ResolveConflictIn] resolveConflictIn (required):
  Future<TricountStatusOut?> resolveTricountConflict(String conflictId, ResolveConflictIn resolveConflictIn,) async {
    final response = await resolveTricountConflictWithHttpInfo(conflictId, resolveConflictIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TricountStatusOut',) as TricountStatusOut;
    
    }
    return null;
  }

  /// Sync Tricount
  ///
  /// Sync now instead of waiting for the next pass.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<Response> syncTricountWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}/tricount/sync'
      .replaceAll('{group_id}', groupId);

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

  /// Sync Tricount
  ///
  /// Sync now instead of waiting for the next pass.
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<TricountStatusOut?> syncTricount(String groupId,) async {
    final response = await syncTricountWithHttpInfo(groupId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TricountStatusOut',) as TricountStatusOut;
    
    }
    return null;
  }

  /// Unlink Tricount
  ///
  /// Stop syncing. Nothing is deleted on either side.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<Response> unlinkTricountWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}/tricount'
      .replaceAll('{group_id}', groupId);

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

  /// Unlink Tricount
  ///
  /// Stop syncing. Nothing is deleted on either side.
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<void> unlinkTricount(String groupId,) async {
    final response = await unlinkTricountWithHttpInfo(groupId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }
}
