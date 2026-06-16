import 'dart:io' show Platform;

import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// Optional override from `flutter test --dart-define=SCREENSHOT_OUTPUT_DIR=...`
/// (e.g. macOS host run targeting `~/Desktop/uploads`).
const String screenshotOutputDirFromEnvironment = String.fromEnvironment(
  'SCREENSHOT_OUTPUT_DIR',
);

/// Dev-only route list for automated screenshot capture (not used in production).
class ScreenshotRouteTarget {
  const ScreenshotRouteTarget({
    required this.order,
    required this.route,
    required this.fileBase,
    this.scrollable = false,
    this.debugOnly = false,
  });

  final int order;
  final String route;
  final String fileBase;
  final bool scrollable;
  final bool debugOnly;
}

/// Default macOS output directory: ~/Desktop/uploads (sync; host only).
String screenshotOutputDirectory() {
  if (screenshotOutputDirFromEnvironment.isNotEmpty) {
    return screenshotOutputDirFromEnvironment;
  }
  final home = Platform.environment['HOME'] ?? '';
  if (home.isEmpty) {
    return '';
  }
  return '$home/Desktop/uploads';
}

/// Writable directory for the current runtime (host Mac or on-device).
Future<String> resolveScreenshotOutputDirectory() async {
  if (screenshotOutputDirFromEnvironment.isNotEmpty) {
    return screenshotOutputDirFromEnvironment;
  }

  final home = Platform.environment['HOME'] ?? '';
  if (home.isNotEmpty) {
    return '$home/Desktop/uploads';
  }

  if (Platform.isAndroid) {
    final external = await getExternalStorageDirectory();
    if (external != null) {
      return '${external.path}/voicememory_screenshots';
    }
  }

  final docs = await getApplicationDocumentsDirectory();
  return '${docs.path}/screenshots';
}

/// Relative path under Android external app storage (for `adb pull`).
String? androidScreenshotAdbPullPath() {
  if (!Platform.isAndroid) return null;
  return '/storage/emulated/0/Android/data/${AppConfig.bundleId}/files/voicememory_screenshots';
}

/// All major app routes for screenshot automation.
List<ScreenshotRouteTarget> screenshotRegistry({
  bool includeDebugRoutes = true,
}) {
  final debug = includeDebugRoutes && AppConfig.debugToolsEnabled;

  return [
    const ScreenshotRouteTarget(order: 1, route: '/record', fileBase: 'record'),
    const ScreenshotRouteTarget(
      order: 2,
      route: '/archive-belief',
      fileBase: 'archive',
      scrollable: true,
    ),
    const ScreenshotRouteTarget(
      order: 3,
      route: '/timeline',
      fileBase: 'timeline',
      scrollable: true,
    ),
    const ScreenshotRouteTarget(order: 4, route: '/search', fileBase: 'search'),
    const ScreenshotRouteTarget(
      order: 5,
      route: '/discover-yourself',
      fileBase: 'changes',
      scrollable: true,
    ),
    const ScreenshotRouteTarget(
      order: 6,
      route: '/account',
      fileBase: 'account',
      scrollable: true,
    ),
    const ScreenshotRouteTarget(
      order: 7,
      route: '/pricing',
      fileBase: 'pricing',
      scrollable: true,
    ),
    const ScreenshotRouteTarget(order: 8, route: '/export', fileBase: 'export'),
    const ScreenshotRouteTarget(
      order: 9,
      route: '/archive-identity',
      fileBase: 'archive_identity',
      scrollable: true,
    ),
    const ScreenshotRouteTarget(
      order: 10,
      route: '/archive-life-chapters',
      fileBase: 'archive_life_chapters',
      scrollable: true,
    ),
    const ScreenshotRouteTarget(
      order: 11,
      route: '/settings',
      fileBase: 'settings',
      scrollable: true,
    ),
    const ScreenshotRouteTarget(
      order: 12,
      route: '/journal',
      fileBase: 'journal',
      scrollable: true,
    ),
    const ScreenshotRouteTarget(
      order: 13,
      route: '/blind-spots',
      fileBase: 'blind_spots',
      scrollable: true,
    ),
    const ScreenshotRouteTarget(
      order: 14,
      route: '/subscription',
      fileBase: 'subscription',
      scrollable: true,
    ),
    const ScreenshotRouteTarget(
      order: 15,
      route: '/restore-purchases',
      fileBase: 'restore_purchases',
    ),
    if (debug)
      const ScreenshotRouteTarget(
        order: 16,
        route: '/native-push-verify',
        fileBase: 'native_push_verify',
        scrollable: true,
        debugOnly: true,
      ),
    if (debug)
      const ScreenshotRouteTarget(
        order: 17,
        route: '/revenuecat-verify',
        fileBase: 'revenuecat_verify',
        scrollable: true,
        debugOnly: true,
      ),
  ];
}
