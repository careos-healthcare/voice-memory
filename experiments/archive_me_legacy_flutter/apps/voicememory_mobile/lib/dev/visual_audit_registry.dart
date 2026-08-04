import 'dart:io' show Directory, Platform;

import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// Output root: `~/Desktop/upload1` on host (override via dart-define).
const String visualAuditOutputFromEnvironment = String.fromEnvironment(
  'VISUAL_AUDIT_OUTPUT_DIR',
);

/// Subfolders under the audit root.
abstract class VisualAuditFolders {
  static const screens = 'screens';
  static const record = 'record';
  static const archive = 'archive';
  static const timeline = 'timeline';
  static const search = 'search';
  static const changes = 'changes';
  static const account = 'account';
  static const pricing = 'pricing';
  static const export = 'export';
  static const debug = 'debug';
  static const dialogs = 'dialogs';
  static const bottomSheets = 'bottom_sheets';
  static const errors = 'errors';
  static const navigation = 'navigation';
  static const audit = 'audit';

  static const all = [
    screens,
    record,
    archive,
    timeline,
    search,
    changes,
    account,
    pricing,
    export,
    debug,
    dialogs,
    bottomSheets,
    errors,
    navigation,
    audit,
  ];
}

/// Planned capture for the audit runner.
class VisualAuditCapturePlan {
  const VisualAuditCapturePlan({
    required this.id,
    required this.filename,
    required this.folder,
    this.route,
    this.scrollable = false,
    this.debugOnly = false,
  });

  final String id;
  final String filename;
  final String folder;
  final String? route;
  final bool scrollable;
  final bool debugOnly;
}

class VisualAuditRouteSpec {
  const VisualAuditRouteSpec({
    required this.path,
    required this.folder,
    this.scrollable = false,
    this.debugOnly = false,
  });

  final String path;
  final String folder;
  final bool scrollable;
  final bool debugOnly;
}

/// Bottom navigation destinations (shell tabs).
const List<({String route, String label, String folder})>
visualAuditBottomNavTabs = [
  (route: '/record', label: 'Record', folder: VisualAuditFolders.record),
  (
    route: '/archive-belief',
    label: 'Archive',
    folder: VisualAuditFolders.archive,
  ),
  (route: '/account', label: 'Account', folder: VisualAuditFolders.account),
];

/// Labels / semantics that must not be tapped during crawl.
const List<String> visualAuditDangerTapPatterns = [
  'delete',
  'sign out',
  'sign-out',
  'purchase',
  'restore purchase',
  'restore purchases',
  'remove account',
  'delete account',
  'erase',
  'clear all',
];

/// Error-surface keywords scanned on each screen.
const List<String> visualAuditErrorSurfaceKeywords = [
  'error',
  'exception',
  'backend',
  'offline',
  'unavailable',
];

/// All navigable routes for audit (non-tab routes included).
List<VisualAuditRouteSpec> visualAuditRoutes({bool includeDebug = true}) {
  final debug = includeDebug && AppConfig.debugToolsEnabled;
  return [
    const VisualAuditRouteSpec(
      path: '/record',
      folder: VisualAuditFolders.record,
    ),
    const VisualAuditRouteSpec(
      path: '/archive-belief',
      folder: VisualAuditFolders.archive,
      scrollable: true,
    ),
    const VisualAuditRouteSpec(
      path: '/account',
      folder: VisualAuditFolders.account,
      scrollable: true,
    ),
    const VisualAuditRouteSpec(
      path: '/pricing',
      folder: VisualAuditFolders.pricing,
      scrollable: true,
    ),
    const VisualAuditRouteSpec(
      path: '/export',
      folder: VisualAuditFolders.export,
    ),
    const VisualAuditRouteSpec(
      path: '/self-discovery',
      folder: VisualAuditFolders.archive,
      scrollable: true,
    ),
    const VisualAuditRouteSpec(
      path: '/settings',
      folder: VisualAuditFolders.screens,
      scrollable: true,
    ),
    const VisualAuditRouteSpec(
      path: '/journal',
      folder: VisualAuditFolders.screens,
      scrollable: true,
    ),
    const VisualAuditRouteSpec(
      path: '/subscription',
      folder: VisualAuditFolders.pricing,
      scrollable: true,
    ),
    const VisualAuditRouteSpec(
      path: '/restore-purchases',
      folder: VisualAuditFolders.pricing,
    ),
    if (debug)
      const VisualAuditRouteSpec(
        path: '/native-push-verify',
        folder: VisualAuditFolders.debug,
        scrollable: true,
        debugOnly: true,
      ),
    if (debug)
      const VisualAuditRouteSpec(
        path: '/revenuecat-verify',
        folder: VisualAuditFolders.debug,
        scrollable: true,
        debugOnly: true,
      ),
  ];
}

String visualAuditHostRoot() {
  if (visualAuditOutputFromEnvironment.isNotEmpty) {
    return visualAuditOutputFromEnvironment;
  }
  final home = Platform.environment['HOME'] ?? '';
  if (home.isEmpty) return 'upload1';
  return '$home/Desktop/upload1';
}

Future<String> resolveVisualAuditRoot() async {
  if (visualAuditOutputFromEnvironment.isNotEmpty) {
    return visualAuditOutputFromEnvironment;
  }
  final home = Platform.environment['HOME'] ?? '';
  if (home.isNotEmpty) {
    return '$home/Desktop/upload1';
  }
  if (Platform.isAndroid) {
    final external = await getExternalStorageDirectory();
    if (external != null) {
      return '${external.path}/voicememory_visual_audit';
    }
  }
  final docs = await getApplicationDocumentsDirectory();
  return '${docs.path}/visual_audit';
}

String? androidVisualAuditAdbPullPath() {
  if (!Platform.isAndroid) return null;
  return '/storage/emulated/0/Android/data/${AppConfig.bundleId}/files/voicememory_visual_audit';
}

Future<void> ensureVisualAuditDirectories(String root) async {
  for (final name in VisualAuditFolders.all) {
    final dir = Directory('$root${Platform.pathSeparator}$name');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
}
