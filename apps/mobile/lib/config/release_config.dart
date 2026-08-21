import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/config/production_navigation.dart';
import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/router/developer_route_guard.dart';
import 'package:flutter/foundation.dart';

/// Release-build guards for screenshot mode, developer routes, and trial surfaces.
abstract class ReleaseConfig {
  ReleaseConfig._();

  /// Screenshot captures require an explicit compile-time define.
  static bool get screenshotCaptureActive => ScreenshotMode.enabled;

  /// Screenshot mode is off in release unless the define is set at build time.
  static bool get screenshotAllowedInThisBuild =>
      !kReleaseMode || screenshotCaptureActive;

  /// Developer / QA routes (trial control, RevenueCat verify, etc.).
  static bool isDeveloperRoute(String path) {
    final normalized = path.split('?').first;
    if (ProductionNavigation.isDebugOnlyRoute(normalized)) return true;
    if (DeveloperRouteGuard.developerOnlyPaths.contains(normalized)) {
      return true;
    }
    return _isDeveloperGuardPath(normalized);
  }

  static bool _isDeveloperGuardPath(String path) {
    if (path.startsWith('/archive-tool/')) return true;
    if (path.startsWith('/archive-explanation/')) return true;
    if (path.startsWith('/discover-yourself/chapter/')) return true;
    if (path == '/archive-debug') return true;
    return false;
  }

  /// Whether a developer-only route may open in this build.
  static bool developerRouteAccessible(String path) {
    if (!isDeveloperRoute(path)) return true;
    if (TrialMode.hideDeveloperSurfaces) return false;
    return DeveloperSettingsGate.canShowDeveloperSettings;
  }

  /// Trial control is never a consumer release surface.
  static bool get trialControlAccessible =>
      TrialMode.enabled && DeveloperSettingsGate.canShowDeveloperSettings;

  /// Trial participants and focused-beta (billing frozen) skip billing init.
  static bool get billingRequired =>
      V1BillingCapability.isEnabled && !TrialMode.isLocalOnly;
}