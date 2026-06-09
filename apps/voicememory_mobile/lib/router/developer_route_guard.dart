import '../config/developer_settings_gate.dart';

/// Consumer-safe redirects for legacy and internal routes.
abstract final class DeveloperRouteGuard {
  DeveloperRouteGuard._();

  static const patternsHome = '/archive-belief';

  static const legacyRedirects = <String, String>{
    '/timeline': patternsHome,
    '/search': patternsHome,
    '/discover': patternsHome,
    '/discover-changes': patternsHome,
    '/memory': patternsHome,
    '/archive-detail': patternsHome,
  };

  static const developerOnlyPaths = <String>{
    '/developer-diagnostics',
    '/first-pattern-quality',
    '/trial-control',
    '/revenuecat-verify',
    '/restore-production-verify',
    '/native-push-verify',
    '/offline-sync-verify',
    '/archive-analyst',
    '/archive-deep-dive',
    '/archive-share',
    '/archive-evidence-trail',
    '/archive-journey',
    '/blind-spots',
    '/journal',
    '/archive-identity',
    '/archive-life-chapters',
    '/weekly-story',
    '/updates',
    '/subscription-review-preview',
  };

  /// Returns redirect target when [path] must not be shown.
  static String? redirectFor(String path) {
    final normalized = _normalize(path);

    final legacy = legacyRedirects[normalized];
    if (legacy != null) return legacy;

    if (_isDeveloperOnly(normalized) && !DeveloperSettingsGate.isUnlocked) {
      return patternsHome;
    }

    return null;
  }

  static bool _isDeveloperOnly(String path) {
    if (developerOnlyPaths.contains(path)) return true;
    if (path.startsWith('/archive-tool/')) return true;
    if (path.startsWith('/archive-explanation/')) return true;
    if (path.startsWith('/discover-yourself/chapter/')) return true;
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
