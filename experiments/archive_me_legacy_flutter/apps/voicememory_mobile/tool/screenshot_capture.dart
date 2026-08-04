import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voicememory_mobile/app.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/dev/screenshot_registry.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/router/onboarding_gate.dart';
import 'package:voicememory_mobile/services/app_services.dart';

/// Result summary printed after a screenshot run.
class ScreenshotCaptureReport {
  ScreenshotCaptureReport({
    required this.outputDirectory,
    required this.savedPaths,
    required this.routesVisited,
    required this.routesFailed,
  });

  final String outputDirectory;
  final List<String> savedPaths;
  final int routesVisited;
  final int routesFailed;

  int get totalScreenshots => savedPaths.length;

  void printSummary() {
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('Screenshots saved:');
    // ignore: avoid_print
    print(outputDirectory);
    // ignore: avoid_print
    print('Total screenshots:');
    // ignore: avoid_print
    print(totalScreenshots);
    // ignore: avoid_print
    print('Routes visited:');
    // ignore: avoid_print
    print(routesVisited);
    if (routesFailed > 0) {
      // ignore: avoid_print
      print('Routes failed: $routesFailed');
    }
  }
}

/// Integration-test screenshot runner (lives under [tool/], not shipped in release APK).
class ScreenshotCaptureRunner {
  ScreenshotCaptureRunner({
    required this.binding,
    required this.tester,
    String? outputDirectory,
    List<ScreenshotRouteTarget>? targets,
  }) : _outputDirectoryOverride = outputDirectory,
       targets = targets ?? screenshotRegistry();

  final IntegrationTestWidgetsFlutterBinding binding;
  final WidgetTester tester;
  final String? _outputDirectoryOverride;
  final List<ScreenshotRouteTarget> targets;

  late String _effectiveOutputDirectory;

  final List<String> _savedPaths = [];
  var _routesVisited = 0;
  var _routesFailed = 0;
  var _androidSurfaceConverted = false;

  static const Duration _pumpInterval = Duration(milliseconds: 100);

  /// Bounded frame pumps (avoids hanging on perpetual animations / network spinners).
  Future<void> _pumpFrames({int frames = 24}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(_pumpInterval);
    }
    await _waitForFrameSettle();
  }

  static Future<void> prepareAppForScreenshots() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppConfig.initApiResolution();
    await AppServices.initialize();
    await _seedSampleJournalIfEmpty();
    await AppServices.instance.prefs.setOnboardingCompleted(true);
    onboardingGate.markComplete();
  }

  static Future<void> _seedSampleJournalIfEmpty() async {
    final existing = await AppServices.instance.journal.loadAll();
    if (existing.isNotEmpty) return;

    final entry = JournalEntry(
      id: 'screenshot-sample-1',
      createdAt: DateTime.utc(2026, 5, 10, 14, 30),
      transcript:
          'I keep wondering whether I am in the right career. I feel uncertain about my next move at work and what my manager expects.',
      durationSeconds: 42,
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 4,
        recurringThemes: ['career'],
        exactLanguagePattern: 'not sure what the right path is',
        concreteObservation:
            'Career uncertainty came up again in this reflection.',
        repeatedSignal: 'career',
      ),
      syncStatus: SyncStatus.localOnly,
    );
    await AppServices.instance.journalStore.save(entry);
  }

  Future<ScreenshotCaptureReport> runAll() async {
    if (!kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
      throw StateError(
        'Screenshot capture is only available in debug/test builds.',
      );
    }

    _effectiveOutputDirectory =
        _outputDirectoryOverride ?? await resolveScreenshotOutputDirectory();
    final dir = Directory(_effectiveOutputDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final adbPullHint = androidScreenshotAdbPullPath();
    if (adbPullHint != null) {
      debugPrint(
        'Screenshots on device: $_effectiveOutputDirectory\n'
        'Pull to Mac: adb pull $adbPullHint ~/Desktop/uploads/',
      );
    }

    runApp(const ArchiveMeApp());
    await _pumpFrames(frames: 40);

    for (final target in targets) {
      try {
        await _visitRoute(target);
        _routesVisited++;
      } catch (e, st) {
        _routesFailed++;
        debugPrint('Screenshot route failed ${target.route}: $e');
        if (kDebugMode) debugPrint('$st');
        await _captureFile('error_${target.fileBase}.png');
      }
    }

    final report = ScreenshotCaptureReport(
      outputDirectory: _effectiveOutputDirectory,
      savedPaths: List.unmodifiable(_savedPaths),
      routesVisited: _routesVisited,
      routesFailed: _routesFailed,
    );
    report.printSummary();
    return report;
  }

  Future<void> _visitRoute(ScreenshotRouteTarget target) async {
    appRouter.go(target.route);
    await _pumpFrames();
    await _waitForFrameSettle();

    if (target.scrollable) {
      await _captureScrollPositions(target.fileBase);
    } else {
      final numbered =
          '${target.order.toString().padLeft(3, '0')}_${target.fileBase}.png';
      await _captureFile(numbered);
    }
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

  Future<void> _jumpScroll(ScrollController controller, double offset) async {
    controller.jumpTo(offset.clamp(0.0, controller.position.maxScrollExtent));
    await _pumpFrames(frames: 10);
  }

  Future<void> _captureScrollPositions(String fileBase) async {
    await _captureFile('${fileBase}_top.png');

    final controller = _primaryScrollController();
    if (controller == null) {
      await _captureFile('${fileBase}_mid.png');
      await _captureFile('${fileBase}_bottom.png');
      return;
    }

    final maxExtent = controller.position.maxScrollExtent;
    if (maxExtent <= 0) {
      await _captureFile('${fileBase}_mid.png');
      await _captureFile('${fileBase}_bottom.png');
      return;
    }

    await _jumpScroll(controller, maxExtent * 0.5);
    await _captureFile('${fileBase}_mid.png');

    await _jumpScroll(controller, maxExtent);
    await _captureFile('${fileBase}_bottom.png');
  }

  Future<void> _waitForFrameSettle() async {
    await tester.pump(const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<void> _captureFile(String filename) async {
    if (!kIsWeb && Platform.isAndroid && !_androidSurfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      _androidSurfaceConverted = true;
    }
    await tester.pump(_pumpInterval);
    final screenshotName = filename.endsWith('.png')
        ? filename.substring(0, filename.length - 4)
        : filename;
    final bytes = await binding.takeScreenshot(screenshotName);
    final path = '$_effectiveOutputDirectory${Platform.pathSeparator}$filename';
    await File(path).writeAsBytes(bytes, flush: true);
    _savedPaths.add(path);
    debugPrint('Screenshot saved: $path');
  }
}
