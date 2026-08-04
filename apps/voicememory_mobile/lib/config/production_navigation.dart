import 'package:flutter/foundation.dart';

import '../core/config/v1_navigation_guard.dart';
import '../core/config/v1_feature_flags.dart';
import '../product/archive_me_v1_product_contract.dart';
import 'archive_tool_routes.dart';
import 'developer_settings_gate.dart';
import 'trial_mode.dart';

/// Routes and nav entries hidden in release builds (incomplete or dev-only copy).
class ProductionNavigation {
  ProductionNavigation._();

  static bool get hideIncompleteSurfaces => kReleaseMode;

  /// QA / verification — never available outside the developer settings gate.
  static const Set<String> debugOnlyRoutes = {
    '/native-push-verify',
    '/revenuecat-verify',
    '/restore-production-verify',
    '/offline-sync-verify',
    '/developer-diagnostics',
    '/first-pattern-quality',
    '/trial-control',
  };

  /// Paths that must not appear in drawers, sheets, or home quick links.
  static const Set<String> hiddenNavRoutes = {
    ...ArchiveToolRoutes.deferredToolPaths,
    ...debugOnlyRoutes,
  };

  static bool isDebugOnlyRoute(String route) => debugOnlyRoutes.contains(route);

  static bool isNavRouteVisible(String route) {
    if (V1FeatureFlags.enableV1Only &&
        !ArchiveMeV1ProductContract.isConsumerRouteAllowed(route)) {
      return false;
    }
    if (!V1NavigationGuard.isNavRouteVisible(route)) return false;
    if (isDebugOnlyRoute(route) &&
        !DeveloperSettingsGate.canShowDeveloperSettings) {
      return false;
    }
    if (ArchiveToolRoutes.isDeferred(route)) return false;
    if (!hideIncompleteSurfaces) return true;
    if (hiddenNavRoutes.contains(route)) return false;
    return true;
  }

  /// Redirect deep links away from incomplete archive tools and verification routes.
  static String? redirectAwayFromIncomplete(String path) {
    if (V1FeatureFlags.enableV1Only &&
        !ArchiveMeV1ProductContract.isConsumerRouteAllowed(path)) {
      return V1NavigationGuard.redirectFor(path);
    }
    final v1Redirect = V1NavigationGuard.redirectFor(path);
    if (v1Redirect != null) return v1Redirect;

    if (TrialMode.hideDeveloperSurfaces && isDebugOnlyRoute(path)) {
      return '/record';
    }
    if (isDebugOnlyRoute(path) &&
        !DeveloperSettingsGate.canShowDeveloperSettings) {
      return '/settings';
    }
    if (ArchiveToolRoutes.isDeferred(path)) return '/archive-belief';
    if (!hideIncompleteSurfaces) return null;
    if (hiddenNavRoutes.contains(path)) return '/settings';
    return null;
  }
}
