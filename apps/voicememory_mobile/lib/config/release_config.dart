import 'package:flutter/foundation.dart';

import '../router/developer_route_guard.dart';
import 'developer_settings_gate.dart';
import 'production_navigation.dart';
import 'screenshot_mode.dart';
import 'trial_mode.dart';

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

  /// Trial participants skip billing initialization.
  static bool get billingRequired => !TrialMode.isLocalOnly;
}
