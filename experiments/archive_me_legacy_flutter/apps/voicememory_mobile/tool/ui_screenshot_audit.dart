import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voicememory_mobile/app.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/config/production_navigation.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/router/onboarding_gate.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';

import 'full_visual_audit.dart';

/// Host output root: `~/Desktop/upload12` (override via dart-define).
const String uiScreenshotAuditRootFromEnvironment = String.fromEnvironment(
  'UI_SCREENSHOT_AUDIT_ROOT',
);

const String uiScreenshotAuditScreenshotsSubdir = 'screenshots';

/// Parsed route from [lib/router/app_router.dart].
class UiRouterRouteEntry {
  const UiRouterRouteEntry({
    required this.path,
    this.redirectOnly = false,
    this.hasParameters = false,
    this.debugOnly = false,
    this.productionVisible = true,
  });

  final String path;
  final bool redirectOnly;
  final bool hasParameters;
  final bool debugOnly;
  final bool productionVisible;

  String get slug => path.replaceAll(RegExp(r'^/'), '').replaceAll('/', '-');

  String get suggestedFilename =>
      hasParameters ? '$slug-sample.png' : '$slug.png';
}

/// Inventory built from router source + production navigation rules.
class UiRouterInventory {
  UiRouterInventory({
    required this.sourcePath,
    required this.routes,
    required this.redirects,
    required this.parsedAt,
  });

  final String sourcePath;
  final List<UiRouterRouteEntry> routes;
  final List<({String from, String? to})> redirects;
  final DateTime parsedAt;

  List<UiRouterRouteEntry> get capturableRoutes =>
      routes.where((r) => !r.redirectOnly && r.productionVisible).toList();

  List<UiRouterRouteEntry> missingFromCapturePlan(List<String> capturedRoutes) {
    final captured = capturedRoutes.toSet();
    return capturableRoutes.where((r) => !captured.contains(r.path)).toList();
  }
}

/// One planned or completed screenshot.
class UiScreenshotRecord {
  UiScreenshotRecord({
    required this.filename,
    required this.route,
    required this.screenState,
    required this.capturedAt,
    this.filePath,
    this.error,
  });

  final String filename;
  final String route;
  final String screenState;
  final DateTime capturedAt;
  final String? filePath;
  final String? error;
}

/// Layout / UX finding from widget-tree analysis at capture time.
class UiAuditFinding {
  UiAuditFinding({
    required this.severity,
    required this.category,
    required this.message,
    required this.screenshot,
    this.route,
    this.recommendation,
  });

  final int severity;
  final String category;
  final String message;
  final String screenshot;
  final String? route;
  final String? recommendation;
}

/// Built-in inventory (kept in sync with [lib/router/app_router.dart]).
UiRouterInventory defaultUiRouterInventory() {
  const source = 'lib/router/app_router.dart';
  const knownRedirectOnly = {'/', '/memory', '/archive-detail'};
  const paths = [
    '/',
    '/onboarding',
    '/record',
    '/archive-belief',
    '/memory',
    '/timeline',
    '/search',
    '/discover-yourself',
    '/account',
    '/archive-detail',
    '/archive-identity',
    '/archive-life-chapters',
    '/archive-tool/:tool',
    '/journal',
    '/blind-spots',
    '/updates',
    '/entry/:id',
    '/pricing',
    '/subscription',
    '/restore-purchases',
    '/restore-production-verify',
    '/export',
    '/delete-account',
    '/settings',
    '/native-push-verify',
    '/revenuecat-verify',
    '/offline-sync-verify',
  ];
  final routes = paths
      .map(
        (path) => UiRouterRouteEntry(
          path: path,
          redirectOnly: knownRedirectOnly.contains(path),
          hasParameters: path.contains(':'),
          debugOnly: ProductionNavigation.isDebugOnlyRoute(path),
          productionVisible:
              !ProductionNavigation.hiddenNavRoutes.contains(path) &&
              (ProductionNavigation.isNavRouteVisible(path) ||
                  _isDeepLinkRoute(path)),
        ),
      )
      .toList();
  return UiRouterInventory(
    sourcePath: source,
    routes: routes,
    redirects: const [
      (from: '/', to: '/record'),
      (from: '/memory', to: '/archive-belief'),
      (from: '/archive-detail', to: '/archive-belief'),
    ],
    parsedAt: DateTime.utc(2026, 5, 25),
  );
}

String _defaultRouterFilePath() {
  final env = Platform.environment['UI_SCREENSHOT_ROUTER_PATH'];
  if (env != null && env.isNotEmpty) return env;

  final cwd = Directory.current.path;
  final candidates = [
    if (cwd.endsWith('voicememory_mobile'))
      '$cwd${Platform.pathSeparator}lib${Platform.pathSeparator}router${Platform.pathSeparator}app_router.dart',
    '$cwd${Platform.pathSeparator}lib${Platform.pathSeparator}router${Platform.pathSeparator}app_router.dart',
    '$cwd${Platform.pathSeparator}apps${Platform.pathSeparator}voicememory_mobile${Platform.pathSeparator}lib${Platform.pathSeparator}router${Platform.pathSeparator}app_router.dart',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return candidates.first;
}

/// Loads inventory from disk on host, or falls back to [defaultUiRouterInventory].
UiRouterInventory loadUiRouterInventory({String? routerFilePath}) {
  final path = routerFilePath ?? _defaultRouterFilePath();
  final file = File(path);
  if (file.existsSync()) {
    return parseAppRouterFile(path);
  }
  return defaultUiRouterInventory();
}

/// Parses [app_router.dart] without importing app router (file-based inventory).
UiRouterInventory parseAppRouterFile(String routerFilePath) {
  final file = File(routerFilePath);
  if (!file.existsSync()) {
    throw StateError('Router file not found: $routerFilePath');
  }
  return parseAppRouterSource(
    file.readAsStringSync(),
    sourcePath: routerFilePath,
  );
}

UiRouterInventory parseAppRouterSource(
  String source, {
  required String sourcePath,
}) {
  final pathPattern = RegExp(r"path:\s*'([^']+)'");
  final redirectPattern = RegExp(
    r"path:\s*'([^']+)'[\s\S]*?redirect:\s*\([^)]*\)\s*=>\s*'([^']+)'",
  );

  final paths = <String>{};
  for (final m in pathPattern.allMatches(source)) {
    paths.add(m.group(1)!);
  }

  final redirects = <({String from, String? to})>[];
  for (final m in redirectPattern.allMatches(source)) {
    redirects.add((from: m.group(1)!, to: m.group(2)));
  }

  const knownRedirectOnly = {'/', '/memory', '/archive-detail'};

  final routes = paths.map((path) {
    final hasParams = path.contains(':');
    final builderNear = _routeHasBuilder(source, path);
    final redirectOnlyFinal =
        knownRedirectOnly.contains(path) ||
        (!builderNear && redirects.any((r) => r.from == path));

    return UiRouterRouteEntry(
      path: path,
      redirectOnly: redirectOnlyFinal,
      hasParameters: hasParams,
      debugOnly: ProductionNavigation.isDebugOnlyRoute(path),
      productionVisible:
          !ProductionNavigation.hiddenNavRoutes.contains(path) &&
          (ProductionNavigation.isNavRouteVisible(path) ||
              _isDeepLinkRoute(path)),
    );
  }).toList()..sort((a, b) => a.path.compareTo(b.path));

  return UiRouterInventory(
    sourcePath: sourcePath,
    routes: routes,
    redirects: redirects,
    parsedAt: DateTime.now().toUtc(),
  );
}

bool _isDeepLinkRoute(String path) {
  const deep = {
    '/entry/:id',
    '/archive-identity',
    '/archive-life-chapters',
    '/archive-tool/:tool',
    '/subscription',
    '/restore-purchases',
    '/export',
    '/delete-account',
    '/settings',
    '/onboarding',
    '/pricing',
    '/journal',
    '/blind-spots',
    '/updates',
  };
  return deep.contains(path);
}

bool _routeHasBuilder(String source, String path) {
  final idx = source.indexOf("path: '$path'");
  if (idx < 0) return false;
  final slice = source.substring(idx, idx + 400);
  return slice.contains('builder:');
}

String uiScreenshotAuditHostRoot() {
  if (uiScreenshotAuditRootFromEnvironment.isNotEmpty) {
    return uiScreenshotAuditRootFromEnvironment;
  }
  final home = Platform.environment['HOME'] ?? '';
  if (home.isEmpty) return 'upload12';
  return '$home/Desktop/upload12';
}

String uiScreenshotAuditScreenshotsDir(String root) =>
    '$root${Platform.pathSeparator}$uiScreenshotAuditScreenshotsSubdir';

/// Resolves a writable audit root on device or host.
Future<String> resolveUiScreenshotAuditRoot() async {
  final fromEnv = uiScreenshotAuditRootFromEnvironment;
  final hostFallback = uiScreenshotAuditHostRoot();

  if (fromEnv.isNotEmpty &&
      !(Platform.isAndroid && fromEnv.startsWith('/Users'))) {
    return fromEnv;
  }

  if (Platform.isAndroid) {
    const downloadRoot = '/storage/emulated/0/Download/voicememory_upload12';
    try {
      final download = Directory(downloadRoot);
      if (!await download.exists()) {
        await download.create(recursive: true);
      }
      return downloadRoot;
    } catch (_) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return '${external.path}/upload12';
      }
      final docs = await getApplicationDocumentsDirectory();
      return '${docs.path}/upload12';
    }
  }

  if (fromEnv.isNotEmpty) return fromEnv;
  return hostFallback;
}

/// Device path for `adb pull` (Android external storage).
String? androidUiScreenshotAuditAdbPullPath() {
  if (!Platform.isAndroid) return null;
  return '/storage/emulated/0/Download/voicememory_upload12';
}

/// CLI: parse router and print inventory (no Flutter binding).
Future<void> runRouterInventoryCli() async {
  final inventory = loadUiRouterInventory();
  // ignore: avoid_print
  print(
    const JsonEncoder.withIndent('  ').convert({
      'source': inventory.sourcePath,
      'parsedAt': inventory.parsedAt.toIso8601String(),
      'routes': inventory.routes
          .map(
            (r) => {
              'path': r.path,
              'redirectOnly': r.redirectOnly,
              'hasParameters': r.hasParameters,
              'debugOnly': r.debugOnly,
              'productionVisible': r.productionVisible,
              'suggestedFilename': r.suggestedFilename,
            },
          )
          .toList(),
      'redirects': inventory.redirects
          .map((r) => {'from': r.from, 'to': r.to})
          .toList(),
    }),
  );
}

/// Widget-tree UX analyzer (runs at capture time; no PNG CV).
class UiLayoutAnalyzer {
  UiLayoutAnalyzer(this.tester);

  final WidgetTester tester;

  List<UiAuditFinding> analyze({
    required String screenshot,
    required String route,
    required String screenState,
  }) {
    final findings = <UiAuditFinding>[];

    _checkRenderOverflow(findings, screenshot, route);
    _checkMissingBack(findings, screenshot, route, screenState);
    _checkSmallTapTargets(findings, screenshot, route);
    _checkErrorSurfaces(findings, screenshot, route);
    _checkAccessibilityLabels(findings, screenshot, route);
    _checkVisualHierarchy(findings, screenshot, route, screenState);
    _checkDeadEnd(findings, screenshot, route, screenState);

    return findings;
  }

  void _checkRenderOverflow(
    List<UiAuditFinding> out,
    String screenshot,
    String route,
  ) {
    final exception = tester.takeException();
    if (exception == null) return;
    final msg = exception.toString();
    if (!msg.toLowerCase().contains('overflow')) return;
    out.add(
      UiAuditFinding(
        severity: 5,
        category: 'text_overflow',
        message: 'Render overflow detected: $msg',
        screenshot: screenshot,
        route: route,
        recommendation:
            'Wrap long text, reduce font size, or use scrollable layouts.',
      ),
    );
  }

  static const _shellRoutes = {
    '/record',
    '/archive-belief',
    '/timeline',
    '/search',
    '/discover-yourself',
    '/account',
    '/onboarding',
  };

  static const _backExpectedRoutes = {
    '/entry/:id',
    '/archive-identity',
    '/archive-life-chapters',
    '/subscription',
    '/restore-purchases',
    '/export',
    '/delete-account',
    '/settings',
    '/pricing',
    '/journal',
    '/blind-spots',
    '/updates',
  };

  void _checkMissingBack(
    List<UiAuditFinding> out,
    String screenshot,
    String route,
    String screenState,
  ) {
    if (_shellRoutes.contains(route)) return;
    final expectsBack = _backExpectedRoutes.any((r) {
      if (r.contains(':id')) return route.startsWith('/entry/');
      return route == r;
    });
    if (!expectsBack) return;

    final backIcon = find.byIcon(Icons.arrow_back);
    final backTooltip = find.byTooltip('Back');
    if (backIcon.evaluate().isNotEmpty || backTooltip.evaluate().isNotEmpty) {
      return;
    }

    final appBar = find.byType(AppBar);
    if (appBar.evaluate().isEmpty) {
      out.add(
        UiAuditFinding(
          severity: 4,
          category: 'missing_back_button',
          message: 'No AppBar back control on a pushed/detail route ($route).',
          screenshot: screenshot,
          route: route,
          recommendation:
              'Add leading back or explicit Done to return to archive.',
        ),
      );
      return;
    }

    final bar = tester.widget<AppBar>(appBar.first);
    if (bar.automaticallyImplyLeading) {
      return;
    }

    out.add(
      UiAuditFinding(
        severity: 4,
        category: 'missing_back_button',
        message:
            'AppBar present but no explicit back on $route ($screenState).',
        screenshot: screenshot,
        route: route,
        recommendation: 'Add IconButton(Icons.arrow_back) or bottom Done.',
      ),
    );
  }

  void _checkSmallTapTargets(
    List<UiAuditFinding> out,
    String screenshot,
    String route,
  ) {
    for (final type in [IconButton, TextButton, FilledButton, OutlinedButton]) {
      final finder = find.byType(type);
      for (var i = 0; i < finder.evaluate().length && i < 12; i++) {
        final rect = tester.getRect(finder.at(i));
        if (rect.width < 40 || rect.height < 40) {
          out.add(
            UiAuditFinding(
              severity: 3,
              category: 'accessibility',
              message:
                  'Small tap target (${rect.width.toStringAsFixed(0)}×${rect.height.toStringAsFixed(0)}) on $type.',
              screenshot: screenshot,
              route: route,
              recommendation:
                  'Minimum 48×48 dp touch targets for primary actions.',
            ),
          );
          break;
        }
      }
    }
  }

  void _checkErrorSurfaces(
    List<UiAuditFinding> out,
    String screenshot,
    String route,
  ) {
    const keywords = [
      'error',
      'exception',
      'failed',
      'unavailable',
      'blocked',
      'denied',
    ];
    final texts = find.byType(Text);
    for (var i = 0; i < texts.evaluate().length; i++) {
      final data = tester.widget<Text>(texts.at(i)).data?.toLowerCase() ?? '';
      for (final kw in keywords) {
        if (data.contains(kw)) {
          out.add(
            UiAuditFinding(
              severity: data.contains('error') || data.contains('exception')
                  ? 4
                  : 2,
              category: 'error_surface',
              message:
                  'Visible "$kw" messaging: "${data.length > 80 ? '${data.substring(0, 80)}…' : data}"',
              screenshot: screenshot,
              route: route,
            ),
          );
          return;
        }
      }
    }
  }

  void _checkAccessibilityLabels(
    List<UiAuditFinding> out,
    String screenshot,
    String route,
  ) {
    final iconButtons = find.byType(IconButton);
    for (var i = 0; i < iconButtons.evaluate().length && i < 8; i++) {
      final btn = tester.widget<IconButton>(iconButtons.at(i));
      if (btn.tooltip == null) {
        out.add(
          UiAuditFinding(
            severity: 2,
            category: 'accessibility',
            message: 'IconButton without tooltip or semanticLabel.',
            screenshot: screenshot,
            route: route,
            recommendation: 'Add tooltip for screen readers.',
          ),
        );
        return;
      }
    }
  }

  void _checkVisualHierarchy(
    List<UiAuditFinding> out,
    String screenshot,
    String route,
    String screenState,
  ) {
    if (route == '/record' && screenState.contains('processing')) {
      final progress = find.byType(LinearProgressIndicator);
      if (progress.evaluate().isEmpty) {
        out.add(
          UiAuditFinding(
            severity: 3,
            category: 'visual_hierarchy',
            message: 'Processing state without visible progress indicator.',
            screenshot: screenshot,
            route: route,
          ),
        );
      }
    }
    if (route == '/archive-belief' && screenState.contains('5+')) {
      final banner = find.textContaining('YOUR ARCHIVE CURRENTLY BELIEVES');
      if (banner.evaluate().isEmpty) {
        out.add(
          UiAuditFinding(
            severity: 2,
            category: 'visual_hierarchy',
            message:
                '5+ reflections but belief summary banner not detected in tree.',
            screenshot: screenshot,
            route: route,
          ),
        );
      }
    }
  }

  void _checkDeadEnd(
    List<UiAuditFinding> out,
    String screenshot,
    String route,
    String screenState,
  ) {
    final expectsBack = _backExpectedRoutes.any((r) {
      if (r.contains(':id')) return route.startsWith('/entry/');
      return route == r;
    });
    if (!expectsBack) return;
    final appBar = find.byType(AppBar);
    if (appBar.evaluate().isNotEmpty) {
      final bar = tester.widget<AppBar>(appBar.first);
      if (bar.automaticallyImplyLeading) return;
    }
    final hasNavOut =
        find.byType(OutlinedButton).evaluate().isNotEmpty ||
        find.byType(FilledButton).evaluate().isNotEmpty ||
        find.byIcon(Icons.arrow_back).evaluate().isNotEmpty;
    if (!hasNavOut) {
      out.add(
        UiAuditFinding(
          severity: 5,
          category: 'dead_end',
          message: 'No obvious navigation out on $route ($screenState).',
          screenshot: screenshot,
          route: route,
        ),
      );
    }
  }
}

/// Full audit report written to ~/Desktop/upload12/.
class UiScreenshotAuditReport {
  UiScreenshotAuditReport({
    required this.outputRoot,
    required this.inventory,
    required this.startedAt,
  }) : captures = [],
       findings = [],
       failures = [];

  final String outputRoot;
  final UiRouterInventory inventory;
  final DateTime startedAt;
  final List<UiScreenshotRecord> captures;
  final List<UiAuditFinding> findings;
  final List<String> failures;

  final Set<String> _routesCaptured = {};

  void addCapture(UiScreenshotRecord record) {
    captures.add(record);
    if (record.route.isEmpty) return;
    _routesCaptured.add(_normalizeRouteForInventory(record.route));
  }

  static String _normalizeRouteForInventory(String route) {
    if (route.startsWith('/entry/')) return '/entry/:id';
    if (route.startsWith('/archive-tool/')) return '/archive-tool/:tool';
    return route;
  }

  List<UiAuditFinding> get topIssuesBySeverity {
    final sorted = [...findings]
      ..sort((a, b) => b.severity.compareTo(a.severity));
    return sorted.take(20).toList();
  }

  Future<void> writeReports() async {
    final screenshotsDir = uiScreenshotAuditScreenshotsDir(outputRoot);
    await Directory(outputRoot).create(recursive: true);

    final indexPath =
        '$outputRoot${Platform.pathSeparator}UI_SCREENSHOT_INDEX.md';
    final findingsPath =
        '$outputRoot${Platform.pathSeparator}UI_AUDIT_FINDINGS.md';

    await File(indexPath).writeAsString(_buildIndexMd(screenshotsDir));
    await File(findingsPath).writeAsString(_buildFindingsMd());

    final jsonPath =
        '$outputRoot${Platform.pathSeparator}ui_screenshot_audit.json';
    await File(jsonPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'startedAt': startedAt.toIso8601String(),
        'completedAt': DateTime.now().toUtc().toIso8601String(),
        'outputRoot': outputRoot,
        'screenshotsDir': screenshotsDir,
        'totalCaptures': captures.length,
        'inventory': inventory.routes
            .map(
              (r) => {
                'path': r.path,
                'redirectOnly': r.redirectOnly,
                'capturable': !r.redirectOnly && r.productionVisible,
              },
            )
            .toList(),
        'captures': captures
            .map(
              (c) => {
                'filename': c.filename,
                'route': c.route,
                'screenState': c.screenState,
                'capturedAt': c.capturedAt.toIso8601String(),
                'filePath': c.filePath,
                'error': c.error,
              },
            )
            .toList(),
        'findings': findings
            .map(
              (f) => {
                'severity': f.severity,
                'category': f.category,
                'message': f.message,
                'screenshot': f.screenshot,
                'route': f.route,
                'recommendation': f.recommendation,
              },
            )
            .toList(),
        'failures': failures,
        'missingRoutes': inventory
            .missingFromCapturePlan(_routesCaptured.toList())
            .map((r) => r.path)
            .toList(),
      }),
    );
  }

  String _buildIndexMd(String screenshotsDir) {
    final b = StringBuffer()
      ..writeln('# ArchiveMe UI Screenshot Index')
      ..writeln()
      ..writeln('**Generated:** ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('**Router source:** `${inventory.sourcePath}`')
      ..writeln('**Screenshots directory:** `$screenshotsDir`')
      ..writeln()
      ..writeln('## Summary')
      ..writeln('- Total screenshots: ${captures.length}')
      ..writeln('- Routes captured (unique): ${_routesCaptured.length}')
      ..writeln('- Router paths parsed: ${inventory.routes.length}')
      ..writeln('- Capturable routes: ${inventory.capturableRoutes.length}')
      ..writeln('- Findings: ${findings.length}')
      ..writeln()
      ..writeln('## Captures')
      ..writeln('| Filename | Route | Screen state | Captured (UTC) |')
      ..writeln('|----------|-------|--------------|----------------|');
    for (final c in captures) {
      b.writeln(
        '| ${c.filename} | `${c.route}` | ${c.screenState} | ${c.capturedAt.toIso8601String()} |',
      );
    }
    b.writeln();
    b.writeln('## Router inventory (parsed)');
    b.writeln('| Path | Redirect only | Params | Production visible |');
    b.writeln('|------|---------------|--------|--------------------|');
    for (final r in inventory.routes) {
      b.writeln(
        '| `${r.path}` | ${r.redirectOnly} | ${r.hasParameters} | ${r.productionVisible} |',
      );
    }
    return b.toString();
  }

  String _buildFindingsMd() {
    final missing = inventory.missingFromCapturePlan(_routesCaptured.toList());
    final missingFiles = _plannedButNotCaptured();

    final b = StringBuffer()
      ..writeln('# ArchiveMe UI Audit Findings')
      ..writeln()
      ..writeln('**Generated:** ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln()
      ..writeln('## Executive summary')
      ..writeln('- Screenshots captured: **${captures.length}**')
      ..writeln('- UX findings: **${findings.length}**')
      ..writeln('- Capture failures: **${failures.length}**')
      ..writeln('- Missing routes (not captured): **${missing.length}**')
      ..writeln('- Missing planned screenshots: **${missingFiles.length}**')
      ..writeln()
      ..writeln('## Top 20 issues (by severity)')
      ..writeln('| Rank | Sev | Category | Screenshot | Issue |')
      ..writeln('|------|-----|----------|------------|-------|');
    var rank = 1;
    for (final f in topIssuesBySeverity) {
      b.writeln(
        '| $rank | ${f.severity} | ${f.category} | ${f.screenshot} | ${f.message.replaceAll('|', '/')} |',
      );
      rank++;
    }
    if (topIssuesBySeverity.isEmpty) {
      b.writeln('| — | — | — | — | No automated findings |');
    }
    b.writeln();
    b.writeln('## All findings');
    b.writeln();
    final byScreenshot = <String, List<UiAuditFinding>>{};
    for (final f in findings) {
      byScreenshot.putIfAbsent(f.screenshot, () => []).add(f);
    }
    for (final entry in byScreenshot.entries) {
      b.writeln('### `${entry.key}`');
      for (final f in entry.value) {
        b.writeln('- **[${f.severity}] ${f.category}:** ${f.message}');
        if (f.recommendation != null) {
          b.writeln('  - Recommendation: ${f.recommendation}');
        }
      }
      b.writeln();
    }
    if (missing.isNotEmpty) {
      b.writeln('## Missing routes');
      for (final r in missing) {
        b.writeln('- `${r.path}` (${r.suggestedFilename})');
      }
      b.writeln();
    }
    if (missingFiles.isNotEmpty) {
      b.writeln('## Missing screenshots (planned but not saved)');
      for (final m in missingFiles) {
        b.writeln('- $m');
      }
      b.writeln();
    }
    if (failures.isNotEmpty) {
      b.writeln('## Capture failures');
      for (final f in failures) {
        b.writeln('- $f');
      }
    }
    return b.toString();
  }

  List<String> _plannedButNotCaptured() {
    const planned = [
      'record-idle.png',
      'record-recording.png',
      'record-processing.png',
      'record-saved.png',
      'archive-empty.png',
      'archive-first-reflection.png',
      'archive-2-4-reflections.png',
      'archive-5-plus-reflections.png',
      'archive-belief-summary.png',
      'search-empty.png',
      'search-populated.png',
      'timeline-empty.png',
      'timeline-populated.png',
      'subscription-free-tier.png',
      'subscription-products-unavailable.png',
      'account-signed-out.png',
      'account-signed-in.png',
    ];
    final saved = captures.map((c) => c.filename).toSet();
    return planned.where((p) => !saved.contains(p)).toList();
  }

  void printFinalSummary() {
    final missing = inventory.missingFromCapturePlan(_routesCaptured.toList());
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('=== UI Screenshot Audit Summary ===');
    // ignore: avoid_print
    print('Total screens captured: ${captures.length}');
    // ignore: avoid_print
    print('Missing routes: ${missing.length}');
    for (final r in missing) {
      // ignore: avoid_print
      print('  - ${r.path}');
    }
    // ignore: avoid_print
    print('Missing planned screenshots: ${_plannedButNotCaptured().length}');
    // ignore: avoid_print
    print('Top UX issues:');
    var i = 1;
    for (final f in topIssuesBySeverity) {
      // ignore: avoid_print
      print(
        '  $i. [${f.severity}] ${f.category} — ${f.screenshot}: ${f.message}',
      );
      i++;
    }
    // ignore: avoid_print
    print('Reports: $outputRoot/UI_SCREENSHOT_INDEX.md');
    // ignore: avoid_print
    print('         $outputRoot/UI_AUDIT_FINDINGS.md');
  }
}

/// Integration-test runner for production UI screenshot audit.
class UiScreenshotAuditRunner {
  UiScreenshotAuditRunner({
    required this.binding,
    required this.tester,
    String? outputRoot,
    String? routerFilePath,
  }) : routerPath = routerFilePath ?? _defaultRouterFilePath(),
       report = UiScreenshotAuditReport(
         outputRoot: outputRoot ?? uiScreenshotAuditHostRoot(),
         inventory: loadUiRouterInventory(routerFilePath: routerFilePath),
         startedAt: DateTime.now().toUtc(),
       );

  final IntegrationTestWidgetsFlutterBinding binding;
  final WidgetTester tester;
  final String routerPath;
  late UiScreenshotAuditReport report;

  late String _screenshotsDir;
  var _androidSurfaceConverted = false;
  String? _sampleEntryId;

  static const Duration _pumpInterval = Duration(milliseconds: 100);

  Future<UiScreenshotAuditReport> runFullAudit() async {
    if (!kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
      throw StateError('UI screenshot audit is debug/test only.');
    }

    final root = await resolveUiScreenshotAuditRoot();
    final startedAt = report.startedAt;
    final inventory = report.inventory;
    report = UiScreenshotAuditReport(
      outputRoot: root,
      inventory: inventory,
      startedAt: startedAt,
    );

    _screenshotsDir = uiScreenshotAuditScreenshotsDir(root);
    await Directory(_screenshotsDir).create(recursive: true);

    final adbHint = androidUiScreenshotAuditAdbPullPath();
    if (adbHint != null) {
      debugPrint(
        'UI audit on device: $root\n'
        'Pull to Mac: adb pull $adbHint ${uiScreenshotAuditHostRoot()}/',
      );
    }

    await VisualAuditFixtures.prepareApp();
    runApp(const ArchiveMeApp());
    await pumpFrames(frames: 40);

    await _captureRouteScreens();
    await _captureOnboardingPages();
    await _captureArchiveStates();
    await _captureRecordStates();
    await _captureSearchStates();
    await _captureTimelineStates();
    await _captureSubscriptionStates();
    await _captureAccountStates();
    await _captureParameterizedRoutes();
    await _captureArchiveToolRoute();
    await _captureDebugRoutesIfEnabled();

    VisualAuditFixtures.clearRecordOverride();
    await report.writeReports();
    report.printFinalSummary();
    return report;
  }

  /// Captures `onboarding-1.png` … `onboarding-5.png` only (belief-first flow).
  Future<UiScreenshotAuditReport> runOnboardingScreenshotAudit() async {
    if (!kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
      throw StateError('Onboarding screenshot audit is debug/test only.');
    }

    final root = await resolveUiScreenshotAuditRoot();
    report = UiScreenshotAuditReport(
      outputRoot: root,
      inventory: report.inventory,
      startedAt: DateTime.now().toUtc(),
    );
    _screenshotsDir = uiScreenshotAuditScreenshotsDir(root);
    await Directory(_screenshotsDir).create(recursive: true);

    await VisualAuditFixtures.prepareApp();
    runApp(const ArchiveMeApp());
    await pumpFrames(frames: 40);

    await _captureOnboardingPages();
    await report.writeReports();
    report.printFinalSummary();
    return report;
  }

  Future<void> _captureOnboardingPages() async {
    await AppServices.instance.prefs.setOnboardingCompleted(false);
    await onboardingGate.refresh();
    await safeGo('/onboarding');
    await pumpFrames(frames: 36);

    for (var page = 0; page < 5; page++) {
      await _saveScreenshot(
        filename: 'onboarding-${page + 1}.png',
        route: '/onboarding',
        screenState: 'belief_onboarding_page_${page + 1}',
      );
      if (page < 4) {
        await tester.tap(find.text('Continue'));
        await pumpFrames(frames: 24);
      }
    }

    await AppServices.instance.prefs.setOnboardingCompleted(true);
    onboardingGate.markComplete();
  }

  Future<void> _captureRouteScreens() async {
    final plans = <({String route, String filename, bool scroll})>[
      (route: '/record', filename: 'record.png', scroll: false),
      (route: '/archive-belief', filename: 'archive-belief.png', scroll: true),
      (route: '/belief-changes', filename: 'belief-changes.png', scroll: true),
      (
        route: '/discover-yourself',
        filename: 'discover-yourself.png',
        scroll: true,
      ),
      (route: '/account', filename: 'account.png', scroll: true),
      (route: '/subscription', filename: 'subscription.png', scroll: true),
      (route: '/settings', filename: 'settings.png', scroll: true),
      (route: '/export', filename: 'export.png', scroll: false),
      (route: '/pricing', filename: 'pricing.png', scroll: true),
      (
        route: '/restore-purchases',
        filename: 'restore-purchases.png',
        scroll: false,
      ),
      (route: '/journal', filename: 'journal.png', scroll: true),
      (route: '/blind-spots', filename: 'blind-spots.png', scroll: true),
      (
        route: '/archive-identity',
        filename: 'archive-identity.png',
        scroll: true,
      ),
      (
        route: '/archive-life-chapters',
        filename: 'archive-life-chapters.png',
        scroll: true,
      ),
      (route: '/onboarding', filename: 'onboarding.png', scroll: true),
      (route: '/updates', filename: 'updates.png', scroll: false),
      (route: '/delete-account', filename: 'delete-account.png', scroll: false),
    ];

    await VisualAuditFixtures.seedRecordingCount(5);

    for (final plan in plans) {
      if (!ProductionNavigation.isNavRouteVisible(plan.route) &&
          plan.route != '/onboarding') {
        continue;
      }
      await _runCapture(
        filename: plan.filename,
        route: plan.route,
        screenState: 'default_route',
        action: () async {
          if (plan.route == '/onboarding') {
            await AppServices.instance.prefs.setOnboardingCompleted(false);
            await onboardingGate.refresh();
          } else {
            await AppServices.instance.prefs.setOnboardingCompleted(true);
            onboardingGate.markComplete();
          }
          await safeGo(plan.route);
          if (plan.scroll) {
            await _captureWithScrollVariants(
              baseFilename: plan.filename.replaceAll('.png', ''),
              route: plan.route,
              screenState: 'default_route',
              primaryOnly: true,
            );
          }
        },
        skipPrimaryIfScrolled: plan.scroll,
      );
      if (plan.route == '/onboarding') {
        await AppServices.instance.prefs.setOnboardingCompleted(true);
        onboardingGate.markComplete();
      }
    }
  }

  Future<void> _captureArchiveStates() async {
    final states = <({int count, String file, String state})>[
      (count: 0, file: 'archive-empty.png', state: 'empty_archive'),
      (
        count: 1,
        file: 'archive-first-reflection.png',
        state: 'first_reflection',
      ),
      (count: 3, file: 'archive-2-4-reflections.png', state: '2-4_reflections'),
      (
        count: 5,
        file: 'archive-5-plus-reflections.png',
        state: '5+_reflections',
      ),
      (
        count: 6,
        file: 'archive-belief-summary.png',
        state: 'belief_summary_visible',
      ),
    ];
    for (final s in states) {
      await _runCapture(
        filename: s.file,
        route: '/archive-belief',
        screenState: s.state,
        action: () async {
          await VisualAuditFixtures.seedRecordingCount(s.count);
          await safeGo('/archive-belief');
        },
      );
    }
  }

  Future<void> _captureRecordStates() async {
    final states = <({String file, String state, void Function() apply})>[
      (
        file: 'record-idle.png',
        state: 'idle',
        apply: VisualAuditFixtures.setRecordIdle,
      ),
      (
        file: 'record-recording.png',
        state: 'recording',
        apply: VisualAuditFixtures.setRecordRecording,
      ),
      (
        file: 'record-processing.png',
        state: 'processing',
        apply: () {
          VisualAuditOverrides.setRecordPresentation(
            const RecordAuditPresentation(
              ui: RecordUiState.processing,
              stageLabel: 'Finding patterns…',
            ),
          );
        },
      ),
      (
        file: 'record-saved.png',
        state: 'saved',
        apply: VisualAuditFixtures.setRecordSyncSuccess,
      ),
    ];
    for (final s in states) {
      await _runCapture(
        filename: s.file,
        route: '/record',
        screenState: s.state,
        action: () async {
          s.apply();
          await safeGo('/record');
        },
      );
    }
    VisualAuditFixtures.clearRecordOverride();
  }

  Future<void> _captureSearchStates() async {
    await _runCapture(
      filename: 'search-empty.png',
      route: '/search',
      screenState: 'search_empty_query',
      action: () async {
        await VisualAuditFixtures.seedRecordingCount(3);
        await safeGo('/search');
      },
    );
    await _runCapture(
      filename: 'search-populated.png',
      route: '/search',
      screenState: 'search_populated_results',
      action: () async {
        await VisualAuditFixtures.seedRecordingCount(5);
        await safeGo('/search');
        final field = find.byType(TextField);
        if (field.evaluate().isNotEmpty) {
          await tester.enterText(field.first, 'career');
          await pumpFrames(frames: 30);
        }
      },
    );
  }

  Future<void> _captureTimelineStates() async {
    await _runCapture(
      filename: 'timeline-empty.png',
      route: '/timeline',
      screenState: 'timeline_empty',
      action: () async {
        await VisualAuditFixtures.clearJournal();
        await safeGo('/timeline');
      },
    );
    await _runCapture(
      filename: 'timeline-populated.png',
      route: '/timeline',
      screenState: 'timeline_populated',
      action: () async {
        await VisualAuditFixtures.seedRecordingCount(5);
        await safeGo('/timeline');
      },
    );
  }

  Future<void> _captureSubscriptionStates() async {
    await _runCapture(
      filename: 'subscription-free-tier.png',
      route: '/subscription',
      screenState: 'free_tier',
      action: () async {
        await safeGo('/subscription');
        await pumpFrames(frames: 40);
      },
    );
    await _runCapture(
      filename: 'subscription-products-unavailable.png',
      route: '/subscription',
      screenState: 'products_unavailable',
      action: () async {
        await safeGo('/subscription');
        await pumpFrames(frames: 40);
      },
    );
  }

  Future<void> _captureAccountStates() async {
    await _runCapture(
      filename: 'account-signed-out.png',
      route: '/account',
      screenState: 'signed_out',
      action: () async {
        await AppServices.instance.auth.signOut();
        await VisualAuditFixtures.seedRecordingCount(2);
        await safeGo('/account');
        await pumpFrames(frames: 30);
      },
    );
    await _runCapture(
      filename: 'account-signed-in.png',
      route: '/account',
      screenState: 'signed_in_requires_live_session',
      action: () async {
        await AppServices.instance.auth.signOut();
        await safeGo('/account');
        await pumpFrames(frames: 24);
        final field = find.byType(TextField);
        if (field.evaluate().isNotEmpty) {
          await tester.enterText(field.first, 'you@example.com');
          await pumpFrames(frames: 8);
        }
      },
    );
  }

  Future<void> _captureDebugRoutesIfEnabled() async {
    if (!AppConfig.debugToolsEnabled) return;
    const debugRoutes = [
      '/native-push-verify',
      '/revenuecat-verify',
      '/offline-sync-verify',
    ];
    for (final route in debugRoutes) {
      if (ProductionNavigation.redirectAwayFromIncomplete(route) != null) {
        continue;
      }
      await _runCapture(
        filename: '${route.replaceAll('/', '').replaceAll('-', '_')}.png',
        route: route,
        screenState: 'debug_route',
        action: () async => safeGo(route),
      );
    }
  }

  Future<void> _captureArchiveToolRoute() async {
    await _runCapture(
      filename: 'archive-tool-belief-survival.png',
      route: '/archive-tool/belief-survival',
      screenState: 'deferred_tool_redirect_or_surface',
      action: () async {
        await VisualAuditFixtures.seedRecordingCount(5);
        await safeGo('/archive-tool/belief-survival');
      },
    );
  }

  Future<void> _captureParameterizedRoutes() async {
    await VisualAuditFixtures.seedRecordingCount(5);
    final entries = await AppServices.instance.journal.loadAll();
    if (entries.isEmpty) return;
    _sampleEntryId = entries.last.id;
    await _runCapture(
      filename: 'entry-detail.png',
      route: '/entry/$_sampleEntryId',
      screenState: 'entry_detail',
      action: () async => safeGo('/entry/$_sampleEntryId'),
    );
  }

  Future<void> _runCapture({
    required String filename,
    required String route,
    required String screenState,
    required Future<void> Function() action,
    bool skipPrimaryIfScrolled = false,
  }) async {
    try {
      await action();
      await pumpFrames(frames: 28);
      if (!skipPrimaryIfScrolled) {
        await _saveScreenshot(
          filename: filename,
          route: route,
          screenState: screenState,
        );
      }
    } catch (e, st) {
      report.failures.add('$filename ($route): $e');
      debugPrint('Capture failed $filename: $e');
      if (kDebugMode) debugPrint('$st');
      try {
        await _saveScreenshot(
          filename: filename.replaceAll('.png', '-error.png'),
          route: route,
          screenState: 'capture_error',
        );
      } catch (_) {}
    }
  }

  Future<void> _captureWithScrollVariants({
    required String baseFilename,
    required String route,
    required String screenState,
    bool primaryOnly = false,
  }) async {
    await _saveScreenshot(
      filename: '$baseFilename.png',
      route: route,
      screenState: screenState,
    );
    if (primaryOnly) return;
  }

  Future<void> _saveScreenshot({
    required String filename,
    required String route,
    required String screenState,
  }) async {
    final analyzer = UiLayoutAnalyzer(tester);
    final findings = analyzer.analyze(
      screenshot: filename,
      route: route,
      screenState: screenState,
    );
    report.findings.addAll(findings);

    if (!kIsWeb && Platform.isAndroid && !_androidSurfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      _androidSurfaceConverted = true;
    }
    await tester.pump(_pumpInterval);
    final name = filename.endsWith('.png')
        ? filename.substring(0, filename.length - 4)
        : filename;
    final bytes = await binding.takeScreenshot(name);
    final path = '$_screenshotsDir${Platform.pathSeparator}$filename';
    await File(path).writeAsBytes(bytes, flush: true);

    report.addCapture(
      UiScreenshotRecord(
        filename: filename,
        route: route,
        screenState: screenState,
        capturedAt: DateTime.now().toUtc(),
        filePath: path,
      ),
    );
    debugPrint('UI audit screenshot: $path');
  }

  Future<void> safeGo(String route) async {
    appRouter.go(route);
    await pumpFrames();
  }

  Future<void> pumpFrames({int frames = 24}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(_pumpInterval);
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}
