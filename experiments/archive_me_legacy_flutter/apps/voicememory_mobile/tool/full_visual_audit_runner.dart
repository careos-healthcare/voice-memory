import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voicememory_mobile/app.dart';
import 'package:voicememory_mobile/dev/visual_audit_registry.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'full_visual_audit.dart';

/// Crawls routes, taps safe widgets, captures PNGs for visual audit.
class VisualAuditCrawler {
  VisualAuditCrawler({
    required this.tester,
    required this.runner,
    required this.maxTapDepth,
  });

  final WidgetTester tester;
  final FullVisualAuditRunner runner;
  final int maxTapDepth;

  final Set<String> _visitedRouteKeys = {};

  Future<void> crawlFromRoute(String route, String folder) async {
    await runner.safeGo(route);
    await runner.captureScrollTriplet(
      folder: folder,
      basename: 'crawl_${runner.slug(route)}_landing',
      route: route,
    );
    await _crawlTaps(route: route, folder: folder, depth: 0);
  }

  Future<void> _crawlTaps({
    required String route,
    required String folder,
    required int depth,
  }) async {
    if (depth >= maxTapDepth) return;

    final candidates = _safeTapTargets();
    for (var i = 0; i < candidates.length; i++) {
      final finder = candidates[i];
      try {
        await tester.tap(finder, warnIfMissed: false);
        await runner.pumpFrames(frames: 16);
        final path = appRouter.state.uri.path;
        final key = '$path@depth$depth#$i';
        if (_visitedRouteKeys.contains(key)) continue;
        _visitedRouteKeys.add(key);

        final subfolder = path.contains('export')
            ? VisualAuditFolders.export
            : path.contains('pricing') || path.contains('subscription')
            ? VisualAuditFolders.pricing
            : folder;

        await runner.captureScrollTriplet(
          folder: subfolder,
          basename: 'crawl_${runner.slug(route)}_tap_${depth}_$i',
          route: path,
        );

        if (runner.treeHasErrorKeywords()) {
          await runner.captureCurrentScreen(
            filename: 'error_surface_${runner.slug(path)}_${depth}_$i.png',
            folder: VisualAuditFolders.errors,
            route: path,
            captureId: 'error_surface',
          );
        }

        await runner.safeGo(route);
        await runner.pumpFrames();
      } catch (e) {
        runner.report.warnings.add('Tap skipped on $route depth $depth: $e');
      }
    }
  }

  List<Finder> _safeTapTargets() {
    final out = <Finder>[];
    for (final type in [
      IconButton,
      TextButton,
      ListTile,
      InkWell,
      FilledButton,
    ]) {
      final finder = find.byType(type);
      for (var i = 0; i < finder.evaluate().length && out.length < 6; i++) {
        final f = finder.at(i);
        if (_isSafeTap(f)) out.add(f);
      }
    }
    return out;
  }

  bool _isSafeTap(Finder finder) {
    try {
      final semantics = tester.getSemantics(finder);
      final label = semantics.label.toLowerCase();
      final value = semantics.value.toLowerCase();
      final combined = '$label $value';
      for (final danger in visualAuditDangerTapPatterns) {
        if (combined.contains(danger)) return false;
      }
      if (combined.contains('delete') || combined.contains('sign out')) {
        return false;
      }
      return label.isNotEmpty || value.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

/// Orchestrates full visual audit capture run.
class FullVisualAuditRunner {
  FullVisualAuditRunner({
    required this.binding,
    required this.tester,
    String? outputRoot,
    this.maxCrawlerTapDepth = 2,
  }) : report = VisualAuditReport(
         outputRoot: outputRoot ?? visualAuditHostRoot(),
         timestamp: DateTime.now().toUtc(),
       );

  final IntegrationTestWidgetsFlutterBinding binding;
  final WidgetTester tester;
  final VisualAuditReport report;
  final int maxCrawlerTapDepth;

  late String _root;
  var _sequence = 0;
  var _androidSurfaceConverted = false;

  static const Duration _pumpInterval = Duration(milliseconds: 100);

  Future<VisualAuditReport> runFullAudit() async {
    if (!kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
      throw StateError('Visual audit is debug/test only.');
    }

    _root = await resolveVisualAuditRoot();
    await ensureVisualAuditDirectories(_root);

    final adbHint = androidVisualAuditAdbPullPath();
    if (adbHint != null) {
      debugPrint(
        'Visual audit on device: $_root\nadb pull $adbHint ~/Desktop/upload1/',
      );
    }

    await VisualAuditFixtures.prepareApp();
    runApp(const ArchiveMeApp());
    await pumpFrames(frames: 40);

    await _captureRecordStates();
    await _captureArchiveModes();
    await _captureSearchStates();
    await _captureBottomNavTabs();
    await _captureAllRoutes();
    await _captureAccountAndPricing();
    await _captureDebugRoutes();
    await _runNavigationCrawler();

    VisualAuditFixtures.clearRecordOverride();
    await report.writeToDisk();
    return report;
  }

  Future<void> _captureRecordStates() async {
    final captures = <({String name, void Function() apply})>[
      (name: 'idle', apply: VisualAuditFixtures.setRecordIdle),
      (name: 'recording', apply: VisualAuditFixtures.setRecordRecording),
      (name: 'saving', apply: VisualAuditFixtures.setRecordSaving),
      (
        name: 'saved_local',
        apply: VisualAuditFixtures.setRecordLocalSaveSuccess,
      ),
      (
        name: 'sync_unavailable',
        apply: VisualAuditFixtures.setRecordSyncUnavailable,
      ),
      (name: 'sync_success', apply: VisualAuditFixtures.setRecordSyncSuccess),
      (
        name: 'microphone_denied',
        apply: VisualAuditFixtures.setRecordMicrophoneDenied,
      ),
    ];

    for (final c in captures) {
      await _runSafe(
        captureId: 'record_${c.name}',
        route: '/record',
        action: () async {
          c.apply();
          await safeGo('/record');
          await captureNamed(
            folder: VisualAuditFolders.record,
            basename: 'record_${c.name}',
          );
        },
      );
    }
    VisualAuditFixtures.clearRecordOverride();
  }

  Future<void> _captureArchiveModes() async {
    for (final count in VisualAuditFixtures.archiveRecordingCounts) {
      final mode = VisualAuditFixtures.archiveModeLabel(count);
      await _runSafe(
        captureId: 'archive_$mode',
        route: '/archive-belief',
        action: () async {
          await VisualAuditFixtures.seedRecordingCount(count);
          await safeGo('/archive-belief');
          await captureNamed(
            folder: VisualAuditFolders.archive,
            basename: 'archive_$mode',
            scrollable: true,
          );
        },
      );
    }
  }

  Future<void> _captureSearchStates() async {
    await _runSafe(
      captureId: 'search_empty',
      route: '/search',
      action: () async {
        await VisualAuditFixtures.seedRecordingCount(3);
        await safeGo('/search');
        await captureNamed(
          folder: VisualAuditFolders.search,
          basename: 'search_empty',
        );
      },
    );

    await _runSafe(
      captureId: 'search_typing',
      route: '/search',
      action: () async {
        await safeGo('/search');
        final field = find.byType(TextField);
        if (field.evaluate().isNotEmpty) {
          await tester.enterText(field.first, 'career');
          await pumpFrames();
        }
        await captureNamed(
          folder: VisualAuditFolders.search,
          basename: 'search_typing',
        );
      },
    );

    await _runSafe(
      captureId: 'search_no_results',
      route: '/search',
      action: () async {
        await safeGo('/search');
        final field = find.byType(TextField);
        if (field.evaluate().isNotEmpty) {
          await tester.enterText(field.first, 'zzzznonexistentquery');
          await pumpFrames(frames: 30);
        }
        await captureNamed(
          folder: VisualAuditFolders.search,
          basename: 'search_no_results',
        );
      },
    );

    await _runSafe(
      captureId: 'search_results',
      route: '/search',
      action: () async {
        await VisualAuditFixtures.seedRecordingCount(5);
        await safeGo('/search');
        final field = find.byType(TextField);
        if (field.evaluate().isNotEmpty) {
          await tester.enterText(field.first, 'career');
          await pumpFrames(frames: 30);
        }
        await captureNamed(
          folder: VisualAuditFolders.search,
          basename: 'search_results',
          scrollable: true,
        );
      },
    );
  }

  Future<void> _captureBottomNavTabs() async {
    for (final tab in visualAuditBottomNavTabs) {
      await _runSafe(
        captureId: 'nav_${slug(tab.label)}',
        route: tab.route,
        action: () async {
          await safeGo(tab.route);
          await captureNamed(
            folder: VisualAuditFolders.navigation,
            basename: 'nav_${slug(tab.label)}',
            scrollable: true,
          );
          await captureNamed(
            folder: tab.folder,
            basename: 'tab_${slug(tab.label)}',
            scrollable: true,
          );
        },
      );
    }
  }

  Future<void> _captureAllRoutes() async {
    for (final spec in visualAuditRoutes()) {
      await _runSafe(
        captureId: 'route_${slug(spec.path)}',
        route: spec.path,
        action: () async {
          await VisualAuditFixtures.seedRecordingCount(5);
          await safeGo(spec.path);
          if (!report.routesVisited.contains(spec.path)) {
            report.routesVisited.add(spec.path);
          }
          await captureNamed(
            folder: spec.folder,
            basename: 'route_${slug(spec.path)}',
            scrollable: spec.scrollable,
          );
          if (treeHasErrorKeywords()) {
            await captureCurrentScreen(
              filename: 'error_surface_${slug(spec.path)}.png',
              folder: VisualAuditFolders.errors,
              route: spec.path,
              captureId: 'error_surface_${slug(spec.path)}',
            );
          }
        },
      );
    }
  }

  Future<void> _captureAccountAndPricing() async {
    await _runSafe(
      captureId: 'account_signed_out',
      route: '/account',
      action: () async {
        await VisualAuditFixtures.seedRecordingCount(2);
        await safeGo('/account');
        await captureNamed(
          folder: VisualAuditFolders.account,
          basename: 'account_signed_out',
          scrollable: true,
        );
      },
    );

    await _runSafe(
      captureId: 'pricing_unavailable',
      route: '/pricing',
      action: () async {
        await safeGo('/pricing');
        await captureNamed(
          folder: VisualAuditFolders.pricing,
          basename: 'pricing_page',
          scrollable: true,
        );
      },
    );

    await _runSafe(
      captureId: 'export_idle',
      route: '/export',
      action: () async {
        await VisualAuditFixtures.seedRecordingCount(3);
        await safeGo('/export');
        await captureNamed(
          folder: VisualAuditFolders.export,
          basename: 'export_idle',
        );
      },
    );
  }

  Future<void> _captureDebugRoutes() async {
    for (final spec in visualAuditRoutes().where((r) => r.debugOnly)) {
      await _runSafe(
        captureId: 'debug_${slug(spec.path)}',
        route: spec.path,
        action: () async {
          await safeGo(spec.path);
          await captureNamed(
            folder: VisualAuditFolders.debug,
            basename: 'debug_${slug(spec.path)}',
            scrollable: true,
          );
        },
      );
    }
  }

  Future<void> _runNavigationCrawler() async {
    final crawler = VisualAuditCrawler(
      tester: tester,
      runner: this,
      maxTapDepth: maxCrawlerTapDepth,
    );
    for (final spec in visualAuditRoutes().take(8)) {
      await _runSafe(
        captureId: 'crawler_${slug(spec.path)}',
        route: spec.path,
        action: () => crawler.crawlFromRoute(spec.path, spec.folder),
      );
    }
  }

  Future<void> _runSafe({
    required String captureId,
    required String route,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } catch (e, st) {
      report.addError(message: '$e', route: route, captureId: captureId);
      if (kDebugMode) debugPrint('$st');
      try {
        await captureCurrentScreen(
          filename: 'error_${slug(route)}.png',
          folder: VisualAuditFolders.errors,
          route: route,
          captureId: 'error_$captureId',
        );
      } catch (_) {}
    }
  }

  Future<void> safeGo(String route) async {
    appRouter.go(route);
    await pumpFrames();
  }

  Future<void> pumpFrames({int frames = 24}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(_pumpInterval);
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  String slug(String input) => input
      .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
      .replaceFirst(RegExp(r'^_|_$'), '');

  Future<void> captureNamed({
    required String folder,
    required String basename,
    bool scrollable = false,
    String? route,
  }) async {
    if (!scrollable) {
      await captureCurrentScreen(
        filename: '${_nextPrefix()}_$basename.png',
        folder: folder,
        route: route,
        captureId: basename,
      );
      return;
    }
    await captureScrollTriplet(
      folder: folder,
      basename: basename,
      route: route,
    );
  }

  Future<void> captureScrollTriplet({
    required String folder,
    required String basename,
    String? route,
  }) async {
    await captureCurrentScreen(
      filename: '${basename}_top.png',
      folder: folder,
      route: route,
      captureId: '${basename}_top',
    );
    final controller = _primaryScrollController();
    if (controller == null || controller.position.maxScrollExtent <= 0) {
      await captureCurrentScreen(
        filename: '${basename}_mid.png',
        folder: folder,
        route: route,
        captureId: '${basename}_mid',
      );
      await captureCurrentScreen(
        filename: '${basename}_bottom.png',
        folder: folder,
        route: route,
        captureId: '${basename}_bottom',
      );
      return;
    }
    final max = controller.position.maxScrollExtent;
    controller.jumpTo(max * 0.5);
    await pumpFrames(frames: 10);
    await captureCurrentScreen(
      filename: '${basename}_mid.png',
      folder: folder,
      route: route,
      captureId: '${basename}_mid',
    );
    controller.jumpTo(max);
    await pumpFrames(frames: 10);
    await captureCurrentScreen(
      filename: '${basename}_bottom.png',
      folder: folder,
      route: route,
      captureId: '${basename}_bottom',
    );
  }

  ScrollController? _primaryScrollController() {
    ScrollController? best;
    var bestExtent = 0.0;
    final scrollables = find.byType(Scrollable);
    for (var i = 0; i < scrollables.evaluate().length; i++) {
      final widget = tester.widget<Scrollable>(scrollables.at(i));
      final controller = widget.controller;
      if (controller == null || !controller.hasClients) continue;
      final extent = controller.position.maxScrollExtent;
      if (extent > bestExtent) {
        bestExtent = extent;
        best = controller;
      }
    }
    return best;
  }

  bool treeHasErrorKeywords() {
    final textWidgets = find.byType(Text);
    for (var i = 0; i < textWidgets.evaluate().length; i++) {
      final data =
          tester.widget<Text>(textWidgets.at(i)).data?.toLowerCase() ?? '';
      for (final kw in visualAuditErrorSurfaceKeywords) {
        if (data.contains(kw)) return true;
      }
    }
    return false;
  }

  String _nextPrefix() {
    _sequence++;
    return _sequence.toString().padLeft(3, '0');
  }

  Future<void> captureCurrentScreen({
    required String filename,
    required String folder,
    String? route,
    String? captureId,
  }) async {
    if (!kIsWeb && Platform.isAndroid && !_androidSurfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      _androidSurfaceConverted = true;
    }
    await tester.pump(_pumpInterval);
    final name = filename.endsWith('.png')
        ? filename.substring(0, filename.length - 4)
        : filename;
    final bytes = await binding.takeScreenshot(name);
    final dir = '$_root${Platform.pathSeparator}$folder';
    await Directory(dir).create(recursive: true);
    final path = '$dir${Platform.pathSeparator}$filename';
    await File(path).writeAsBytes(bytes, flush: true);
    report.addScreenshot(
      path: path,
      filename: filename,
      folder: folder,
      route: route,
      captureId: captureId,
    );
    debugPrint('Visual audit saved: $path');
  }
}
