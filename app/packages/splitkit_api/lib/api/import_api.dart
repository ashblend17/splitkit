//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class ImportApi {
  ImportApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Commit Tricount
  ///
  /// Import the file in one go, as one batch that can be undone.  `options` is JSON: `{\"group_id\": …}` or `{\"new_group\": {\"name\", \"currency\", \"icon\"}}`, plus `people` (`[{\"name\", \"user_id\"}]`; no `user_id` makes a placeholder member) and `categories` (`{\"Tricount category\": \"key\"}`; anything unmapped becomes Other).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] file (required):
  ///   The same file that was previewed
  ///
  /// * [String] options (required):
  ///   ImportCommitIn as JSON
  Future<Response> commitTricountWithHttpInfo(String file, String options,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/import/tricount/commit';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['multipart/form-data'];

    bool hasFields = false;
    final mp = MultipartRequest('POST', Uri.parse(path));
    if (file != null) {
      hasFields = true;
      mp.fields[r'file'] = parameterToString(file);
    }
    if (options != null) {
      hasFields = true;
      mp.fields[r'options'] = parameterToString(options);
    }
    if (hasFields) {
      postBody = mp;
    }

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

  /// Commit Tricount
  ///
  /// Import the file in one go, as one batch that can be undone.  `options` is JSON: `{\"group_id\": …}` or `{\"new_group\": {\"name\", \"currency\", \"icon\"}}`, plus `people` (`[{\"name\", \"user_id\"}]`; no `user_id` makes a placeholder member) and `categories` (`{\"Tricount category\": \"key\"}`; anything unmapped becomes Other).
  ///
  /// Parameters:
  ///
  /// * [String] file (required):
  ///   The same file that was previewed
  ///
  /// * [String] options (required):
  ///   ImportCommitIn as JSON
  Future<ImportBatchOut?> commitTricount(String file, String options,) async {
    final response = await commitTricountWithHttpInfo(file, options,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ImportBatchOut',) as ImportBatchOut;
    
    }
    return null;
  }

  /// Get Import Batch
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] batchId (required):
  Future<Response> getImportBatchWithHttpInfo(String batchId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/import/batches/{batch_id}'
      .replaceAll('{batch_id}', batchId);

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

  /// Get Import Batch
  ///
  /// Parameters:
  ///
  /// * [String] batchId (required):
  Future<ImportBatchOut?> getImportBatch(String batchId,) async {
    final response = await getImportBatchWithHttpInfo(batchId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ImportBatchOut',) as ImportBatchOut;
    
    }
    return null;
  }

  /// List Import Batches
  ///
  /// Your imports, newest first.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> listImportBatchesWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/import/batches';

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

  /// List Import Batches
  ///
  /// Your imports, newest first.
  Future<List<ImportBatchOut>?> listImportBatches() async {
    final response = await listImportBatchesWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<ImportBatchOut>') as List)
        .cast<ImportBatchOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// Preview Tricount
  ///
  /// Read a Tricount export and suggest how to map it. Saves nothing.  `group_id`: import into this group (people are matched against its members). Otherwise a new group is assumed; `currency` sets its currency (default: the file's).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] file (required):
  ///   Tricount export, CSV or XLSX
  ///
  /// * [String] groupId:
  ///
  /// * [String] currency:
  Future<Response> previewTricountWithHttpInfo(String file, { String? groupId, String? currency, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/import/tricount/preview';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['multipart/form-data'];

    bool hasFields = false;
    final mp = MultipartRequest('POST', Uri.parse(path));
    if (file != null) {
      hasFields = true;
      mp.fields[r'file'] = parameterToString(file);
    }
    if (groupId != null) {
      hasFields = true;
      mp.fields[r'group_id'] = parameterToString(groupId);
    }
    if (currency != null) {
      hasFields = true;
      mp.fields[r'currency'] = parameterToString(currency);
    }
    if (hasFields) {
      postBody = mp;
    }

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

  /// Preview Tricount
  ///
  /// Read a Tricount export and suggest how to map it. Saves nothing.  `group_id`: import into this group (people are matched against its members). Otherwise a new group is assumed; `currency` sets its currency (default: the file's).
  ///
  /// Parameters:
  ///
  /// * [String] file (required):
  ///   Tricount export, CSV or XLSX
  ///
  /// * [String] groupId:
  ///
  /// * [String] currency:
  Future<ImportPreviewOut?> previewTricount(String file, { String? groupId, String? currency, }) async {
    final response = await previewTricountWithHttpInfo(file,  groupId: groupId, currency: currency, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ImportPreviewOut',) as ImportPreviewOut;
    
    }
    return null;
  }

  /// Undo Import Batch
  ///
  /// Remove everything this import created (soft deletes, so items can be restored one by one). Calling it again changes nothing.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] batchId (required):
  Future<Response> undoImportBatchWithHttpInfo(String batchId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/import/batches/{batch_id}/undo'
      .replaceAll('{batch_id}', batchId);

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

  /// Undo Import Batch
  ///
  /// Remove everything this import created (soft deletes, so items can be restored one by one). Calling it again changes nothing.
  ///
  /// Parameters:
  ///
  /// * [String] batchId (required):
  Future<ImportBatchOut?> undoImportBatch(String batchId,) async {
    final response = await undoImportBatchWithHttpInfo(batchId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ImportBatchOut',) as ImportBatchOut;
    
    }
    return null;
  }
}
