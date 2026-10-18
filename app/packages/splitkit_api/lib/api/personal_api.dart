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

  /// Apply Personal Batch
  ///
  /// Up to 100 account and entry creates, updates and entry deletes, applied in order, all or none. A transfer's two legs go in one batch. A repeated create gives back what it already made; a stale update gets a 409 and nothing is applied. A refusal says which `item`.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PersonalMixedBatchIn] personalMixedBatchIn (required):
  Future<Response> applyPersonalBatchWithHttpInfo(PersonalMixedBatchIn personalMixedBatchIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/batch';

    // ignore: prefer_final_locals
    Object? postBody = personalMixedBatchIn;

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

  /// Apply Personal Batch
  ///
  /// Up to 100 account and entry creates, updates and entry deletes, applied in order, all or none. A transfer's two legs go in one batch. A repeated create gives back what it already made; a stale update gets a 409 and nothing is applied. A refusal says which `item`.
  ///
  /// Parameters:
  ///
  /// * [PersonalMixedBatchIn] personalMixedBatchIn (required):
  Future<PersonalMixedBatchOut?> applyPersonalBatch(PersonalMixedBatchIn personalMixedBatchIn,) async {
    final response = await applyPersonalBatchWithHttpInfo(personalMixedBatchIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalMixedBatchOut',) as PersonalMixedBatchOut;
    
    }
    return null;
  }

  /// Create Allocation Plan
  ///
  /// Usually sent with its income in one `POST /personal/batch`. One plan per income and rule: the same id gives back the plan, another id gets 409 `plan_exists`.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PersonalAllocationPlanIn] personalAllocationPlanIn (required):
  Future<Response> createAllocationPlanWithHttpInfo(PersonalAllocationPlanIn personalAllocationPlanIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/allocation-plans';

    // ignore: prefer_final_locals
    Object? postBody = personalAllocationPlanIn;

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

  /// Create Allocation Plan
  ///
  /// Usually sent with its income in one `POST /personal/batch`. One plan per income and rule: the same id gives back the plan, another id gets 409 `plan_exists`.
  ///
  /// Parameters:
  ///
  /// * [PersonalAllocationPlanIn] personalAllocationPlanIn (required):
  Future<PersonalAllocationPlanOut?> createAllocationPlan(PersonalAllocationPlanIn personalAllocationPlanIn,) async {
    final response = await createAllocationPlanWithHttpInfo(personalAllocationPlanIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAllocationPlanOut',) as PersonalAllocationPlanOut;
    
    }
    return null;
  }

  /// Create Allocation Rule
  ///
  /// To a goal that counts contributions or an open account, in your currency. A repeated id gives back the rule it already made.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PersonalAllocationRuleIn] personalAllocationRuleIn (required):
  Future<Response> createAllocationRuleWithHttpInfo(PersonalAllocationRuleIn personalAllocationRuleIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/allocation-rules';

    // ignore: prefer_final_locals
    Object? postBody = personalAllocationRuleIn;

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

  /// Create Allocation Rule
  ///
  /// To a goal that counts contributions or an open account, in your currency. A repeated id gives back the rule it already made.
  ///
  /// Parameters:
  ///
  /// * [PersonalAllocationRuleIn] personalAllocationRuleIn (required):
  Future<PersonalAllocationRuleOut?> createAllocationRule(PersonalAllocationRuleIn personalAllocationRuleIn,) async {
    final response = await createAllocationRuleWithHttpInfo(personalAllocationRuleIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAllocationRuleOut',) as PersonalAllocationRuleOut;
    
    }
    return null;
  }

  /// Create Goal Contribution
  ///
  /// To a goal that counts contributions. With `transaction_id`, the entry that moved the money: it counts towards one goal at most, and not if it moves an account a goal follows by balance (422 `counted_by_balance`).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PersonalGoalContributionIn] personalGoalContributionIn (required):
  Future<Response> createGoalContributionWithHttpInfo(PersonalGoalContributionIn personalGoalContributionIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/goal-contributions';

    // ignore: prefer_final_locals
    Object? postBody = personalGoalContributionIn;

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

  /// Create Goal Contribution
  ///
  /// To a goal that counts contributions. With `transaction_id`, the entry that moved the money: it counts towards one goal at most, and not if it moves an account a goal follows by balance (422 `counted_by_balance`).
  ///
  /// Parameters:
  ///
  /// * [PersonalGoalContributionIn] personalGoalContributionIn (required):
  Future<PersonalGoalContributionOut?> createGoalContribution(PersonalGoalContributionIn personalGoalContributionIn,) async {
    final response = await createGoalContributionWithHttpInfo(personalGoalContributionIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalGoalContributionOut',) as PersonalGoalContributionOut;
    
    }
    return null;
  }

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

  /// Create Personal Account
  ///
  /// In your currency. A repeated id gives back the account it already made. With an `sms_label`, your entries with that label and no account move into it.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PersonalAccountIn] personalAccountIn (required):
  Future<Response> createPersonalAccountWithHttpInfo(PersonalAccountIn personalAccountIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/accounts';

    // ignore: prefer_final_locals
    Object? postBody = personalAccountIn;

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

  /// Create Personal Account
  ///
  /// In your currency. A repeated id gives back the account it already made. With an `sms_label`, your entries with that label and no account move into it.
  ///
  /// Parameters:
  ///
  /// * [PersonalAccountIn] personalAccountIn (required):
  Future<PersonalAccountOut?> createPersonalAccount(PersonalAccountIn personalAccountIn,) async {
    final response = await createPersonalAccountWithHttpInfo(personalAccountIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAccountOut',) as PersonalAccountOut;
    
    }
    return null;
  }

  /// Create Personal Batch
  ///
  /// Up to 100 entries in one request, all or none. A repeated id (a retry, a bank SMS read again) gives back the entry it already made, deleted or not.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PersonalBatchIn] personalBatchIn (required):
  Future<Response> createPersonalBatchWithHttpInfo(PersonalBatchIn personalBatchIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/transactions/batch';

    // ignore: prefer_final_locals
    Object? postBody = personalBatchIn;

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

  /// Create Personal Batch
  ///
  /// Up to 100 entries in one request, all or none. A repeated id (a retry, a bank SMS read again) gives back the entry it already made, deleted or not.
  ///
  /// Parameters:
  ///
  /// * [PersonalBatchIn] personalBatchIn (required):
  Future<PersonalBatchOut?> createPersonalBatch(PersonalBatchIn personalBatchIn,) async {
    final response = await createPersonalBatchWithHttpInfo(personalBatchIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalBatchOut',) as PersonalBatchOut;
    
    }
    return null;
  }

  /// Create Personal Goal
  ///
  /// In your currency. A repeated id gives back the goal it already made.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PersonalGoalIn] personalGoalIn (required):
  Future<Response> createPersonalGoalWithHttpInfo(PersonalGoalIn personalGoalIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/goals';

    // ignore: prefer_final_locals
    Object? postBody = personalGoalIn;

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

  /// Create Personal Goal
  ///
  /// In your currency. A repeated id gives back the goal it already made.
  ///
  /// Parameters:
  ///
  /// * [PersonalGoalIn] personalGoalIn (required):
  Future<PersonalGoalOut?> createPersonalGoal(PersonalGoalIn personalGoalIn,) async {
    final response = await createPersonalGoalWithHttpInfo(personalGoalIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalGoalOut',) as PersonalGoalOut;
    
    }
    return null;
  }

  /// Create Personal Holding
  ///
  /// In an open investment account of yours. A repeated id gives back the holding it made.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PersonalHoldingIn] personalHoldingIn (required):
  Future<Response> createPersonalHoldingWithHttpInfo(PersonalHoldingIn personalHoldingIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/holdings';

    // ignore: prefer_final_locals
    Object? postBody = personalHoldingIn;

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

  /// Create Personal Holding
  ///
  /// In an open investment account of yours. A repeated id gives back the holding it made.
  ///
  /// Parameters:
  ///
  /// * [PersonalHoldingIn] personalHoldingIn (required):
  Future<PersonalHoldingOut?> createPersonalHolding(PersonalHoldingIn personalHoldingIn,) async {
    final response = await createPersonalHoldingWithHttpInfo(personalHoldingIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalHoldingOut',) as PersonalHoldingOut;
    
    }
    return null;
  }

  /// Create Reminder Schedule
  ///
  /// A monthly reminder for a goal or a holding. It never records an entry.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PersonalReminderScheduleIn] personalReminderScheduleIn (required):
  Future<Response> createReminderScheduleWithHttpInfo(PersonalReminderScheduleIn personalReminderScheduleIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/reminder-schedules';

    // ignore: prefer_final_locals
    Object? postBody = personalReminderScheduleIn;

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

  /// Create Reminder Schedule
  ///
  /// A monthly reminder for a goal or a holding. It never records an entry.
  ///
  /// Parameters:
  ///
  /// * [PersonalReminderScheduleIn] personalReminderScheduleIn (required):
  Future<PersonalReminderScheduleOut?> createReminderSchedule(PersonalReminderScheduleIn personalReminderScheduleIn,) async {
    final response = await createReminderScheduleWithHttpInfo(personalReminderScheduleIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalReminderScheduleOut',) as PersonalReminderScheduleOut;
    
    }
    return null;
  }

  /// Delete Allocation Plan
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] planId (required):
  ///
  /// * [int] version:
  Future<Response> deleteAllocationPlanWithHttpInfo(String planId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/allocation-plans/{plan_id}'
      .replaceAll('{plan_id}', planId);

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

  /// Delete Allocation Plan
  ///
  /// Parameters:
  ///
  /// * [String] planId (required):
  ///
  /// * [int] version:
  Future<PersonalAllocationPlanOut?> deleteAllocationPlan(String planId, { int? version, }) async {
    final response = await deleteAllocationPlanWithHttpInfo(planId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAllocationPlanOut',) as PersonalAllocationPlanOut;
    
    }
    return null;
  }

  /// Delete Allocation Rule
  ///
  /// Its plans stay, but it makes no new ones.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] ruleId (required):
  ///
  /// * [int] version:
  Future<Response> deleteAllocationRuleWithHttpInfo(String ruleId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/allocation-rules/{rule_id}'
      .replaceAll('{rule_id}', ruleId);

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

  /// Delete Allocation Rule
  ///
  /// Its plans stay, but it makes no new ones.
  ///
  /// Parameters:
  ///
  /// * [String] ruleId (required):
  ///
  /// * [int] version:
  Future<PersonalAllocationRuleOut?> deleteAllocationRule(String ruleId, { int? version, }) async {
    final response = await deleteAllocationRuleWithHttpInfo(ruleId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAllocationRuleOut',) as PersonalAllocationRuleOut;
    
    }
    return null;
  }

  /// Delete Goal Contribution
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contributionId (required):
  ///
  /// * [int] version:
  Future<Response> deleteGoalContributionWithHttpInfo(String contributionId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/goal-contributions/{contribution_id}'
      .replaceAll('{contribution_id}', contributionId);

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

  /// Delete Goal Contribution
  ///
  /// Parameters:
  ///
  /// * [String] contributionId (required):
  ///
  /// * [int] version:
  Future<PersonalGoalContributionOut?> deleteGoalContribution(String contributionId, { int? version, }) async {
    final response = await deleteGoalContributionWithHttpInfo(contributionId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalGoalContributionOut',) as PersonalGoalContributionOut;
    
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

  /// Delete Personal Account
  ///
  /// Only while no entry is in it (409 `account_in_use`): close it instead.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  ///
  /// * [int] version:
  Future<Response> deletePersonalAccountWithHttpInfo(String accountId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/accounts/{account_id}'
      .replaceAll('{account_id}', accountId);

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

  /// Delete Personal Account
  ///
  /// Only while no entry is in it (409 `account_in_use`): close it instead.
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  ///
  /// * [int] version:
  Future<PersonalAccountOut?> deletePersonalAccount(String accountId, { int? version, }) async {
    final response = await deletePersonalAccountWithHttpInfo(accountId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAccountOut',) as PersonalAccountOut;
    
    }
    return null;
  }

  /// Delete Personal Goal
  ///
  /// Its contributions go with it, and come back when it's restored.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] goalId (required):
  ///
  /// * [int] version:
  Future<Response> deletePersonalGoalWithHttpInfo(String goalId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/goals/{goal_id}'
      .replaceAll('{goal_id}', goalId);

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

  /// Delete Personal Goal
  ///
  /// Its contributions go with it, and come back when it's restored.
  ///
  /// Parameters:
  ///
  /// * [String] goalId (required):
  ///
  /// * [int] version:
  Future<PersonalGoalOut?> deletePersonalGoal(String goalId, { int? version, }) async {
    final response = await deletePersonalGoalWithHttpInfo(goalId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalGoalOut',) as PersonalGoalOut;
    
    }
    return null;
  }

  /// Delete Personal Holding
  ///
  /// Refused while a live entry names it (409 `holding_in_use`). Its SIP reminders go with it, and come back when it's restored.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] holdingId (required):
  ///
  /// * [int] version:
  Future<Response> deletePersonalHoldingWithHttpInfo(String holdingId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/holdings/{holding_id}'
      .replaceAll('{holding_id}', holdingId);

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

  /// Delete Personal Holding
  ///
  /// Refused while a live entry names it (409 `holding_in_use`). Its SIP reminders go with it, and come back when it's restored.
  ///
  /// Parameters:
  ///
  /// * [String] holdingId (required):
  ///
  /// * [int] version:
  Future<PersonalHoldingOut?> deletePersonalHolding(String holdingId, { int? version, }) async {
    final response = await deletePersonalHoldingWithHttpInfo(holdingId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalHoldingOut',) as PersonalHoldingOut;
    
    }
    return null;
  }

  /// Delete Reminder Schedule
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] scheduleId (required):
  ///
  /// * [int] version:
  Future<Response> deleteReminderScheduleWithHttpInfo(String scheduleId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/reminder-schedules/{schedule_id}'
      .replaceAll('{schedule_id}', scheduleId);

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

  /// Delete Reminder Schedule
  ///
  /// Parameters:
  ///
  /// * [String] scheduleId (required):
  ///
  /// * [int] version:
  Future<PersonalReminderScheduleOut?> deleteReminderSchedule(String scheduleId, { int? version, }) async {
    final response = await deleteReminderScheduleWithHttpInfo(scheduleId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalReminderScheduleOut',) as PersonalReminderScheduleOut;
    
    }
    return null;
  }

  /// Delete Reminder State
  ///
  /// Takes the decision back: the reminder shows again.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] stateId (required):
  ///
  /// * [int] version:
  Future<Response> deleteReminderStateWithHttpInfo(String stateId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/reminder-states/{state_id}'
      .replaceAll('{state_id}', stateId);

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

  /// Delete Reminder State
  ///
  /// Takes the decision back: the reminder shows again.
  ///
  /// Parameters:
  ///
  /// * [String] stateId (required):
  ///
  /// * [int] version:
  Future<PersonalReminderStateOut?> deleteReminderState(String stateId, { int? version, }) async {
    final response = await deleteReminderStateWithHttpInfo(stateId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalReminderStateOut',) as PersonalReminderStateOut;
    
    }
    return null;
  }

  /// Get Allocation Plan
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] planId (required):
  Future<Response> getAllocationPlanWithHttpInfo(String planId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/allocation-plans/{plan_id}'
      .replaceAll('{plan_id}', planId);

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

  /// Get Allocation Plan
  ///
  /// Parameters:
  ///
  /// * [String] planId (required):
  Future<PersonalAllocationPlanOut?> getAllocationPlan(String planId,) async {
    final response = await getAllocationPlanWithHttpInfo(planId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAllocationPlanOut',) as PersonalAllocationPlanOut;
    
    }
    return null;
  }

  /// Get Allocation Rule
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] ruleId (required):
  Future<Response> getAllocationRuleWithHttpInfo(String ruleId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/allocation-rules/{rule_id}'
      .replaceAll('{rule_id}', ruleId);

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

  /// Get Allocation Rule
  ///
  /// Parameters:
  ///
  /// * [String] ruleId (required):
  Future<PersonalAllocationRuleOut?> getAllocationRule(String ruleId,) async {
    final response = await getAllocationRuleWithHttpInfo(ruleId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAllocationRuleOut',) as PersonalAllocationRuleOut;
    
    }
    return null;
  }

  /// Get Goal Contribution
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contributionId (required):
  Future<Response> getGoalContributionWithHttpInfo(String contributionId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/goal-contributions/{contribution_id}'
      .replaceAll('{contribution_id}', contributionId);

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

  /// Get Goal Contribution
  ///
  /// Parameters:
  ///
  /// * [String] contributionId (required):
  Future<PersonalGoalContributionOut?> getGoalContribution(String contributionId,) async {
    final response = await getGoalContributionWithHttpInfo(contributionId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalGoalContributionOut',) as PersonalGoalContributionOut;
    
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

  /// Get Personal Account
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  Future<Response> getPersonalAccountWithHttpInfo(String accountId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/accounts/{account_id}'
      .replaceAll('{account_id}', accountId);

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

  /// Get Personal Account
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  Future<PersonalAccountOut?> getPersonalAccount(String accountId,) async {
    final response = await getPersonalAccountWithHttpInfo(accountId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAccountOut',) as PersonalAccountOut;
    
    }
    return null;
  }

  /// Get Personal Goal
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] goalId (required):
  Future<Response> getPersonalGoalWithHttpInfo(String goalId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/goals/{goal_id}'
      .replaceAll('{goal_id}', goalId);

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

  /// Get Personal Goal
  ///
  /// Parameters:
  ///
  /// * [String] goalId (required):
  Future<PersonalGoalOut?> getPersonalGoal(String goalId,) async {
    final response = await getPersonalGoalWithHttpInfo(goalId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalGoalOut',) as PersonalGoalOut;
    
    }
    return null;
  }

  /// Get Personal Holding
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] holdingId (required):
  Future<Response> getPersonalHoldingWithHttpInfo(String holdingId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/holdings/{holding_id}'
      .replaceAll('{holding_id}', holdingId);

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

  /// Get Personal Holding
  ///
  /// Parameters:
  ///
  /// * [String] holdingId (required):
  Future<PersonalHoldingOut?> getPersonalHolding(String holdingId,) async {
    final response = await getPersonalHoldingWithHttpInfo(holdingId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalHoldingOut',) as PersonalHoldingOut;
    
    }
    return null;
  }

  /// Get Reminder Schedule
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] scheduleId (required):
  Future<Response> getReminderScheduleWithHttpInfo(String scheduleId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/reminder-schedules/{schedule_id}'
      .replaceAll('{schedule_id}', scheduleId);

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

  /// Get Reminder Schedule
  ///
  /// Parameters:
  ///
  /// * [String] scheduleId (required):
  Future<PersonalReminderScheduleOut?> getReminderSchedule(String scheduleId,) async {
    final response = await getReminderScheduleWithHttpInfo(scheduleId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalReminderScheduleOut',) as PersonalReminderScheduleOut;
    
    }
    return null;
  }

  /// Get Reminder State
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] stateId (required):
  Future<Response> getReminderStateWithHttpInfo(String stateId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/reminder-states/{state_id}'
      .replaceAll('{state_id}', stateId);

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

  /// Get Reminder State
  ///
  /// Parameters:
  ///
  /// * [String] stateId (required):
  Future<PersonalReminderStateOut?> getReminderState(String stateId,) async {
    final response = await getReminderStateWithHttpInfo(stateId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalReminderStateOut',) as PersonalReminderStateOut;
    
    }
    return null;
  }

  /// List Allocation Plans
  ///
  /// Oldest first (`deleted=true`: cancelled with their income, or deleted). No status: the app works out planned, partial, fulfilled or cancelled.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] sourceTransactionId:
  ///
  /// * [String] ruleId:
  ///
  /// * [String] goalId:
  ///
  /// * [String] accountId:
  ///
  /// * [bool] deleted:
  Future<Response> listAllocationPlansWithHttpInfo({ String? sourceTransactionId, String? ruleId, String? goalId, String? accountId, bool? deleted, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/allocation-plans';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (sourceTransactionId != null) {
      queryParams.addAll(_queryParams('', 'source_transaction_id', sourceTransactionId));
    }
    if (ruleId != null) {
      queryParams.addAll(_queryParams('', 'rule_id', ruleId));
    }
    if (goalId != null) {
      queryParams.addAll(_queryParams('', 'goal_id', goalId));
    }
    if (accountId != null) {
      queryParams.addAll(_queryParams('', 'account_id', accountId));
    }
    if (deleted != null) {
      queryParams.addAll(_queryParams('', 'deleted', deleted));
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

  /// List Allocation Plans
  ///
  /// Oldest first (`deleted=true`: cancelled with their income, or deleted). No status: the app works out planned, partial, fulfilled or cancelled.
  ///
  /// Parameters:
  ///
  /// * [String] sourceTransactionId:
  ///
  /// * [String] ruleId:
  ///
  /// * [String] goalId:
  ///
  /// * [String] accountId:
  ///
  /// * [bool] deleted:
  Future<List<PersonalAllocationPlanOut>?> listAllocationPlans({ String? sourceTransactionId, String? ruleId, String? goalId, String? accountId, bool? deleted, }) async {
    final response = await listAllocationPlansWithHttpInfo( sourceTransactionId: sourceTransactionId, ruleId: ruleId, goalId: goalId, accountId: accountId, deleted: deleted, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<PersonalAllocationPlanOut>') as List)
        .cast<PersonalAllocationPlanOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// List Allocation Rules
  ///
  /// Your rules by priority, then oldest first (`deleted=true`: the deleted ones). Whether active percentages add up to more than 100% is the app's to say.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [bool] deleted:
  Future<Response> listAllocationRulesWithHttpInfo({ bool? deleted, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/allocation-rules';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deleted != null) {
      queryParams.addAll(_queryParams('', 'deleted', deleted));
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

  /// List Allocation Rules
  ///
  /// Your rules by priority, then oldest first (`deleted=true`: the deleted ones). Whether active percentages add up to more than 100% is the app's to say.
  ///
  /// Parameters:
  ///
  /// * [bool] deleted:
  Future<List<PersonalAllocationRuleOut>?> listAllocationRules({ bool? deleted, }) async {
    final response = await listAllocationRulesWithHttpInfo( deleted: deleted, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<PersonalAllocationRuleOut>') as List)
        .cast<PersonalAllocationRuleOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// List Goal Contributions
  ///
  /// Newest first, of one goal or all (`deleted=true`: the deleted ones).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] goalId:
  ///
  /// * [bool] deleted:
  Future<Response> listGoalContributionsWithHttpInfo({ String? goalId, bool? deleted, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/goal-contributions';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (goalId != null) {
      queryParams.addAll(_queryParams('', 'goal_id', goalId));
    }
    if (deleted != null) {
      queryParams.addAll(_queryParams('', 'deleted', deleted));
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

  /// List Goal Contributions
  ///
  /// Newest first, of one goal or all (`deleted=true`: the deleted ones).
  ///
  /// Parameters:
  ///
  /// * [String] goalId:
  ///
  /// * [bool] deleted:
  Future<List<PersonalGoalContributionOut>?> listGoalContributions({ String? goalId, bool? deleted, }) async {
    final response = await listGoalContributionsWithHttpInfo( goalId: goalId, deleted: deleted, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<PersonalGoalContributionOut>') as List)
        .cast<PersonalGoalContributionOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// List Personal
  ///
  /// Your own entries (only you see these), newest first, with totals: `spent_minor` is expenses minus refunds; transfers, adjustments and investments aren't spending. `reviewed=false&source=sms` is what the app shows as \"Just in\".
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
  /// * [String] account:
  ///   As labelled, e.g. \"HDFC ··4821\"
  ///
  /// * [String] accountId:
  ///
  /// * [String] channel:
  ///
  /// * [String] source_:
  ///
  /// * [bool] reviewed:
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  Future<Response> listPersonalWithHttpInfo({ DateTime? start, DateTime? end, String? type, List<String>? category, bool? deleted, String? account, String? accountId, String? channel, String? source_, bool? reviewed, int? limit, int? offset, }) async {
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
    if (account != null) {
      queryParams.addAll(_queryParams('', 'account', account));
    }
    if (accountId != null) {
      queryParams.addAll(_queryParams('', 'account_id', accountId));
    }
    if (channel != null) {
      queryParams.addAll(_queryParams('', 'channel', channel));
    }
    if (source_ != null) {
      queryParams.addAll(_queryParams('', 'source', source_));
    }
    if (reviewed != null) {
      queryParams.addAll(_queryParams('', 'reviewed', reviewed));
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
  /// Your own entries (only you see these), newest first, with totals: `spent_minor` is expenses minus refunds; transfers, adjustments and investments aren't spending. `reviewed=false&source=sms` is what the app shows as \"Just in\".
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
  /// * [String] account:
  ///   As labelled, e.g. \"HDFC ··4821\"
  ///
  /// * [String] accountId:
  ///
  /// * [String] channel:
  ///
  /// * [String] source_:
  ///
  /// * [bool] reviewed:
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  Future<PersonalListOut?> listPersonal({ DateTime? start, DateTime? end, String? type, List<String>? category, bool? deleted, String? account, String? accountId, String? channel, String? source_, bool? reviewed, int? limit, int? offset, }) async {
    final response = await listPersonalWithHttpInfo( start: start, end: end, type: type, category: category, deleted: deleted, account: account, accountId: accountId, channel: channel, source_: source_, reviewed: reviewed, limit: limit, offset: offset, );
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

  /// List Personal Accounts
  ///
  /// Your accounts, active and closed, oldest first (`deleted=true`: the deleted ones, for restoring). No balances: the app derives them from each account's opening balance and the entries in it.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [bool] deleted:
  Future<Response> listPersonalAccountsWithHttpInfo({ bool? deleted, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/accounts';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deleted != null) {
      queryParams.addAll(_queryParams('', 'deleted', deleted));
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

  /// List Personal Accounts
  ///
  /// Your accounts, active and closed, oldest first (`deleted=true`: the deleted ones, for restoring). No balances: the app derives them from each account's opening balance and the entries in it.
  ///
  /// Parameters:
  ///
  /// * [bool] deleted:
  Future<List<PersonalAccountOut>?> listPersonalAccounts({ bool? deleted, }) async {
    final response = await listPersonalAccountsWithHttpInfo( deleted: deleted, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<PersonalAccountOut>') as List)
        .cast<PersonalAccountOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// List Personal Goals
  ///
  /// Your goals by priority, then oldest first (`deleted=true`: the deleted ones). No progress: the app derives it from the source each goal's `tracking_mode` names.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [bool] deleted:
  Future<Response> listPersonalGoalsWithHttpInfo({ bool? deleted, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/goals';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deleted != null) {
      queryParams.addAll(_queryParams('', 'deleted', deleted));
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

  /// List Personal Goals
  ///
  /// Your goals by priority, then oldest first (`deleted=true`: the deleted ones). No progress: the app derives it from the source each goal's `tracking_mode` names.
  ///
  /// Parameters:
  ///
  /// * [bool] deleted:
  Future<List<PersonalGoalOut>?> listPersonalGoals({ bool? deleted, }) async {
    final response = await listPersonalGoalsWithHttpInfo( deleted: deleted, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<PersonalGoalOut>') as List)
        .cast<PersonalGoalOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// List Personal Holdings
  ///
  /// Oldest first, of one account or all (`deleted=true`: the deleted ones). No gains or stale flags: the app works those out.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] accountId:
  ///
  /// * [bool] deleted:
  Future<Response> listPersonalHoldingsWithHttpInfo({ String? accountId, bool? deleted, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/holdings';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (accountId != null) {
      queryParams.addAll(_queryParams('', 'account_id', accountId));
    }
    if (deleted != null) {
      queryParams.addAll(_queryParams('', 'deleted', deleted));
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

  /// List Personal Holdings
  ///
  /// Oldest first, of one account or all (`deleted=true`: the deleted ones). No gains or stale flags: the app works those out.
  ///
  /// Parameters:
  ///
  /// * [String] accountId:
  ///
  /// * [bool] deleted:
  Future<List<PersonalHoldingOut>?> listPersonalHoldings({ String? accountId, bool? deleted, }) async {
    final response = await listPersonalHoldingsWithHttpInfo( accountId: accountId, deleted: deleted, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<PersonalHoldingOut>') as List)
        .cast<PersonalHoldingOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// List Reminder Schedules
  ///
  /// By day of the month (`deleted=true`: the deleted ones). No due dates: the app works out the next one.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] goalId:
  ///
  /// * [String] holdingId:
  ///
  /// * [bool] deleted:
  Future<Response> listReminderSchedulesWithHttpInfo({ String? goalId, String? holdingId, bool? deleted, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/reminder-schedules';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (goalId != null) {
      queryParams.addAll(_queryParams('', 'goal_id', goalId));
    }
    if (holdingId != null) {
      queryParams.addAll(_queryParams('', 'holding_id', holdingId));
    }
    if (deleted != null) {
      queryParams.addAll(_queryParams('', 'deleted', deleted));
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

  /// List Reminder Schedules
  ///
  /// By day of the month (`deleted=true`: the deleted ones). No due dates: the app works out the next one.
  ///
  /// Parameters:
  ///
  /// * [String] goalId:
  ///
  /// * [String] holdingId:
  ///
  /// * [bool] deleted:
  Future<List<PersonalReminderScheduleOut>?> listReminderSchedules({ String? goalId, String? holdingId, bool? deleted, }) async {
    final response = await listReminderSchedulesWithHttpInfo( goalId: goalId, holdingId: holdingId, deleted: deleted, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<PersonalReminderScheduleOut>') as List)
        .cast<PersonalReminderScheduleOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// List Reminder States
  ///
  /// Your decisions on reminders (`deleted=true`: the ones taken back).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [bool] deleted:
  Future<Response> listReminderStatesWithHttpInfo({ bool? deleted, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/reminder-states';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deleted != null) {
      queryParams.addAll(_queryParams('', 'deleted', deleted));
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

  /// List Reminder States
  ///
  /// Your decisions on reminders (`deleted=true`: the ones taken back).
  ///
  /// Parameters:
  ///
  /// * [bool] deleted:
  Future<List<PersonalReminderStateOut>?> listReminderStates({ bool? deleted, }) async {
    final response = await listReminderStatesWithHttpInfo( deleted: deleted, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<PersonalReminderStateOut>') as List)
        .cast<PersonalReminderStateOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// Personal Reported Accounts
  ///
  /// The account labels your entries carry, most recently used first, each with the latest balance its bank reported. Kept until the app stops using `/personal/summary`.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> personalReportedAccountsWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/accounts/reported';

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

  /// Personal Reported Accounts
  ///
  /// The account labels your entries carry, most recently used first, each with the latest balance its bank reported. Kept until the app stops using `/personal/summary`.
  Future<List<AccountOut>?> personalReportedAccounts() async {
    final response = await personalReportedAccountsWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<AccountOut>') as List)
        .cast<AccountOut>()
        .toList(growable: false);

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

  /// Restore Allocation Plan
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] planId (required):
  ///
  /// * [int] version:
  Future<Response> restoreAllocationPlanWithHttpInfo(String planId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/allocation-plans/{plan_id}/restore'
      .replaceAll('{plan_id}', planId);

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

  /// Restore Allocation Plan
  ///
  /// Parameters:
  ///
  /// * [String] planId (required):
  ///
  /// * [int] version:
  Future<PersonalAllocationPlanOut?> restoreAllocationPlan(String planId, { int? version, }) async {
    final response = await restoreAllocationPlanWithHttpInfo(planId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAllocationPlanOut',) as PersonalAllocationPlanOut;
    
    }
    return null;
  }

  /// Restore Allocation Rule
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] ruleId (required):
  ///
  /// * [int] version:
  Future<Response> restoreAllocationRuleWithHttpInfo(String ruleId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/allocation-rules/{rule_id}/restore'
      .replaceAll('{rule_id}', ruleId);

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

  /// Restore Allocation Rule
  ///
  /// Parameters:
  ///
  /// * [String] ruleId (required):
  ///
  /// * [int] version:
  Future<PersonalAllocationRuleOut?> restoreAllocationRule(String ruleId, { int? version, }) async {
    final response = await restoreAllocationRuleWithHttpInfo(ruleId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAllocationRuleOut',) as PersonalAllocationRuleOut;
    
    }
    return null;
  }

  /// Restore Goal Contribution
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contributionId (required):
  ///
  /// * [int] version:
  Future<Response> restoreGoalContributionWithHttpInfo(String contributionId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/goal-contributions/{contribution_id}/restore'
      .replaceAll('{contribution_id}', contributionId);

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

  /// Restore Goal Contribution
  ///
  /// Parameters:
  ///
  /// * [String] contributionId (required):
  ///
  /// * [int] version:
  Future<PersonalGoalContributionOut?> restoreGoalContribution(String contributionId, { int? version, }) async {
    final response = await restoreGoalContributionWithHttpInfo(contributionId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalGoalContributionOut',) as PersonalGoalContributionOut;
    
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

  /// Restore Personal Account
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  ///
  /// * [int] version:
  Future<Response> restorePersonalAccountWithHttpInfo(String accountId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/accounts/{account_id}/restore'
      .replaceAll('{account_id}', accountId);

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

  /// Restore Personal Account
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  ///
  /// * [int] version:
  Future<PersonalAccountOut?> restorePersonalAccount(String accountId, { int? version, }) async {
    final response = await restorePersonalAccountWithHttpInfo(accountId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAccountOut',) as PersonalAccountOut;
    
    }
    return null;
  }

  /// Restore Personal Goal
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] goalId (required):
  ///
  /// * [int] version:
  Future<Response> restorePersonalGoalWithHttpInfo(String goalId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/goals/{goal_id}/restore'
      .replaceAll('{goal_id}', goalId);

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

  /// Restore Personal Goal
  ///
  /// Parameters:
  ///
  /// * [String] goalId (required):
  ///
  /// * [int] version:
  Future<PersonalGoalOut?> restorePersonalGoal(String goalId, { int? version, }) async {
    final response = await restorePersonalGoalWithHttpInfo(goalId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalGoalOut',) as PersonalGoalOut;
    
    }
    return null;
  }

  /// Restore Personal Holding
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] holdingId (required):
  ///
  /// * [int] version:
  Future<Response> restorePersonalHoldingWithHttpInfo(String holdingId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/holdings/{holding_id}/restore'
      .replaceAll('{holding_id}', holdingId);

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

  /// Restore Personal Holding
  ///
  /// Parameters:
  ///
  /// * [String] holdingId (required):
  ///
  /// * [int] version:
  Future<PersonalHoldingOut?> restorePersonalHolding(String holdingId, { int? version, }) async {
    final response = await restorePersonalHoldingWithHttpInfo(holdingId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalHoldingOut',) as PersonalHoldingOut;
    
    }
    return null;
  }

  /// Restore Reminder Schedule
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] scheduleId (required):
  ///
  /// * [int] version:
  Future<Response> restoreReminderScheduleWithHttpInfo(String scheduleId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/reminder-schedules/{schedule_id}/restore'
      .replaceAll('{schedule_id}', scheduleId);

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

  /// Restore Reminder Schedule
  ///
  /// Parameters:
  ///
  /// * [String] scheduleId (required):
  ///
  /// * [int] version:
  Future<PersonalReminderScheduleOut?> restoreReminderSchedule(String scheduleId, { int? version, }) async {
    final response = await restoreReminderScheduleWithHttpInfo(scheduleId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalReminderScheduleOut',) as PersonalReminderScheduleOut;
    
    }
    return null;
  }

  /// Restore Reminder State
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] stateId (required):
  ///
  /// * [int] version:
  Future<Response> restoreReminderStateWithHttpInfo(String stateId, { int? version, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/reminder-states/{state_id}/restore'
      .replaceAll('{state_id}', stateId);

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

  /// Restore Reminder State
  ///
  /// Parameters:
  ///
  /// * [String] stateId (required):
  ///
  /// * [int] version:
  Future<PersonalReminderStateOut?> restoreReminderState(String stateId, { int? version, }) async {
    final response = await restoreReminderStateWithHttpInfo(stateId,  version: version, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalReminderStateOut',) as PersonalReminderStateOut;
    
    }
    return null;
  }

  /// Save Reminder State
  ///
  /// Makes the decision for `dedup_key` (201), or replaces the one there is (200), even a deleted one. Its id is reminder_state_id(you, dedup_key).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PersonalReminderStateIn] personalReminderStateIn (required):
  Future<Response> saveReminderStateWithHttpInfo(PersonalReminderStateIn personalReminderStateIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/reminder-states';

    // ignore: prefer_final_locals
    Object? postBody = personalReminderStateIn;

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

  /// Save Reminder State
  ///
  /// Makes the decision for `dedup_key` (201), or replaces the one there is (200), even a deleted one. Its id is reminder_state_id(you, dedup_key).
  ///
  /// Parameters:
  ///
  /// * [PersonalReminderStateIn] personalReminderStateIn (required):
  Future<PersonalReminderStateOut?> saveReminderState(PersonalReminderStateIn personalReminderStateIn,) async {
    final response = await saveReminderStateWithHttpInfo(personalReminderStateIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalReminderStateOut',) as PersonalReminderStateOut;
    
    }
    return null;
  }

  /// Update Allocation Plan
  ///
  /// A recomputed snapshot and amount (after its income changed).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] planId (required):
  ///
  /// * [PersonalAllocationPlanIn] personalAllocationPlanIn (required):
  Future<Response> updateAllocationPlanWithHttpInfo(String planId, PersonalAllocationPlanIn personalAllocationPlanIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/allocation-plans/{plan_id}'
      .replaceAll('{plan_id}', planId);

    // ignore: prefer_final_locals
    Object? postBody = personalAllocationPlanIn;

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

  /// Update Allocation Plan
  ///
  /// A recomputed snapshot and amount (after its income changed).
  ///
  /// Parameters:
  ///
  /// * [String] planId (required):
  ///
  /// * [PersonalAllocationPlanIn] personalAllocationPlanIn (required):
  Future<PersonalAllocationPlanOut?> updateAllocationPlan(String planId, PersonalAllocationPlanIn personalAllocationPlanIn,) async {
    final response = await updateAllocationPlanWithHttpInfo(planId, personalAllocationPlanIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAllocationPlanOut',) as PersonalAllocationPlanOut;
    
    }
    return null;
  }

  /// Update Allocation Rule
  ///
  /// Fields left out keep their value. Existing plans keep the snapshot they were made with.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] ruleId (required):
  ///
  /// * [PersonalAllocationRuleIn] personalAllocationRuleIn (required):
  Future<Response> updateAllocationRuleWithHttpInfo(String ruleId, PersonalAllocationRuleIn personalAllocationRuleIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/allocation-rules/{rule_id}'
      .replaceAll('{rule_id}', ruleId);

    // ignore: prefer_final_locals
    Object? postBody = personalAllocationRuleIn;

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

  /// Update Allocation Rule
  ///
  /// Fields left out keep their value. Existing plans keep the snapshot they were made with.
  ///
  /// Parameters:
  ///
  /// * [String] ruleId (required):
  ///
  /// * [PersonalAllocationRuleIn] personalAllocationRuleIn (required):
  Future<PersonalAllocationRuleOut?> updateAllocationRule(String ruleId, PersonalAllocationRuleIn personalAllocationRuleIn,) async {
    final response = await updateAllocationRuleWithHttpInfo(ruleId, personalAllocationRuleIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAllocationRuleOut',) as PersonalAllocationRuleOut;
    
    }
    return null;
  }

  /// Update Goal Contribution
  ///
  /// `transaction_id` and `note` keep their value when left out.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contributionId (required):
  ///
  /// * [PersonalGoalContributionIn] personalGoalContributionIn (required):
  Future<Response> updateGoalContributionWithHttpInfo(String contributionId, PersonalGoalContributionIn personalGoalContributionIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/goal-contributions/{contribution_id}'
      .replaceAll('{contribution_id}', contributionId);

    // ignore: prefer_final_locals
    Object? postBody = personalGoalContributionIn;

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

  /// Update Goal Contribution
  ///
  /// `transaction_id` and `note` keep their value when left out.
  ///
  /// Parameters:
  ///
  /// * [String] contributionId (required):
  ///
  /// * [PersonalGoalContributionIn] personalGoalContributionIn (required):
  Future<PersonalGoalContributionOut?> updateGoalContribution(String contributionId, PersonalGoalContributionIn personalGoalContributionIn,) async {
    final response = await updateGoalContributionWithHttpInfo(contributionId, personalGoalContributionIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalGoalContributionOut',) as PersonalGoalContributionOut;
    
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

  /// Update Personal Account
  ///
  /// `status: closed` closes it: it takes no new entries and still counts in net worth. A new `sms_label` moves in your entries with that label and no account.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  ///
  /// * [PersonalAccountIn] personalAccountIn (required):
  Future<Response> updatePersonalAccountWithHttpInfo(String accountId, PersonalAccountIn personalAccountIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/accounts/{account_id}'
      .replaceAll('{account_id}', accountId);

    // ignore: prefer_final_locals
    Object? postBody = personalAccountIn;

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

  /// Update Personal Account
  ///
  /// `status: closed` closes it: it takes no new entries and still counts in net worth. A new `sms_label` moves in your entries with that label and no account.
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  ///
  /// * [PersonalAccountIn] personalAccountIn (required):
  Future<PersonalAccountOut?> updatePersonalAccount(String accountId, PersonalAccountIn personalAccountIn,) async {
    final response = await updatePersonalAccountWithHttpInfo(accountId, personalAccountIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalAccountOut',) as PersonalAccountOut;
    
    }
    return null;
  }

  /// Update Personal Goal
  ///
  /// Fields left out keep their value (`status`: null keeps it too). Switching `tracking_mode` needs that mode's field, and drops the old mode's.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] goalId (required):
  ///
  /// * [PersonalGoalIn] personalGoalIn (required):
  Future<Response> updatePersonalGoalWithHttpInfo(String goalId, PersonalGoalIn personalGoalIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/goals/{goal_id}'
      .replaceAll('{goal_id}', goalId);

    // ignore: prefer_final_locals
    Object? postBody = personalGoalIn;

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

  /// Update Personal Goal
  ///
  /// Fields left out keep their value (`status`: null keeps it too). Switching `tracking_mode` needs that mode's field, and drops the old mode's.
  ///
  /// Parameters:
  ///
  /// * [String] goalId (required):
  ///
  /// * [PersonalGoalIn] personalGoalIn (required):
  Future<PersonalGoalOut?> updatePersonalGoal(String goalId, PersonalGoalIn personalGoalIn,) async {
    final response = await updatePersonalGoalWithHttpInfo(goalId, personalGoalIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalGoalOut',) as PersonalGoalOut;
    
    }
    return null;
  }

  /// Update Personal Holding
  ///
  /// \"Update value\": the valuation is replaced (only the latest is kept). The account, quantity and cost basis keep their value when left out.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] holdingId (required):
  ///
  /// * [PersonalHoldingIn] personalHoldingIn (required):
  Future<Response> updatePersonalHoldingWithHttpInfo(String holdingId, PersonalHoldingIn personalHoldingIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/holdings/{holding_id}'
      .replaceAll('{holding_id}', holdingId);

    // ignore: prefer_final_locals
    Object? postBody = personalHoldingIn;

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

  /// Update Personal Holding
  ///
  /// \"Update value\": the valuation is replaced (only the latest is kept). The account, quantity and cost basis keep their value when left out.
  ///
  /// Parameters:
  ///
  /// * [String] holdingId (required):
  ///
  /// * [PersonalHoldingIn] personalHoldingIn (required):
  Future<PersonalHoldingOut?> updatePersonalHolding(String holdingId, PersonalHoldingIn personalHoldingIn,) async {
    final response = await updatePersonalHoldingWithHttpInfo(holdingId, personalHoldingIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalHoldingOut',) as PersonalHoldingOut;
    
    }
    return null;
  }

  /// Update Reminder Schedule
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] scheduleId (required):
  ///
  /// * [PersonalReminderScheduleIn] personalReminderScheduleIn (required):
  Future<Response> updateReminderScheduleWithHttpInfo(String scheduleId, PersonalReminderScheduleIn personalReminderScheduleIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/reminder-schedules/{schedule_id}'
      .replaceAll('{schedule_id}', scheduleId);

    // ignore: prefer_final_locals
    Object? postBody = personalReminderScheduleIn;

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

  /// Update Reminder Schedule
  ///
  /// Parameters:
  ///
  /// * [String] scheduleId (required):
  ///
  /// * [PersonalReminderScheduleIn] personalReminderScheduleIn (required):
  Future<PersonalReminderScheduleOut?> updateReminderSchedule(String scheduleId, PersonalReminderScheduleIn personalReminderScheduleIn,) async {
    final response = await updateReminderScheduleWithHttpInfo(scheduleId, personalReminderScheduleIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalReminderScheduleOut',) as PersonalReminderScheduleOut;
    
    }
    return null;
  }

  /// Update Reminder State
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] stateId (required):
  ///
  /// * [PersonalReminderStateIn] personalReminderStateIn (required):
  Future<Response> updateReminderStateWithHttpInfo(String stateId, PersonalReminderStateIn personalReminderStateIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/personal/reminder-states/{state_id}'
      .replaceAll('{state_id}', stateId);

    // ignore: prefer_final_locals
    Object? postBody = personalReminderStateIn;

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

  /// Update Reminder State
  ///
  /// Parameters:
  ///
  /// * [String] stateId (required):
  ///
  /// * [PersonalReminderStateIn] personalReminderStateIn (required):
  Future<PersonalReminderStateOut?> updateReminderState(String stateId, PersonalReminderStateIn personalReminderStateIn,) async {
    final response = await updateReminderStateWithHttpInfo(stateId, personalReminderStateIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PersonalReminderStateOut',) as PersonalReminderStateOut;
    
    }
    return null;
  }
}
