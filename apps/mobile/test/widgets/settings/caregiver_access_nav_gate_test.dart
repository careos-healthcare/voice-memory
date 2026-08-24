import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/settings/ui/caregiver_consent_copy.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_trust_copy.dart';
import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:archiveme_mobile/screens/settings_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/settings/privacy_security_trust_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_provider_scope.dart';
import '../../support/test_storage_sandbox.dart';

/// Guards the ship gate in `docs/security/CAREGIVER_ACCESS_PRELAUNCH_BLOCKERS.md`:
/// no discoverable route into third-party archive access while the capability is
/// off. The `/caregiver-access` route itself stays registered — a grant issued
/// while the flag was on keeps verifying for its whole TTL, so the screen must
/// remain reachable by deep link even when nothing links to it.
void main() {
  tearDown(() {
    CaregiverFeatureFlags.debugOverride = null;
  });

  Future<void> pumpTrustSection(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            children: const [
              PrivacySecurityTrustSection(showOnDeviceLink: false),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('caregiver nav entries follow the capability flag', () {
    testWidgets('flag defaults to off so no caregiver entry point exists', (
      tester,
    ) async {
      CaregiverFeatureFlags.debugOverride = null;
      expect(
        V1CapabilityRegistry.caregiverMonitoring,
        isFalse,
        reason: 'VOICEMEMORY_ENABLE_CAREGIVER_MODE has no default value, so a '
            'shipped build must report the capability off',
      );

      await pumpTrustSection(tester);

      expect(
        find.byKey(const Key('privacy_security_trust_link_caregiver')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('privacy_security_trust_caregiver_block')),
        findsNothing,
      );
      expect(
        find.text(PrivacySecurityTrustCopy.linkCaregiverAccess),
        findsNothing,
      );
      expect(
        find.text(PrivacySecurityTrustCopy.caregiverAccessTitle),
        findsNothing,
      );
    });

    testWidgets('trust section still renders its other guarantees when off', (
      tester,
    ) async {
      CaregiverFeatureFlags.debugOverride = false;

      await pumpTrustSection(tester);

      expect(
        find.byKey(const Key('privacy_security_trust_section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('privacy_security_trust_encrypted_block')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('privacy_security_trust_link_security')),
        findsOneWidget,
      );
    });

    testWidgets('caregiver link and guarantee return when the flag is on', (
      tester,
    ) async {
      CaregiverFeatureFlags.debugOverride = true;

      await pumpTrustSection(tester);

      expect(
        find.byKey(const Key('privacy_security_trust_link_caregiver')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('privacy_security_trust_caregiver_block')),
        findsOneWidget,
      );
    });
  });

  group('Settings list caregiver tile follows the capability flag', () {
    late TestStorageSandbox sandbox;

    setUpAll(() {
      // `AppServices.resetForTest` starts `ConnectivityAwareNetworkSource`,
      // which throws `MissingPluginException` without this stub.
      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'check') return ['wifi'];
        return null;
      });
    });

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(
        journalPath: sandbox.journalPath,
        prefsPath: sandbox.prefsPath,
        skipRevenueCat: true,
      );
    });

    tearDown(() => sandbox.dispose());

    Future<void> pumpSettings(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tile is absent when the flag is off', (tester) async {
      CaregiverFeatureFlags.debugOverride = false;

      await pumpSettings(tester);

      expect(
        find.byKey(const Key('settings_caregiver_access_tile')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('settings_caregiver_consent_tile')),
        findsNothing,
      );
      expect(find.text(CaregiverConsentCopy.settingsTileTitle), findsNothing);
    });

    testWidgets('tile is present when the flag is on', (tester) async {
      CaregiverFeatureFlags.debugOverride = true;

      await pumpSettings(tester);

      expect(
        find.byKey(const Key('settings_caregiver_access_tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings_caregiver_consent_tile')),
        findsOneWidget,
      );
      expect(find.text(CaregiverConsentCopy.settingsTileTitle), findsOneWidget);
    });
  });
}
