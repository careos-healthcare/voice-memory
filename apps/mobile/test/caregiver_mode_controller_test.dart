import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/caregiver_consent_api_client.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
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
        tokenId: 'token-1',
        subjectAccountId: subjectAccountId,
        caregiverId: caregiverId,
        permissions: permissions,
        issuedAt: DateTime.utc(2026),
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

void main() {
  setUp(() {
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverModeController.resetForTest();
  });

  tearDown(() {
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverModeController.resetForTest();
  });

  Future<CaregiverModeController> configureController() async {
    final prefs = await MobilePrefsStore.open(
      'test/tmp/caregiver_mode_controller/prefs.json',
    );
    CaregiverModeController.configure(
      prefs,
      verification: ConsentVerificationService(
        consentApi: _StubCaregiverConsentApiClient(),
      ),
    );
    return CaregiverModeController.instance;
  }

  test('redirects caregiver routes when feature flag is disabled', () async {
    CaregiverFeatureFlags.debugOverride = false;
    final controller = await configureController();

    expect(
      await controller.redirectFor(RouteCatalog.caregiverHome),
      RouteCatalog.recordHome,
    );
    expect(
      await controller.redirectFor(RouteCatalog.caregiverConsent),
      RouteCatalog.recordHome,
    );
  });

  test('activateWithToken fails when feature flag is disabled', () async {
    CaregiverFeatureFlags.debugOverride = false;
    final controller = await configureController();

    final result = await controller.activateWithToken(
      MonitoringConsentToken(
        tokenId: 'token-1',
        subjectAccountId: 'subject-1',
        caregiverId: 'caregiver-1',
        permissions: CaregiverPermissions.defaultScopes,
        issuedAt: DateTime.utc(2026),
        expiresAt: DateTime.utc(2026, 12, 31),
        policyVersion: ConsentVerificationService.currentPolicyVersion,
        signature: 'server-signature',
      ),
    );

    expect(result.valid, isFalse);
    expect(result.reason, contains('disabled'));
    expect(controller.activeMode, AppMode.selfReflection);
  });

  test('activateWithToken succeeds when feature flag is enabled', () async {
    CaregiverFeatureFlags.debugOverride = true;
    final controller = await configureController();

    final result = await controller.activateWithToken(
      MonitoringConsentToken(
        tokenId: 'token-1',
        subjectAccountId: 'subject-1',
        caregiverId: 'caregiver-1',
        permissions: CaregiverPermissions.defaultScopes,
        issuedAt: DateTime.utc(2026),
        expiresAt: DateTime.utc(2026, 12, 31),
        policyVersion: ConsentVerificationService.currentPolicyVersion,
        signature: 'server-signature',
      ),
    );

    expect(result.valid, isTrue);
    expect(controller.activeMode, AppMode.caregiverMonitoring);
    expect(controller.hasValidSession, isTrue);
  });
}