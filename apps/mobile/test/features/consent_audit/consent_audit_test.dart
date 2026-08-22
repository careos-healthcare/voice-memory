import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/caregiver_consent_api_client.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:archiveme_mobile/features/consent_audit/consent_revocation_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCaregiverConsentApiClient implements CaregiverConsentApiClient {
  @override
  Future<ApiResult<MonitoringConsentToken>> issueToken({
    required String subjectAccountId,
    required String caregiverId,
    required CaregiverPermissions permissions,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<CaregiverTokenVerificationResult>> verifyToken({
    required MonitoringConsentToken token,
    NetworkCancelToken? cancelToken,
  }) async {
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
}

MonitoringConsentToken _token() {
  return MonitoringConsentToken(
    tokenId: 'token-revoke-test',
    subjectAccountId: 'subject-1',
    caregiverId: 'caregiver-1',
    permissions: CaregiverPermissions.defaultScopes,
    issuedAt: DateTime.utc(2026),
    expiresAt: DateTime.utc(2026, 12, 31),
    policyVersion: ConsentVerificationService.currentPolicyVersion,
    signature: 'server-signature',
  );
}

void main() {
  setUp(() async {
    await ConsentRevocationStore.resetForTest();
    await ConsentRevocationStore.ensureLoaded();
  });

  test('revoked token fails verification on next access', () async {
    final service = ConsentVerificationService(
      consentApi: _FakeCaregiverConsentApiClient(),
    );
    final token = _token();

    final before = await service.verify(token, now: DateTime.utc(2026, 2));
    expect(before.valid, isTrue);

    await ConsentRevocationStore.revoke(token.tokenId);

    final after = await service.verify(token, now: DateTime.utc(2026, 2));
    expect(after.valid, isFalse);
    expect(after.reason, 'Consent token revoked');
  });
}
