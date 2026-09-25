//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class CategoriesApi {
  CategoriesApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Create Category
  ///
  /// Add your own category. Only you see it.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CategoryIn] categoryIn (required):
  Future<Response> createCategoryWithHttpInfo(CategoryIn categoryIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/categories';

    // ignore: prefer_final_locals
    Object? postBody = categoryIn;

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

  /// Create Category
  ///
  /// Add your own category. Only you see it.
  ///
  /// Parameters:
  ///
  /// * [CategoryIn] categoryIn (required):
  Future<CategoryOut?> createCategory(CategoryIn categoryIn,) async {
    final response = await createCategoryWithHttpInfo(categoryIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'CategoryOut',) as CategoryOut;
    
    }
    return null;
  }

  /// Delete Category
  ///
  /// Delete one of your own categories, if nothing uses it.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] categoryId (required):
  Future<Response> deleteCategoryWithHttpInfo(String categoryId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/categories/{category_id}'
      .replaceAll('{category_id}', categoryId);

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

  /// Delete Category
  ///
  /// Delete one of your own categories, if nothing uses it.
  ///
  /// Parameters:
  ///
  /// * [String] categoryId (required):
  Future<void> deleteCategory(String categoryId,) async {
    final response = await deleteCategoryWithHttpInfo(categoryId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// List Categories
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] scope:
  Future<Response> listCategoriesWithHttpInfo({ String? scope, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/categories';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (scope != null) {
      queryParams.addAll(_queryParams('', 'scope', scope));
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

  /// List Categories
  ///
  /// Parameters:
  ///
  /// * [String] scope:
  Future<List<CategoryOut>?> listCategories({ String? scope, }) async {
    final response = await listCategoriesWithHttpInfo( scope: scope, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<CategoryOut>') as List)
        .cast<CategoryOut>()
        .toList(growable: false);

    }
    return null;
  }
}
