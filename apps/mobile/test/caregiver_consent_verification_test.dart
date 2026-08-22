import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/caregiver_consent_api_client.dart';
import 'package:archiveme_mobile/data/network/consent_revocation_api_client.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCaregiverConsentApiClient implements CaregiverConsentApiClient {
  _FakeCaregiverConsentApiClient({
    this.verifyFailure = false,
  }) : issueFailure = false, verifyResult = null;

  final CaregiverTokenVerificationResult? verifyResult;
  final bool issueFailure;
  final bool verifyFailure;

  MonitoringConsentToken? lastIssuedToken;

  @override
  Future<ApiResult<MonitoringConsentToken>> issueToken({
    required String subjectAccountId,
    required String caregiverId,
    required CaregiverPermissions permissions,
    NetworkCancelToken? cancelToken,
  }) async {
    if (issueFailure) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }

    final token = MonitoringConsentToken(
      tokenId: 'token-1',
      subjectAccountId: subjectAccountId,
      caregiverId: caregiverId,
      permissions: permissions,
      issuedAt: DateTime.utc(2026),
      expiresAt: DateTime.utc(2026, 12, 31),
      policyVersion: ConsentVerificationService.currentPolicyVersion,
      signature: 'server-signature',
    );
    lastIssuedToken = token;
    return ApiSuccess(token);
  }

  @override
  Future<ApiResult<CaregiverTokenVerificationResult>> verifyToken({
    required MonitoringConsentToken token,
    NetworkCancelToken? cancelToken,
  }) async {
    if (verifyFailure) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }

    if (verifyResult != null) {
      return ApiSuccess(verifyResult!);
    }

    if (token.signature != 'server-signature') {
      return const ApiSuccess(
        CaregiverTokenVerificationResult(
          valid: false,
          reason: 'Invalid consent signature',
        ),
      );
    }

    return ApiSuccess(
      CaregiverTokenVerificationResult(
        valid: true,
        session: CaregiverSession(
          sessionId: 'session-1',
          mode: AppMode.caregiverMonitoring,
          caregiverId: token.caregiverId,
          subjectAccountId: token.subjectAccountId,
          permissions: token.permissions,
          tokenId: token.tokenId,
          startedAt: DateTime.utc(2026, 2),
          expiresAt: token.expiresAt,
          validatedAt: DateTime.utc(2026, 2),
        ),
      ),
    );
  }

  @override
  Future<ApiResult<ConsentRevocationConfirmation>> revokeConsent({
    required ConsentRevocationDomain domain,
    required String tokenId,
    String? reason,
    Map<String, dynamic>? token,
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(
      ConsentRevocationConfirmation(
        tokenId: tokenId,
        revoked: true,
        alreadyRevoked: false,
      ),
    );
  }
}

MonitoringConsentToken _sampleToken({String signature = 'server-signature'}) {
  return MonitoringConsentToken(
    tokenId: 'token-1',
    subjectAccountId: 'subject-1',
    caregiverId: 'caregiver-1',
    permissions: CaregiverPermissions.defaultScopes,
    issuedAt: DateTime.utc(2026),
    expiresAt: DateTime.utc(2026, 12, 31),
    policyVersion: ConsentVerificationService.currentPolicyVersion,
    signature: signature,
  );
}

void main() {
  test('verifies server-signed monitoring consent token', () async {
    final service = ConsentVerificationService(
      consentApi: _FakeCaregiverConsentApiClient(),
    );

    final result = await service.verify(
      _sampleToken(),
      now: DateTime.utc(2026, 2),
    );

    expect(result.valid, isTrue);
    expect(result.session, isNotNull);
    expect(result.session!.caregiverId, 'caregiver-1');
  });

  test('rejects tampered consent token signature via server', () async {
    final service = ConsentVerificationService(
      consentApi: _FakeCaregiverConsentApiClient(),
    );

    final result = await service.verify(
      _sampleToken(signature: 'deadbeef'),
      now: DateTime.utc(2026, 2),
    );

    expect(result.valid, isFalse);
    expect(result.reason, isNotNull);
  });

  test('fails closed when server verification is unavailable', () async {
    final service = ConsentVerificationService(
      consentApi: _FakeCaregiverConsentApiClient(verifyFailure: true),
    );

    final result = await service.verify(
      _sampleToken(),
      now: DateTime.utc(2026, 2),
    );

    expect(result.valid, isFalse);
    expect(result.reason, contains('failed'));
  });

  test('rejects expired token before contacting server', () async {
    final service = ConsentVerificationService(
      consentApi: _FakeCaregiverConsentApiClient(),
    );

    final result = await service.verify(
      _sampleToken(),
      now: DateTime.utc(2027),
    );

    expect(result.valid, isFalse);
    expect(result.reason, 'Consent token expired');
  });
}