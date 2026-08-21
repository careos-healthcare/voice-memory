import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship.dart';

abstract interface class UserRelationshipApiClient {
  Future<ApiResult<List<UserRelationship>>> listForCurrentUser({
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<UserRelationship>> upsert({
    required UserRelationship relationship,
    String? activeConsentTokenId,
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<UserRelationship>> updateConsentStatus({
    required String relationshipId,
    required ConsentStatus consentStatus,
    NetworkCancelToken? cancelToken,
  });
}