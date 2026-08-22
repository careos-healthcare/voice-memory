import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/features/coach/coach_models.dart';

abstract interface class CoachConsentApiClient {
  Future<ApiResult<CoachConsentToken>> issueToken({
    required String relationshipId,
    required String coachId,
    required CoachSharingPermissions permissions,
    required String clientAffirmationHash,
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<CoachTokenVerificationResult>> verifyToken({
    required CoachConsentToken token,
    NetworkCancelToken? cancelToken,
  });
}