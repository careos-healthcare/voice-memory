import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:voicememory_mobile/features/archive_beliefs/belief_change_timeline.dart';
import 'package:voicememory_mobile/product/belief_product_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/archive_beliefs_dashboard.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_empty_view.dart';

/// Headless `toImage()` often hangs in CI/VM. Set `EXPORT_VALUE_CLARITY_PNG=1` to run.
bool get _runExport => Platform.environment['EXPORT_VALUE_CLARITY_PNG'] == '1';

void main() {
  testWidgets('export value clarity screens', (tester) async {
    if (!_runExport) {
      // ignore: avoid_print
      print(
        'Skipped PNG export (set EXPORT_VALUE_CLARITY_PNG=1). '
        'Prefer simulator screenshots — see tool/run_value_clarity_screenshot_export.sh',
      );
      return;
    }
    const size = Size(393, 852);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final home = Platform.environment['HOME'] ?? '';
    final outDir = home.isNotEmpty
        ? '$home/Desktop/upload12/screenshots'
        : 'build/value_clarity';
    await Directory(outDir).create(recursive: true);

    const sampleBelief = ArchiveBeliefCardModel(
      id: 'sample',
      statement: 'I need to prove myself.',
      confidencePercent: 78,
      evidenceSummary: 'Appeared in 12 reflections.',
      whyExplanation: 'Named from recurring themes.',
      section: ArchiveBeliefSection.current,
    );

    final screens = <(String, Widget)>[
      ('value-empty-state', const PatternsEmptyView(fillViewport: true)),
      (
        'value-archive-hero',
        Material(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BeliefSectionHeading(
                  title: BeliefProductCopy.archiveHeroHeading,
                ),
                const SizedBox(height: 12),
                const ArchiveHeroBeliefCard(
                  belief: sampleBelief,
                  reflectionsAnalysed: 12,
                ),
              ],
            ),
          ),
        ),
      ),
      (
        'value-changes-story',
        Material(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  BeliefProductCopy.changesScreenTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                BeliefChangeStories(
                  items: [
                    BeliefChangeTimelineItem(
                      kind: BeliefChangeKind.strengthening,
                      statement: 'I need to prove myself',
                      detail:
                          'This theme is showing up more often in recent reflections.',
                      sortOrder: 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
      await tester.pump(const Duration(milliseconds: 100));

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final bytes = await tester.binding.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      if (bytes == null) {
        fail('PNG export failed for ${s.$1}');
      }
      await File(
        '$outDir/${s.$1}.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
    }

    // ignore: avoid_print
    print('Value clarity screenshots: $outDir');
  }, timeout: const Timeout(Duration(seconds: 45)));
}
