import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/archive_memory/archive_evolution_engine.dart';
import 'package:archiveme_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:archiveme_mobile/features/archive_memory/archive_evolution_store.dart';
import 'package:archiveme_mobile/features/moments/key_moment_store.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_coordinator.dart';

/// Builds and persists the latest pattern evolution timeline. Always fails
/// softly so it never blocks the Patterns tab from loading.
abstract class ArchiveEvolutionCoordinator {
  ArchiveEvolutionCoordinator._();

  static ArchiveEvolutionStore _store() => ArchiveEvolutionStore.instance();

  static Future<ArchiveEvolutionTimeline?> refresh() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.archiveEvolutionTimelineSample;
    }
    try {
      final memory = await PatternMemoryCoordinator.loadActive();
      final moments = await KeyMomentStore.instance().loadAll();
      final progress = await PatternMemoryCoordinator.loadLatestProgress();
      final weeklyRecap =
          await PatternMemoryCoordinator.loadLatestWeeklyRecap();

      final timeline = buildArchiveEvolutionTimeline(
        memory: memory,
        keyMoments: moments,
        progress: progress,
        weeklyRecap: weeklyRecap,
      );

      if (timeline == null) {
        await _store().clear();
        return null;
      }
      await _store().saveLatest(timeline);
      return timeline;
    } catch (_, stackTrace) {
      return null;
    }
  }

  static Future<ArchiveEvolutionTimeline?> loadLatest() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.archiveEvolutionTimelineSample;
    }
    try {
      return await _store().loadLatest();
    } catch (_, stackTrace) {
      return null;
    }
  }
}