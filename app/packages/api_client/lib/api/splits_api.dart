//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class SplitsApi {
  SplitsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// List Methods
  ///
  /// The registered split methods, in the order the selector shows them.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> listMethodsWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/splits/methods';

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

  /// List Methods
  ///
  /// The registered split methods, in the order the selector shows them.
  Future<List<SplitMethodOut>?> listMethods() async {
    final response = await listMethodsWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<SplitMethodOut>') as List)
        .cast<SplitMethodOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// Preview
  ///
  /// Validate and allocate without saving. Invalid splits return 200 with ok=false.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [SplitPreviewIn] splitPreviewIn (required):
  Future<Response> previewWithHttpInfo(SplitPreviewIn splitPreviewIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/splits/preview';

    // ignore: prefer_final_locals
    Object? postBody = splitPreviewIn;

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

  /// Preview
  ///
  /// Validate and allocate without saving. Invalid splits return 200 with ok=false.
  ///
  /// Parameters:
  ///
  /// * [SplitPreviewIn] splitPreviewIn (required):
  Future<SplitPreviewOut?> preview(SplitPreviewIn splitPreviewIn,) async {
    final response = await previewWithHttpInfo(splitPreviewIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SplitPreviewOut',) as SplitPreviewOut;
    
    }
    return null;
  }
}
