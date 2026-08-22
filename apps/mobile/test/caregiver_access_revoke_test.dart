import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/caregiver_consent_api_client.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:archiveme_mobile/features/consent_audit/consent_revocation_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubCaregiverConsentApiClient implements CaregiverConsentApiClient {
  @override
  Future<ApiResult<MonitoringConsentToken>> issueToken({
    required String subjectAccountId,
    required String caregiverId,
    required CaregiverPermissions permissions,
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(
      MonitoringConsentToken(
        tokenId: 'token-revoke-1',
        subjectAccountId: subjectAccountId,
        caregiverId: caregiverId,
        permissions: permissions,
        issuedAt: DateTime.utc(2026, 2, 1),
        expiresAt: DateTime.utc(2026, 12, 31),
        policyVersion: ConsentVerificationService.currentPolicyVersion,
        signature: 'server-signature',
      ),
    );
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
          sessionId: 'session-revoke-1',
          mode: AppMode.caregiverMonitoring,
          caregiverId: token.caregiverId,
          subjectAccountId: token.subjectAccountId,
          permissions: token.permissions,
          tokenId: token.tokenId,
          startedAt: DateTime.utc(2026, 2, 1),
          expiresAt: token.expiresAt,
          validatedAt: DateTime.utc(2026, 2, 1),
        ),
      ),
    );
  }
}

MonitoringConsentToken _testToken() => MonitoringConsentToken(
      tokenId: 'token-revoke-1',
      subjectAccountId: 'subject-1',
      caregiverId: 'caregiver-ada',
      permissions: CaregiverPermissions.defaultScopes,
      issuedAt: DateTime.utc(2026, 2, 1),
      expiresAt: DateTime.utc(2026, 12, 31),
      policyVersion: ConsentVerificationService.currentPolicyVersion,
      signature: 'server-signature',
    );

void main() {
  setUp(() async {
    CaregiverFeatureFlags.debugOverride = true;
    CaregiverModeController.resetForTest();
    await ConsentRevocationStore.resetForTest();
  });

  tearDown(() {
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverModeController.resetForTest();
  });

  Future<CaregiverModeController> configureController() async {
    final prefs = await MobilePrefsStore.open(
      'test/tmp/caregiver_access_revoke/prefs.json',
    );
    CaregiverModeController.configure(
      prefs,
      verification: ConsentVerificationService(
        consentApi: _StubCaregiverConsentApiClient(),
      ),
    );
    return CaregiverModeController.instance;
  }

  test('access overview lists active grant after consent', () async {
    final controller = await configureController();
    await controller.activateWithToken(_testToken());

    final overview = await controller.accessService.loadOverview();

    expect(overview.activeGrants, hasLength(1));
    expect(overview.activeGrants.single.caregiverId, 'caregiver-ada');
    expect(overview.activeGrants.single.isCurrentSession, isTrue);
    expect(overview.accessLog, isNotEmpty);
  });

  test('revokeGrant removes active grant and records audit entry', () async {
    final controller = await configureController();
    await controller.activateWithToken(_testToken());

    await controller.revokeGrant('token-revoke-1');

    final overview = await controller.accessService.loadOverview();
    expect(overview.activeGrants, isEmpty);
    expect(
      controller.auditStore.entries.where(
        (entry) =>
            entry.action == CaregiverAuditAction.consentRevoked &&
            entry.resourceId == 'token-revoke-1',
      ),
      isNotEmpty,
    );
    expect(controller.hasValidSession, isFalse);
    expect(ConsentRevocationStore.isRevoked('token-revoke-1'), isTrue);
  });
}
