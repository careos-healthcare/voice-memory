import 'package:archiveme_mobile/core/config/v1_feature_flags.dart' show V1FeatureFlags;
import 'package:archiveme_mobile/core/config/v1_navigation_guard.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Redirect-only routes for quarantined non-V1 paths.
///
/// Keeps deep links and legacy URLs stable without importing lab screens into
/// the production router graph when [V1FeatureFlags.enableV1Only] is true.
abstract final class V1QuarantineRedirects {
  V1QuarantineRedirects._();

  /// Paths that must never mount a screen in the V1 production graph.
  static List<String> get exactPaths => V1RouteRegistry.quarantinedExactPaths;

  static List<String> get parameterizedPaths =>
      V1RouteRegistry.parameterizedQuarantinePaths;

  static String redirectTarget(String path) {
    final guarded = V1NavigationGuard.redirectFor(path);
    if (guarded != null) return guarded;
    return V1RouteRegistry.canonicalRedirectFor(path);
  }

  static GoRoute redirectRoute({
    required String path,
    required GlobalKey<NavigatorState> parentNavigatorKey,
  }) {
    return GoRoute(
      path: path,
      parentNavigatorKey: parentNavigatorKey,
      redirect: (context, state) => redirectTarget(state.uri.path),
    );
  }

  static List<GoRoute> routes({
    required GlobalKey<NavigatorState> rootNavigatorKey,
  }) {
    return [
      for (final path in exactPaths)
        redirectRoute(path: path, parentNavigatorKey: rootNavigatorKey),
      for (final path in parameterizedPaths)
        redirectRoute(path: path, parentNavigatorKey: rootNavigatorKey),
    ];
  }
}

/// Mirrors [V1QuarantineRedirects] for inventory reporting without importing
/// go_router in the inventory module.
abstract final class V1QuarantineRedirectRouteCount {
  static int get exact => V1RouteRegistry.quarantinedExactPaths.length;
  static int get parameterized =>
      V1RouteRegistry.parameterizedQuarantinePaths.length;
}
