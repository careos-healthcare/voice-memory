import '../../router/route_catalog.dart';
import 'v1_feature_flags.dart';

/// Strict V1 router allowlist — blocks non-core deep links and nav entries.
abstract final class V1NavigationGuard {
  V1NavigationGuard._();

  static const String recordHome = RouteCatalog.recordHome;
  static const String archiveHome = RouteCatalog.archiveHome;
  static const String changesHome = RouteCatalog.changesHome;

  static const Set<String> _exactAllowed = {
    '/',
    ...RouteCatalog.primaryRoutes,
    '/details',
    '/settings',
    '/subscription',
    '/pricing',
    '/restore-purchases',
    '/delete-account',
    '/privacy-trust-centre',
    '/privacy',
    '/terms',
    '/about',
    '/security',
    '/support-feedback',
    '/sample-archive',
    '/help-reviewer-guide',
    '/testing-archiveme',
    '/belief-evidence',
    '/belief-detail',
    '/quick-capture',
    '/quick-yes-capture',
    '/live-voice',
    '/onboarding',
    '/onboarding-intent',
    '/onboarding-loop',
    '/future-preview',
    '/cold-start/seed',
    '/start',
    '/invite',
    '/start/capacity-yes',
    '/start/prove-enough',
    '/start/generic',
  };

  static const List<String> _prefixAllowed = [
    '/entry/',
    '/sample-archive/context/',
    '/archive-evidence-map/context/',
    '/account/',
  ];

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
  static const Set<String> blockedFeatureRoutes = {
    '/pattern-map',
    '/pattern-profile',
    '/pattern-recognition',
    '/action-items',
    '/archive-review',
    '/weekly-archive-review',
    '/prove-enough/monthly-review',
    '/insight-quality',
    '/archive-timeline',
    '/ask-archive',
    '/archive-cleanup',
    '/moments',
    '/journal',
    '/archive-journey',
    '/archive-share',
    '/archive-deep-dive',
    '/weekly-story',
    '/updates',
    '/export',
    '/archive-export',
    '/archive-packs',
    '/collections',
    '/pinned-evidence',
    '/yesterdays-snapshot',
    '/review-ritual',
    '/archive-calendar',
  };

  /// Returns a redirect target when [path] is outside the V1 allowlist.
  static String? redirectFor(String path) {
    if (!V1FeatureFlags.enableV1Only) return null;

    final normalized = _normalize(path);
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
    if (_exactAllowed.contains(path)) return true;
    for (final prefix in _prefixAllowed) {
      if (path.startsWith(prefix)) return true;
    }
    return false;
  }

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
