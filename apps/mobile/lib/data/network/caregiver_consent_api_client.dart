import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/consent_revocation_api_client.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';

/// Renewal is deliberately *not* part of this interface. `ConsentRenewalApiClient`
/// is a separate seam that `HttpCaregiverConsentApiClient` also implements, so
/// a surface that only revokes cannot reach a renewal by accident, and a
/// client that does not offer one leaves renewal unavailable rather than
/// half-wired. `consent_renewal_api_client_test.dart` asserts the production
/// client satisfies both, so the split cannot quietly become a gap.
abstract interface class CaregiverConsentApiClient
    implements ConsentRevocationApiClient {
  Future<ApiResult<MonitoringConsentToken>> issueToken({
    required String subjectAccountId,
    required String caregiverId,
    required CaregiverPermissions permissions,
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<CaregiverTokenVerificationResult>> verifyToken({
    required MonitoringConsentToken token,
    NetworkCancelToken? cancelToken,
  });
}
