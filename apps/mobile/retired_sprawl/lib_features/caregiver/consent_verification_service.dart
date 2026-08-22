import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/consent_audit/consent_revocation_store.dart';
import 'package:archiveme_mobile/data/network/caregiver_consent_api_client.dart';
import 'package:uuid/uuid.dart';

/// Verifies [MonitoringConsentToken] via server-side HMAC before granting access.
///
/// Local device-bound signing has been removed — verification fails closed when
/// the backend is unavailable or the server rejects the token.
class ConsentVerificationService {
  ConsentVerificationService({
    this._consentApi,
  });

  static const int currentPolicyVersion = AppModeConfigPolicy.currentPolicyVersion;

  final CaregiverConsentApiClient? _consentApi;
  final Uuid _uuid = const Uuid();

  Future<CaregiverTokenVerificationResult> verify(
    MonitoringConsentToken token, {
    DateTime? now,
  }) async {
    final clock = (now ?? DateTime.now()).toUtc();

    if (token.policyVersion != currentPolicyVersion) {
      return const CaregiverTokenVerificationResult(
        valid: false,
        reason: 'Unsupported consent policy version',
      );
    }

    if (token.tokenId.isEmpty ||
        token.subjectAccountId.isEmpty ||
        token.caregiverId.isEmpty) {
      return const CaregiverTokenVerificationResult(
        valid: false,
        reason: 'Incomplete consent token',
      );
    }

    await ConsentRevocationStore.ensureLoaded();
    if (ConsentRevocationStore.isRevoked(token.tokenId)) {
      return const CaregiverTokenVerificationResult(
        valid: false,
        reason: 'Consent token revoked',
      );
    }

    if (!clock.isBefore(token.expiresAt)) {
      return const CaregiverTokenVerificationResult(
        valid: false,
        reason: 'Consent token expired',
      );
    }

    if (clock.isBefore(token.issuedAt)) {
      return const CaregiverTokenVerificationResult(
        valid: false,
        reason: 'Consent token not yet valid',
      );
    }

    return _verifyViaServer(token, clock);
  }

  /// Issues a server-signed token after explicit in-app consent.
  ///
  /// Takes no lifetime and no clock. Both are the server's: expiry comes from
  /// `CAREGIVER_CONSENT_DEFAULT_TTL_MS` (7 days,
  /// `packages/shared/lib/consent/consent-token-ttl.ts`) and arrives on the
  /// returned token. This used to declare `ttl` defaulting to 30 days and a
  /// `now` override, neither of which was read here or passed to
  /// `_consentApi.issueToken`. A caller could set either and change nothing,
  /// and a reader could take the 30 for the caregiver lifetime — which is what
  /// happened: it is the coach default, and published copy said 30 days until
  /// `CaregiverGrantCopy.stopPassLifetime` was corrected to 7.
  Future<MonitoringConsentToken> issueToken({
    required String subjectAccountId,
    required String caregiverId,
    required CaregiverPermissions permissions,
  }) async {
    if (AppConfig.isBackendConfigured && _consentApi != null) {
      final result = await _consentApi.issueToken(
        subjectAccountId: subjectAccountId,
        caregiverId: caregiverId,
        permissions: permissions,
      );
      if (result case ApiSuccess(:final value)) {
        return value;
      }
    }

    throw StateError(
      'Server caregiver consent issuance unavailable — backend not configured',
    );
  }

  Future<CaregiverTokenVerificationResult> _verifyViaServer(
    MonitoringConsentToken token,
    DateTime clock,
  ) async {
    final api = _consentApi;
    if (api == null) {
      return const CaregiverTokenVerificationResult(
        valid: false,
        reason: 'Server consent verification unavailable',
      );
    }

    final result = await api.verifyToken(token: token);
    return switch (result) {
      ApiSuccess(:final value) => _normalizeServerResult(value, token, clock),
      ApiFailureResult() => const CaregiverTokenVerificationResult(
          valid: false,
          reason: 'Server consent verification failed',
        ),
    };
  }

  CaregiverTokenVerificationResult _normalizeServerResult(
    CaregiverTokenVerificationResult serverResult,
    MonitoringConsentToken token,
    DateTime clock,
  ) {
    if (!serverResult.valid) {
      return CaregiverTokenVerificationResult(
        valid: false,
        reason: serverResult.reason ?? 'Server consent verification failed',
      );
    }

    final session = serverResult.session ??
        CaregiverSession(
          sessionId: _uuid.v4(),
          mode: AppMode.caregiverMonitoring,
          caregiverId: token.caregiverId,
          subjectAccountId: token.subjectAccountId,
          permissions: token.permissions,
          tokenId: token.tokenId,
          startedAt: clock,
          expiresAt: token.expiresAt,
          validatedAt: clock,
        );

    return CaregiverTokenVerificationResult(valid: true, session: session);
  }

  /// Persists local revocation so future verification fails closed.
  Future<void> revokeToken(String tokenId) async {
    if (tokenId.trim().isEmpty) return;
    await ConsentRevocationStore.ensureLoaded();
    await ConsentRevocationStore.revoke(tokenId.trim());
  }
}