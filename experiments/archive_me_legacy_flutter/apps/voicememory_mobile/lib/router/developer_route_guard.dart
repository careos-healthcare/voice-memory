import '../config/developer_settings_gate.dart';
import 'legacy_route_aliases.dart';
import 'route_catalog.dart';

/// Consumer-safe redirects for legacy and internal routes.
abstract class DeveloperRouteGuard {
  DeveloperRouteGuard._();

  static const patternsHome = RouteCatalog.archiveHome;
  static const legacyRedirects = LegacyRouteAliases.redirects;

  static const developerOnlyPaths = <String>{
    '/developer-diagnostics',
    '/first-pattern-quality',
    '/trial-control',
    '/revenuecat-verify',
    '/restore-production-verify',
    '/native-push-verify',
    '/offline-sync-verify',
    '/archive-deep-dive',
    '/archive-share',
    '/archive-evidence-trail',
    '/archive-journey',
    '/journal',
    '/weekly-story',
    '/updates',
    '/subscription-review-preview',
  };

  /// Returns redirect target when [path] must not be shown.
  static String? redirectFor(String path) {
    final normalized = _normalize(path);

    final legacy = legacyRedirects[normalized];
    if (legacy != null) return legacy;
    if (normalized.startsWith('/discover-yourself/')) return patternsHome;

    if (_isDeveloperOnly(normalized) && !DeveloperSettingsGate.isUnlocked) {
      return patternsHome;
    }

    return null;
  }

  static bool _isDeveloperOnly(String path) {
    if (developerOnlyPaths.contains(path)) return true;
    if (path.startsWith('/archive-tool/')) return true;
    if (path.startsWith('/archive-explanation/')) return true;
    if (path == '/archive-debug') return true;
    return false;
  }

  static String _normalize(String path) {
    if (path.isEmpty) return '/';
    final uri = Uri.tryParse(path);
    if (uri != null && uri.path.isNotEmpty) return uri.path;
    return path.split('?').first;
  }
}
