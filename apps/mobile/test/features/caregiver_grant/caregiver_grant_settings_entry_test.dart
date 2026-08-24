// Drives the real Settings screen rather than the widget in isolation, so the
// insertion is proven to be reachable where a user would look for it.
//
// The surface is stretched to 4000px on purpose: the default 800x600 test
// window leaves a lazy `ListView` never building its offscreen children, and a
// finder then reports the entry point missing when it is only unbuilt.
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_copy.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_disclosure_screen.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_entry_point.dart';
import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:archiveme_mobile/screens/settings_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_provider_scope.dart';
import '../../support/test_storage_sandbox.dart';

void main() {
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

  tearDown(() {
    CaregiverFeatureFlags.debugOverride = null;
    sandbox.dispose();
  });

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

  testWidgets('the grant entry point is absent while the capability is off',
      (tester) async {
    CaregiverFeatureFlags.debugOverride = false;

    await pumpSettings(tester);

    expect(find.byKey(CaregiverEntryPoint.cardKey), findsNothing);
    expect(find.byKey(CaregiverEntryPoint.actionKey), findsNothing);
    expect(find.text(CaregiverGrantCopy.entryTitle), findsNothing);
  });

  testWidgets('the grant entry point appears once the capability is on',
      (tester) async {
    CaregiverFeatureFlags.debugOverride = true;

    await pumpSettings(tester);

    expect(find.byKey(CaregiverEntryPoint.cardKey), findsOneWidget);
    expect(find.byKey(CaregiverEntryPoint.actionKey), findsOneWidget);
    expect(find.text(CaregiverGrantCopy.entryTitle), findsOneWidget);
  });

  testWidgets('it sits inside the Settings list, not floating in the tree',
      (tester) async {
    CaregiverFeatureFlags.debugOverride = true;

    await pumpSettings(tester);

    expect(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byKey(CaregiverEntryPoint.cardKey),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping the Settings entry opens CaregiverDisclosureScreen',
    (tester) async {
      CaregiverFeatureFlags.debugOverride = true;

      await pumpSettings(tester);

      await tester.tap(find.byKey(CaregiverEntryPoint.actionKey));
      await tester.pumpAndSettle();

      expect(find.byKey(CaregiverDisclosureScreen.screenKey), findsOneWidget);
      expect(find.text(CaregiverGrantCopy.canSeeRecent), findsOneWidget);
      expect(find.text(CaregiverGrantCopy.stopOnThisDevice), findsOneWidget);
      expect(find.text(CaregiverGrantCopy.stopPassLifetime), findsOneWidget);
      expect(find.textContaining('instantly severs'), findsNothing);
    },
  );

  test('catalog-only caregiver paths stay off the production registry', () {
    expect(V1RouteRegistry.caregiverAccessPath, '/caregiver-access');
    expect(V1RouteRegistry.supportingPaths, contains('/caregiver-access'));
    expect(V1RouteRegistry.supportingPaths, isNot(contains(RouteCatalog.caregiverHome)));
    expect(
      V1RouteRegistry.supportingPaths,
      isNot(contains(RouteCatalog.caregiverConsent)),
    );
  });

  test('disclosure copy names opening words and a local-then-server revoke', () {
    expect(CaregiverGrantCopy.canSeeRecent, contains('opening words'));
    expect(CaregiverGrantCopy.cannotAudio, contains('does not play your audio'));
    expect(CaregiverGrantCopy.stopOnThisDevice, contains('right away'));
    expect(CaregiverGrantCopy.stopPassLifetime, contains('7 days'));
    expect(CaregiverGrantCopy.stopReachesServer, contains('reconnect'));
    expect(
      CaregiverGrantCopy.all.join(' ').toLowerCase(),
      isNot(contains('instantly severs')),
    );
  });
}
