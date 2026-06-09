import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/config/production_navigation.dart';
import 'package:voicememory_mobile/config/release_config.dart';
import 'package:voicememory_mobile/config/screenshot_mode.dart';
import 'package:voicememory_mobile/config/trial_mode.dart';
import 'package:voicememory_mobile/router/developer_route_guard.dart';

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
    expect(
      ProductionNavigation.isNavRouteVisible('/trial-control'),
      isFalse,
    );
    expect(
      ProductionNavigation.isNavRouteVisible('/revenuecat-verify'),
      isFalse,
    );
  });

  test('trial mode skips billing requirement', () {
    if (TrialMode.enabled) {
      expect(ReleaseConfig.billingRequired, isFalse);
    } else {
      expect(ReleaseConfig.billingRequired, isTrue);
    }
  });

  test('production navigation redirects trial debug routes when trial hides dev', () {
    if (!TrialMode.hideDeveloperSurfaces) return;
    expect(
      ProductionNavigation.redirectAwayFromIncomplete('/trial-control'),
      '/record',
    );
  });
}
