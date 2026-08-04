import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/screens/archive_belief_screen.dart';
import 'package:voicememory_mobile/screens/belief_changes_screen.dart';
import 'package:voicememory_mobile/screens/beliefs_screen.dart';
import 'package:voicememory_mobile/screens/onboarding_screen.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/belief_empty_state.dart';

/// Host PNG export for product simplification review.
void main() {
  testWidgets('export simplified product screens', (tester) async {
    // Manual asset export — skip in automated full-suite runs (RecordScreen bootstrap hangs).
    if (Platform.environment['ARCHIVEME_RUN_PNG_EXPORT'] != 'true') return;

    const size = Size(393, 852);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final home = Platform.environment['HOME'] ?? '';
    final outDir = home.isNotEmpty
        ? '$home/Desktop/upload12/screenshots'
        : 'build/product_screenshots';
    await Directory(outDir).create(recursive: true);

    final screens = <(String name, Widget child)>[
      ('onboarding-1', const OnboardingScreen()),
      ('belief-empty', const BeliefEmptyState(fillViewport: true)),
      ('archive-beliefs', const ArchiveBeliefScreen()),
      ('beliefs-explorer', const BeliefsScreen()),
      ('belief-changes', const BeliefChangesScreen()),
      ('record', const RecordScreen()),
    ];

    for (final s in screens) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(size: size),
            child: RepaintBoundary(
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
      await tester.pump(const Duration(milliseconds: 200));

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$outDir/${s.$1}.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    }

    // ignore: avoid_print
    print('Product screenshots: $outDir');
  });
}
