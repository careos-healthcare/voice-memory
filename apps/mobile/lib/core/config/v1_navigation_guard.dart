import 'package:archiveme_mobile/core/config/v1_feature_flags.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';

/// Strict V1 router allowlist — blocks non-core deep links and nav entries.
abstract final class V1NavigationGuard {
  V1NavigationGuard._();

  static const String recordHome = RouteCatalog.recordHome;
  static const String archiveHome = RouteCatalog.archiveHome;
  static const String changesHome = RouteCatalog.changesHome;

  /// Non-core routes blocked while [V1FeatureFlags.enableV1Only] is true.
  static Set<String> get blockedFeatureRoutes => V1RouteRegistry.allQuarantinedPaths;

  /// Returns a redirect target when [path] is outside the V1 allowlist.
  static String? redirectFor(String path) {
    if (!V1FeatureFlags.enableV1Only) return null;

    final normalized = _normalize(path);

    final billingRedirect = V1RouteRegistry.billingCapabilityRedirect(
      normalized,
    );
    if (billingRedirect != null) return billingRedirect;
    // Billing is on: do not treat these as generic unknown routes. A future
    // pass may mount builders; this pass still has no PaywallScreen.
    if (V1RouteRegistry.billingExactPaths.contains(normalized)) return null;

    if (_isAllowed(normalized)) return null;

    return _fallbackFor(normalized);
  }

  /// Whether [route] may appear in drawers, settings rows, or quick links.
  static bool isNavRouteVisible(String route) {
    if (!V1FeatureFlags.enableV1Only) return true;
    return _isAllowed(_normalize(route));
  }

  static bool isAllowed(String path) {
    if (!V1FeatureFlags.enableV1Only) return true;
    return _isAllowed(_normalize(path));
  }

  static bool _isAllowed(String path) {
    if (V1RouteRegistry.exactAllowlistedPaths.contains(path)) return true;
    for (final prefix in V1RouteRegistry.prefixPaths) {
      if (path.startsWith(prefix)) return true;
    }
    return false;
  }

  static String _fallbackFor(String path) {
    if (path == '/archive-export') return V1RouteRegistry.exportPath;
    if (_recordFallbackExact.contains(path)) return recordHome;
    for (final prefix in _recordFallbackPrefixes) {
      if (path.startsWith(prefix)) return recordHome;
    }
    return V1RouteRegistry.canonicalRedirectFor(path);
  }

  static const Set<String> _recordFallbackExact = {
    '/pressure-check-in',
    '/pressure-insights',
    '/loop-mode',
    '/quick-yes-capture',
    '/live-voice',
    '/start',
    '/start/capacity-yes',
    '/start/prove-enough',
    '/start/generic',
    '/invite',
  };

  static const List<String> _recordFallbackPrefixes = [
    '/record',
    '/quick-capture',
  ];

  static String _normalize(String path) {
    if (path.isEmpty) return '/';
    final uri = Uri.tryParse(path);
    if (uri != null && uri.path.isNotEmpty) return uri.path;
    return path.split('?').first;
  }
}
