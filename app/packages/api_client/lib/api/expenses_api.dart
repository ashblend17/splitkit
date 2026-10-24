//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class ExpensesApi {
  ExpensesApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Create Expense
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [ExpenseIn] expenseIn (required):
  Future<Response> createExpenseWithHttpInfo(String groupId, ExpenseIn expenseIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}/expenses'
      .replaceAll('{group_id}', groupId);

    // ignore: prefer_final_locals
    Object? postBody = expenseIn;

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

  /// Create Expense
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [ExpenseIn] expenseIn (required):
  Future<ExpenseOut?> createExpense(String groupId, ExpenseIn expenseIn,) async {
    final response = await createExpenseWithHttpInfo(groupId, expenseIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ExpenseOut',) as ExpenseOut;
    
    }
    return null;
  }

  /// Delete Expense
  ///
  /// Soft delete. The expense stops counting towards balances and can be restored.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] expenseId (required):
  ///
  /// * [int] version:
  Future<Response> deleteExpenseWithHttpInfo(String expenseId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/expenses/{expense_id}'
      .replaceAll('{expense_id}', expenseId);

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

  /// Delete Expense
  ///
  /// Soft delete. The expense stops counting towards balances and can be restored.
  ///
  /// Parameters:
  ///
  /// * [String] expenseId (required):
  ///
  /// * [int] version:
  Future<ExpenseOut?> deleteExpense(String expenseId, { int? version, }) async {
    final response = await deleteExpenseWithHttpInfo(expenseId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ExpenseOut',) as ExpenseOut;
    
    }
    return null;
  }

  /// Expense History
  ///
  /// Who added and changed this expense, oldest first (\"Edited by Rahul · ₹1,650 → ₹1,800\").
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] expenseId (required):
  Future<Response> expenseHistoryWithHttpInfo(String expenseId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/expenses/{expense_id}/history'
      .replaceAll('{expense_id}', expenseId);

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

  /// Expense History
  ///
  /// Who added and changed this expense, oldest first (\"Edited by Rahul · ₹1,650 → ₹1,800\").
  ///
  /// Parameters:
  ///
  /// * [String] expenseId (required):
  Future<List<HistoryEntry>?> expenseHistory(String expenseId,) async {
    final response = await expenseHistoryWithHttpInfo(expenseId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<HistoryEntry>') as List)
        .cast<HistoryEntry>()
        .toList(growable: false);

    }
    return null;
  }

  /// Get Expense
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] expenseId (required):
  Future<Response> getExpenseWithHttpInfo(String expenseId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/expenses/{expense_id}'
      .replaceAll('{expense_id}', expenseId);

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

  /// Get Expense
  ///
  /// Parameters:
  ///
  /// * [String] expenseId (required):
  Future<ExpenseOut?> getExpense(String expenseId,) async {
    final response = await getExpenseWithHttpInfo(expenseId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ExpenseOut',) as ExpenseOut;
    
    }
    return null;
  }

  /// Restore Expense
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] expenseId (required):
  ///
  /// * [int] version:
  Future<Response> restoreExpenseWithHttpInfo(String expenseId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/expenses/{expense_id}/restore'
      .replaceAll('{expense_id}', expenseId);

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

  /// Restore Expense
  ///
  /// Parameters:
  ///
  /// * [String] expenseId (required):
  ///
  /// * [int] version:
  Future<ExpenseOut?> restoreExpense(String expenseId, { int? version, }) async {
    final response = await restoreExpenseWithHttpInfo(expenseId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ExpenseOut',) as ExpenseOut;
    
    }
    return null;
  }

  /// Update Expense
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] expenseId (required):
  ///
  /// * [ExpenseIn] expenseIn (required):
  Future<Response> updateExpenseWithHttpInfo(String expenseId, ExpenseIn expenseIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/expenses/{expense_id}'
      .replaceAll('{expense_id}', expenseId);

    // ignore: prefer_final_locals
    Object? postBody = expenseIn;

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

  /// Update Expense
  ///
  /// Parameters:
  ///
  /// * [String] expenseId (required):
  ///
  /// * [ExpenseIn] expenseIn (required):
  Future<ExpenseOut?> updateExpense(String expenseId, ExpenseIn expenseIn,) async {
    final response = await updateExpenseWithHttpInfo(expenseId, expenseIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ExpenseOut',) as ExpenseOut;
    
    }
    return null;
  }
}
