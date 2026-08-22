import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';

/// What the server did when asked to replace a caregiver grant.
///
/// [previousRevokedAt] is what makes this a replacement rather than an
/// addition: the server withdrew the token that was presented in the same step
/// that registered [token]. A response without it is treated as unconfirmed,
/// because a successor whose predecessor may still be live is two credentials
/// for one arrangement.
class ConsentRenewalConfirmation {
  const ConsentRenewalConfirmation({
    required this.token,
    required this.previousTokenId,
    this.previousRevokedAt,
    this.ownerConfirmedAt,
  });

  final MonitoringConsentToken token;
  final String previousTokenId;
  final DateTime? previousRevokedAt;
  final DateTime? ownerConfirmedAt;

  bool get isConfirmed =>
      token.tokenId.isNotEmpty &&
      token.tokenId != previousTokenId &&
      previousRevokedAt != null;
}

/// Short, non-identifying codes for a renewal that did not complete.
///
/// A closed set, in the same spirit as `ConsentRevocationFailureCode`: these
/// are the only strings a renewal outcome may carry off the network, so no
/// server message and no person's name can reach local storage or a log
/// through this path.
abstract final class ConsentRenewalFailureCode {
  ConsentRenewalFailureCode._();

  /// No backend is configured for this build.
  static const backendNotConfigured = 'backend_not_configured';

  /// The device could not reach the server, or the call threw.
  static const network = 'network';

  /// The session has lapsed. Signing in again is the way forward.
  static const authRequired = 'auth_required';

  /// The signed-in account is not the one this grant names as its owner.
  static const notGrantOwner = 'not_grant_owner';

  /// The confirmation was absent, too old, or about a different grant.
  static const confirmationRequired = 'confirmation_required';

  /// The access window has already ended. Granting again is the way forward.
  static const grantExpired = 'grant_expired';

  /// The grant is withdrawn, unknown, or otherwise not in a renewable state.
  static const notRenewable = 'not_renewable';

  /// The server could not complete the swap. The current window is unchanged.
  static const serverUnavailable = 'server_unavailable';

  /// A 2xx that did not describe a completed replacement.
  static const notConfirmed = 'not_confirmed';
}

/// Asks the server to replace a caregiver grant with a fresh one.
///
/// Separate from `ConsentRevocationApiClient` because the two have opposite
/// retry policies. A revocation that does not land is queued and retried: the
/// user has already decided, and finishing that decision later is right. A
/// renewal that does not land is dropped, because retrying it later would
/// extend access at a moment the owner was not asked — which is the scheduled
/// renewal this design set out to avoid.
// ignore: one_member_abstracts
abstract interface class ConsentRenewalApiClient {
  Future<ApiResult<ConsentRenewalConfirmation>> renewCaregiverConsent({
    required String tokenId,
    required Map<String, dynamic> token,
    required DateTime ownerConfirmedAt,
    NetworkCancelToken? cancelToken,
  });
}
