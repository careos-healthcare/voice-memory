import 'package:archiveme_mobile/features/auth/domain/caregiver_access_copy.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_access_service.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/consent_audit/consent_revocation_store.dart';
import 'package:archiveme_mobile/features/privacy/database_biometric_gate_store.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_control_center_copy.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:archiveme_mobile/security/app_lock_service.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/services/analytics_service.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/features/settings/screens/privacy_security_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  /// The screen is a lazy `ListView`; on the default 800x600 surface the
  /// pillars below the on-device section are never built and every finder
  /// silently reports nothing.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      withAppProviderScope(
        MaterialApp(
          theme: AppTheme.light(),
          home: PrivacySecurityScreen(accessService: mockCaregiverService),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Taps the section header, not the section: the center of an expanded
  /// `ExpansionTile` lands on its children rather than on the header row.
  /// Pumped past the expand animation because `ExpansionTile` keeps its
  /// children mounted until the controller is fully dismissed.
  Future<void> toggleEncryptionSection(WidgetTester tester) async {
    await tester.tap(
      find.text(PrivacySecurityControlCenterCopy.pillar3Heading),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('PrivacySecurityScreen encryption status', () {
    testWidgets('encryption card is readable without expanding anything', (
      tester,
    ) async {
      SecureSqliteLockService.encryptionEnabled = true;

      await pumpScreen(tester);

      // No tap: this screen is the only surface reporting live encryption
      // state, so the card must be there on arrival.
      expect(find.byKey(const Key('encryption_status_card')), findsOneWidget);
      expect(
        find.text(PrivacySecurityControlCenterCopy.encryptionActiveLabel),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('encryption_status_active_badge')),
        findsOneWidget,
      );
    });

    testWidgets('card follows the live service instead of a fixed claim', (
      tester,
    ) async {
      SecureSqliteLockService.encryptionEnabled = false;

      await pumpScreen(tester);

      expect(find.byKey(const Key('encryption_status_card')), findsOneWidget);
      expect(
        find.text(PrivacySecurityControlCenterCopy.encryptionInactiveLabel),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('encryption_status_active_badge')),
        findsNothing,
      );
    });

    testWidgets('the section still collapses and reports the toggle', (
      tester,
    ) async {
      await pumpScreen(tester);

      await toggleEncryptionSection(tester);

      expect(find.byKey(const Key('encryption_status_card')), findsNothing);
      verify(
        mockAnalytics.logEvent(
          'trust_card_expanded',
          argThat(
            predicate<Map<String, Object>>(
              (params) =>
                  params['card_id'] ==
                      PrivacySecurityEngagementAnalytics
                          .pillar3EncryptionCardId &&
                  params['expanded'] == false,
            ),
          ),
        ),
      ).called(1);

      await toggleEncryptionSection(tester);

      expect(find.byKey(const Key('encryption_status_card')), findsOneWidget);
      verify(
        mockAnalytics.logEvent(
          'trust_card_expanded',
          argThat(
            predicate<Map<String, Object>>(
              (params) =>
                  params['card_id'] ==
                      PrivacySecurityEngagementAnalytics
                          .pillar3EncryptionCardId &&
                  params['expanded'] == true,
            ),
          ),
        ),
      ).called(1);
    });
  });

  group('PrivacySecurityScreen Analytics Events', () {
    testWidgets(
      'toggling biometric switch dispatches biometric_enforcement_toggled',
      (tester) async {
        SecureSqliteLockService.encryptionEnabled = true;
        SecureSqliteLockService.instanceForTest = SecureSqliteLockService(
          biometrics: _MockBiometricAuthenticator(),
        );
        DatabaseBiometricGateStore.seedForTest(enabled: false);

        await pumpScreen(tester);

        final biometricSwitch = find.byKey(
          const Key('biometric_security_gate_toggle'),
        );
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
  });

  group('PrivacySecurityScreen caregiver access link', () {
    /// Grants are managed on `/caregiver-access`; this screen only links there.
    /// The destination is a sentinel so the assertion is about navigation
    /// rather than about the caregiver screen's own dependencies.
    Future<void> pumpRouted(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/privacy-security',
        routes: [
          GoRoute(
            path: '/privacy-security',
            builder: (context, state) =>
                PrivacySecurityScreen(accessService: mockCaregiverService),
          ),
          GoRoute(
            path: '/caregiver-access',
            builder: (context, state) => const Scaffold(
              key: Key('caregiver_access_route_destination'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('link is absent while the capability is off', (tester) async {
      CaregiverFeatureFlags.debugOverride = false;

      await pumpScreen(tester);

      expect(
        find.byKey(const Key('privacy_security_caregiver_access_link')),
        findsNothing,
      );
      expect(find.text(CaregiverAccessCopy.settingsTitle), findsNothing);
    });

    testWidgets('link renders and navigates while the capability is on', (
      tester,
    ) async {
      CaregiverFeatureFlags.debugOverride = true;

      await pumpRouted(tester);

      final link = find.byKey(
        const Key('privacy_security_caregiver_access_link'),
      );
      expect(link, findsOneWidget);
      expect(find.text(CaregiverAccessCopy.settingsTitle), findsOneWidget);

      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('caregiver_access_route_destination')),
        findsOneWidget,
      );
    });
  });

  /// These four strings had no reader anywhere in `lib/` or `test/` while
  /// `pillar4ExplanationBody` described what a caregiver grant is and how it
  /// ends. Asserting the render path is the point of the group: a claim about
  /// consent that no widget builds is a claim nobody can check.
  group('PrivacySecurityScreen caregiver pillar', () {
    testWidgets('heading and grant summary render while the capability is on', (
      tester,
    ) async {
      CaregiverFeatureFlags.debugOverride = true;

      await pumpScreen(tester);

      expect(
        find.text(PrivacySecurityControlCenterCopy.pillar4Heading),
        findsOneWidget,
      );
      expect(
        find.text(PrivacySecurityControlCenterCopy.caregiverSectionSubtitle),
        findsOneWidget,
      );
    });

    testWidgets('"why am I seeing this" opens the caregiver explanation', (
      tester,
    ) async {
      CaregiverFeatureFlags.debugOverride = true;

      await pumpScreen(tester);

      await tester.tap(
        find.byKey(
          const Key(
            'privacy_pillar_why_'
            '${PrivacySecurityEngagementAnalytics.pillar4CaregiverCardId}',
          ),
        ),
      );
      // Explicit pumps rather than `pumpAndSettle`: the biometric tile keeps a
      // progress indicator spinning while it resolves hardware support, so the
      // tree never reaches a settled frame on this screen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text(PrivacySecurityControlCenterCopy.pillar4ExplanationTitle),
        findsWidgets,
      );
      expect(
        find.text(PrivacySecurityControlCenterCopy.pillar4ExplanationBody),
        findsOneWidget,
      );
      verify(
        mockAnalytics.logEvent(
          'trust_explanation_viewed',
          argThat(
            predicate<Map<String, Object>>(
              (params) =>
                  params['pillar_id'] ==
                  PrivacySecurityEngagementAnalytics.pillar4CaregiverCardId,
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('the whole pillar is gated with the capability', (tester) async {
      CaregiverFeatureFlags.debugOverride = false;

      await pumpScreen(tester);

      expect(
        find.text(PrivacySecurityControlCenterCopy.pillar4Heading),
        findsNothing,
      );
      expect(
        find.text(PrivacySecurityControlCenterCopy.caregiverSectionSubtitle),
        findsNothing,
      );
    });
  });
}

class _MockBiometricAuthenticator implements BiometricAuthenticator {
  @override
  Future<bool> available() async => true;

  @override
  Future<bool> authenticate(String reason) async => true;
}
