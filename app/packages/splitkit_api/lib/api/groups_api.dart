//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class GroupsApi {
  GroupsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Add Member
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [AddMemberIn] addMemberIn (required):
  Future<Response> addMemberWithHttpInfo(String groupId, AddMemberIn addMemberIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}/members'
      .replaceAll('{group_id}', groupId);

    // ignore: prefer_final_locals
    Object? postBody = addMemberIn;

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

  /// Add Member
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [AddMemberIn] addMemberIn (required):
  Future<GroupOut?> addMember(String groupId, AddMemberIn addMemberIn,) async {
    final response = await addMemberWithHttpInfo(groupId, addMemberIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GroupOut',) as GroupOut;
    
    }
    return null;
  }

  /// Create Group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [GroupIn] groupIn (required):
  Future<Response> createGroupWithHttpInfo(GroupIn groupIn,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups';

    // ignore: prefer_final_locals
    Object? postBody = groupIn;

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

  /// Create Group
  ///
  /// Parameters:
  ///
  /// * [GroupIn] groupIn (required):
  Future<GroupOut?> createGroup(GroupIn groupIn,) async {
    final response = await createGroupWithHttpInfo(groupIn,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GroupOut',) as GroupOut;
    
    }
    return null;
  }

  /// Get Group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<Response> getGroupWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}'
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

  /// Get Group
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<GroupOut?> getGroup(String groupId,) async {
    final response = await getGroupWithHttpInfo(groupId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GroupOut',) as GroupOut;
    
    }
    return null;
  }

  /// List Groups
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [bool] archived:
  Future<Response> listGroupsWithHttpInfo({ bool? archived, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (archived != null) {
      queryParams.addAll(_queryParams('', 'archived', archived));
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

  /// List Groups
  ///
  /// Parameters:
  ///
  /// * [bool] archived:
  Future<List<GroupOut>?> listGroups({ bool? archived, }) async {
    final response = await listGroupsWithHttpInfo( archived: archived, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<GroupOut>') as List)
        .cast<GroupOut>()
        .toList(growable: false);

    }
    return null;
  }

  /// Remove Member
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [String] userId (required):
  Future<Response> removeMemberWithHttpInfo(String groupId, String userId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}/members/{user_id}'
      .replaceAll('{group_id}', groupId)
      .replaceAll('{user_id}', userId);

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

  /// Remove Member
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [String] userId (required):
  Future<void> removeMember(String groupId, String userId,) async {
    final response = await removeMemberWithHttpInfo(groupId, userId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Update Group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [GroupUpdate] groupUpdate (required):
  Future<Response> updateGroupWithHttpInfo(String groupId, GroupUpdate groupUpdate,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v1/groups/{group_id}'
      .replaceAll('{group_id}', groupId);

    // ignore: prefer_final_locals
    Object? postBody = groupUpdate;

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

  /// Update Group
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [GroupUpdate] groupUpdate (required):
  Future<GroupOut?> updateGroup(String groupId, GroupUpdate groupUpdate,) async {
    final response = await updateGroupWithHttpInfo(groupId, groupUpdate,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GroupOut',) as GroupOut;
    
    }
    return null;
  }
}
