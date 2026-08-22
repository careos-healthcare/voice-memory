import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/config/production_navigation.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/config/release_config.dart';
import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:archiveme_mobile/router/developer_route_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(DeveloperSettingsGate.resetForTest);

  test('screenshot mode is off by default in tests', () {
    expect(ScreenshotMode.enabled, isFalse);
    expect(ReleaseConfig.screenshotCaptureActive, isFalse);
  });

  test('developer routes redirect when locked', () {
    DeveloperSettingsGate.resetForTest();
    expect(
      DeveloperRouteGuard.redirectFor('/trial-control'),
      '/archive-belief',
    );
    expect(
      DeveloperRouteGuard.redirectFor('/revenuecat-verify'),
      '/archive-belief',
    );
    expect(ReleaseConfig.developerRouteAccessible('/trial-control'), isFalse);
  });

  test('developer routes accessible when unlocked', () {
    DeveloperSettingsGate.applyLoadedUnlock(true);
    expect(DeveloperRouteGuard.redirectFor('/trial-control'), isNull);
    expect(ReleaseConfig.developerRouteAccessible('/trial-control'), isTrue);
  });

  test('trial control not accessible without trial mode', () {
    DeveloperSettingsGate.applyLoadedUnlock(true);
    expect(TrialMode.enabled, isFalse);
    expect(ReleaseConfig.trialControlAccessible, isFalse);
  });

  test('production navigation hides debug routes from nav', () {
    expect(ProductionNavigation.isNavRouteVisible('/trial-control'), isFalse);
    expect(
      ProductionNavigation.isNavRouteVisible('/revenuecat-verify'),
      isFalse,
    );
  });

  test('billing requirement follows capability registry', () {
    if (V1BillingCapability.isEnabled && !TrialMode.isLocalOnly) {
      expect(ReleaseConfig.billingRequired, isTrue);
    } else {
      expect(ReleaseConfig.billingRequired, isFalse);
    }
  });

  test(
    'production navigation redirects trial debug routes when trial hides dev',
    () {
      if (!TrialMode.hideDeveloperSurfaces) return;
      expect(
        ProductionNavigation.redirectAwayFromIncomplete('/trial-control'),
        '/record',
      );
    },
  );
}