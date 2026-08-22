import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/caregiver_consent_api_client.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_access_service.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_audit_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:archiveme_mobile/features/consent_audit/consent_revocation_store.dart';
import 'package:archiveme_mobile/features/privacy/database_biometric_gate_store.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:archiveme_mobile/security/app_lock_service.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/services/analytics_service.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/ui/screens/settings/privacy_security_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../helpers/app_provider_scope.dart';
import 'privacy_security_analytics_test.mocks.dart';

@GenerateMocks([AnalyticsService, CaregiverAccessService])
void main() {
  late MockAnalyticsService mockAnalytics;
  late MockCaregiverAccessService mockCaregiverService;

  setUp(() {
    mockAnalytics = MockAnalyticsService();
    mockCaregiverService = MockCaregiverAccessService();
    AnalyticsServices.testOverride = mockAnalytics;

    when(mockCaregiverService.loadOverview()).thenAnswer(
      (_) async => CaregiverAccessOverview(
        activeGrants: [
          CaregiverActiveGrant(
            tokenId: 'token_123',
            caregiverId: 'Heather',
            subjectAccountId: 'subject_123',
            grantedAt: DateTime.utc(2026, 8, 1),
          ),
        ],
        accessLog: const [],
      ),
    );
  });

  tearDown(() async {
    AnalyticsServices.resetForTest();
    await DatabaseBiometricGateStore.resetForTest();
    SecureSqliteLockService.encryptionEnabled = false;
    SecureSqliteLockService.instanceForTest = null;
    PrivacySecurityEngagementAnalytics.resetForTest();
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverModeController.resetForTest();
    await ConsentRevocationStore.resetForTest();
  });

  Future<void> _configureCaregiverModeForRevoke() async {
    final prefs = await MobilePrefsStore.open(
      'test/tmp/privacy_security_analytics_mockito/prefs.json',
    );
    CaregiverFeatureFlags.debugOverride = true;
    CaregiverModeController.configure(
      prefs,
      verification: ConsentVerificationService(
        consentApi: _StubCaregiverConsentApiClient(),
      ),
    );
    await CaregiverModeController.instance.activateWithToken(
      MonitoringConsentToken(
        tokenId: 'token_123',
        subjectAccountId: 'subject_123',
        caregiverId: 'Heather',
        permissions: CaregiverPermissions.defaultScopes,
        issuedAt: DateTime.utc(2026, 8, 1),
        expiresAt: DateTime.utc(2026, 12, 31),
        policyVersion: ConsentVerificationService.currentPolicyVersion,
        signature: 'server-signature',
      ),
    );
  }

  Widget buildTestableWidget() {
    return withAppProviderScope(
      MaterialApp(
        theme: AppTheme.light(),
        home: PrivacySecurityScreen(
          accessService: mockCaregiverService,
        ),
      ),
    );
  }

  Future<void> expandPillar(WidgetTester tester, String cardId) async {
    await tester.tap(find.byKey(Key('privacy_pillar_expansion_$cardId')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> waitForKey(WidgetTester tester, Key key) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      if (find.byKey(key).evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $key');
  }

  group('PrivacySecurityScreen Analytics Events', () {
    testWidgets(
      'expanding Encryption Pillar card dispatches trust_card_expanded',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableWidget());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final pillar3Tile = find.byKey(
          const Key(
            'privacy_pillar_expansion_${PrivacySecurityEngagementAnalytics.pillar3EncryptionCardId}',
          ),
        );
        expect(pillar3Tile, findsOneWidget);

        await expandPillar(
          tester,
          PrivacySecurityEngagementAnalytics.pillar3EncryptionCardId,
        );

        verify(
          mockAnalytics.logEvent(
            'trust_card_expanded',
            argThat(
              predicate<Map<String, Object>>(
                (params) =>
                    params['card_id'] ==
                    PrivacySecurityEngagementAnalytics.pillar3EncryptionCardId,
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'toggling biometric switch dispatches biometric_enforcement_toggled',
      (WidgetTester tester) async {
        SecureSqliteLockService.encryptionEnabled = true;
        SecureSqliteLockService.instanceForTest = SecureSqliteLockService(
          biometrics: _MockBiometricAuthenticator(),
        );
        DatabaseBiometricGateStore.seedForTest(enabled: false);

        await tester.pumpWidget(buildTestableWidget());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await expandPillar(
          tester,
          PrivacySecurityEngagementAnalytics.pillar3EncryptionCardId,
        );

        final biometricSwitch =
            find.byKey(const Key('biometric_security_gate_toggle'));
        expect(biometricSwitch, findsOneWidget);

        await tester.tap(biometricSwitch);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          mockAnalytics.logEvent(
            'biometric_enforcement_toggled',
            argThat(
              predicate<Map<String, Object>>(
                (params) => params['enabled'] == true,
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'revoking caregiver token dispatches caregiver_token_revoked',
      (WidgetTester tester) async {
        await tester.runAsync(_configureCaregiverModeForRevoke);

        await tester.pumpWidget(buildTestableWidget());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await expandPillar(
          tester,
          PrivacySecurityEngagementAnalytics.pillar4CaregiverCardId,
        );

        await waitForKey(
          tester,
          const Key('caregiver_revoke_access_token_123'),
        );

        final revokeButton =
            find.byKey(const Key('caregiver_revoke_access_token_123'));
        expect(revokeButton, findsOneWidget);

        await tester.tap(revokeButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.byKey(const Key('caregiver_revoke_confirm_dialog_token_123')),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(
            of: find.byKey(
              const Key('caregiver_revoke_confirm_dialog_token_123'),
            ),
            matching: find.byKey(
              const Key('caregiver_revoke_confirm_token_123'),
            ),
          ),
        );
        await tester.pump();

        verify(
          mockAnalytics.logEvent(
            'caregiver_token_revoked',
            argThat(
              predicate<Map<String, Object>>(
                (params) => params['token_id'] == 'token_123',
              ),
            ),
          ),
        ).called(1);
      },
    );
  });
}

class _MockBiometricAuthenticator implements BiometricAuthenticator {
  @override
  Future<bool> available() async => true;

  @override
  Future<bool> authenticate(String reason) async => true;
}

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
        tokenId: 'token_123',
        subjectAccountId: subjectAccountId,
        caregiverId: caregiverId,
        permissions: permissions,
        issuedAt: DateTime.utc(2026, 8, 1),
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
          sessionId: 'session-mockito-1',
          mode: AppMode.caregiverMonitoring,
          caregiverId: token.caregiverId,
          subjectAccountId: token.subjectAccountId,
          permissions: token.permissions,
          tokenId: token.tokenId,
          startedAt: DateTime.utc(2026, 8, 1),
          expiresAt: token.expiresAt,
          validatedAt: DateTime.utc(2026, 8, 1),
        ),
      ),
    );
  }
}
