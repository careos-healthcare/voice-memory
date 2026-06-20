import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/force_screenshot_repeat_card.dart';
import 'package:voicememory_mobile/screens/archive_belief_screen.dart';
import 'package:voicememory_mobile/screens/onboarding_screen.dart';
import 'package:voicememory_mobile/startup/startup_light_mode.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/belief_empty_state.dart';

/// Host PNG export for product simplification review.
///
/// CI runs the layout pass only (fast). Set `RUN_SCREENSHOT_EXPORT=true` to
/// write PNG files locally:
/// ```bash
/// RUN_SCREENSHOT_EXPORT=true flutter test test/export_product_simplification_png_test.dart
/// ```
void main() {
  setUpAll(() {
    StartupLightMode.resetForTest();
    StartupLightMode.setEnabledForTest(false);
    ForceScreenshotRepeatCard.testOverride = true;
  });

  tearDownAll(() {
    ForceScreenshotRepeatCard.testOverride = null;
    StartupLightMode.resetForTest();
  });

  testWidgets('export simplified product screens', (tester) async {
    const size = Size(393, 852);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final writeFiles = Platform.environment['RUN_SCREENSHOT_EXPORT'] == 'true';
    final outDir = Platform.environment['PRODUCT_SCREENSHOT_ROOT'] ??
        'build/product_screenshots';
    if (writeFiles) {
      await Directory(outDir).create(recursive: true);
    }

    final screens = <(String name, Widget child)>[
      ('onboarding-1', const OnboardingScreen()),
      ('belief-empty', const BeliefEmptyState(fillViewport: true)),
      ('archive-beliefs', const ArchiveBeliefScreen()),
    ];

    for (final s in screens) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(size: size),
            child: RepaintBoundary(
              key: const Key('export_product_repaint_boundary'),
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: s.$2,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const Key('export_product_repaint_boundary')),
        findsOneWidget,
      );
      if (writeFiles) {
        await _writePng(tester, '$outDir/${s.$1}.png');
      }
    }

    if (writeFiles) {
      // ignore: avoid_print
      print('Product screenshots: $outDir');
    }
  });
}

Future<void> _writePng(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('export_product_repaint_boundary')),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(bytes, isNotNull);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}
