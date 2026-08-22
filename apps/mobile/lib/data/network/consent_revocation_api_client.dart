import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';

/// Which consent grant kind a revocation applies to.
///
/// `POST /api/coach/consent/revoke` serves both kinds and selects between them
/// on the `consentDomain` field, so one client method covers caregiver and
/// coach grants alike.
enum ConsentRevocationDomain {
  caregiverMonitoring,
  coachClient;

  String get wireValue => switch (this) {
    ConsentRevocationDomain.caregiverMonitoring => 'caregiverMonitoring',
    ConsentRevocationDomain.coachClient => 'coachClient',
  };

  /// Also accepts the legacy aliases the backend still tolerates, and the
  /// `MultiPartyAccessRole.wireValue` spellings persisted in older audit rows.
  static ConsentRevocationDomain? fromWire(String? raw) => switch (raw) {
    'caregiverMonitoring' ||
    'caregiver' ||
    'caregiver_monitoring' => ConsentRevocationDomain.caregiverMonitoring,
    'coachClient' || 'coach' || 'coach_client' =>
      ConsentRevocationDomain.coachClient,
    _ => null,
  };
}

/// Server acknowledgement that a grant is on the revocation list.
class ConsentRevocationConfirmation {
  const ConsentRevocationConfirmation({
    required this.tokenId,
    required this.revoked,
    required this.alreadyRevoked,
    this.revokedAt,
  });

  final String tokenId;
  final bool revoked;
  final bool alreadyRevoked;
  final DateTime? revokedAt;

  /// Revocation is idempotent server-side, so a grant that was already on the
  /// list is as good an outcome as one this call put there.
  bool get isConfirmed => revoked || alreadyRevoked;
}

/// Reason codes sent to the server. Never carries journal or personal text.
abstract final class ConsentRevocationReason {
  ConsentRevocationReason._();

  static const userRevoked = 'user_revoked';
}

/// Tells the server to stop honouring an already-issued consent token.
///
// A single-method interface on purpose: it is the seam every revoke path is
// injected through, and both consent domains share it.
// ignore: one_member_abstracts
abstract interface class ConsentRevocationApiClient {
  Future<ApiResult<ConsentRevocationConfirmation>> revokeConsent({
    required ConsentRevocationDomain domain,
    required String tokenId,
    String? reason,
    Map<String, dynamic>? token,
    NetworkCancelToken? cancelToken,
  });
}
