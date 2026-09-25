//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class SyncApi {
  SyncApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Sync
  ///
  /// Changes after your cursors, for every stream you can see, in one call.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [SyncIn] syncIn (required):
  Future<Response> callSyncWithHttpInfo(SyncIn syncIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/sync';

    // ignore: prefer_final_locals
    Object? postBody = syncIn;

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

  /// Sync
  ///
  /// Changes after your cursors, for every stream you can see, in one call.
  ///
  /// Parameters:
  ///
  /// * [SyncIn] syncIn (required):
  Future<SyncOut?> callSync(SyncIn syncIn,) async {
    final response = await callSyncWithHttpInfo(syncIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SyncOut',) as SyncOut;
    
    }
    return null;
  }

  /// Snapshot
  ///
  /// The current state of one stream and the seq it is at. Replace your copy with it.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] stream (required):
  Future<Response> snapshotWithHttpInfo(String stream,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/sync/snapshot/{stream}'
      .replaceAll('{stream}', stream);

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

  /// Snapshot
  ///
  /// The current state of one stream and the seq it is at. Replace your copy with it.
  ///
  /// Parameters:
  ///
  /// * [String] stream (required):
  Future<SyncSnapshotOut?> snapshot(String stream,) async {
    final response = await snapshotWithHttpInfo(stream,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SyncSnapshotOut',) as SyncSnapshotOut;
    
    }
    return null;
  }
}
