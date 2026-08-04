import '../../product/archive_me_v1_product_contract.dart';
import '../../router/route_catalog.dart';
import 'v1_feature_flags.dart';

/// Strict V1 router allowlist — blocks non-core deep links and nav entries.
abstract final class V1NavigationGuard {
  V1NavigationGuard._();

  static const String recordHome = RouteCatalog.recordHome;
  static const String archiveHome = RouteCatalog.archiveHome;
  static const String changesHome = RouteCatalog.changesHome;

  static const Set<String> _recordFallbackExact = {
    '/pressure-check-in',
    '/pressure-insights',
    '/loop-mode',
  };

  static const List<String> _recordFallbackPrefixes = [
    '/record',
    '/quick-capture',
    '/live-voice',
  ];

  /// Non-core routes blocked while [V1FeatureFlags.enableV1Only] is true.
  static const Set<String> blockedFeatureRoutes =
      ArchiveMeV1ProductContract.excludedConsumerRoutes;

  /// Returns a redirect target when [path] is outside the V1 allowlist.
  static String? redirectFor(String path) {
    if (!V1FeatureFlags.enableV1Only) return null;

    final normalized = _normalize(path);
    if (blockedFeatureRoutes.contains(normalized)) {
      return _fallbackFor(normalized);
    }
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

  static bool _isAllowed(String path) =>
      ArchiveMeV1ProductContract.isConsumerRouteAllowed(path);

  static String _fallbackFor(String path) {
    if (_recordFallbackExact.contains(path)) return recordHome;
    for (final prefix in _recordFallbackPrefixes) {
      if (path.startsWith(prefix)) return recordHome;
    }
    return archiveHome;
  }

  static String _normalize(String path) {
    if (path.isEmpty) return '/';
    final uri = Uri.tryParse(path);
    if (uri != null && uri.path.isNotEmpty) return uri.path;
    return path.split('?').first;
  }
}
