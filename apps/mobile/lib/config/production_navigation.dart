import 'package:archiveme_mobile/config/archive_tool_routes.dart';
import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:flutter/foundation.dart';

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