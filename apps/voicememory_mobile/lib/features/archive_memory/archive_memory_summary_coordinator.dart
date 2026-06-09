import '../../config/screenshot_mode.dart';
import '../../config/screenshot_sample_data.dart';
import '../moments/key_moment_store.dart';
import '../pattern_map/pattern_map_engine.dart';
import '../pattern_memory/pattern_memory_coordinator.dart';
import 'archive_memory_summary_engine.dart';
import 'archive_memory_summary_model.dart';
import 'archive_memory_summary_store.dart';

/// Builds and persists the latest "What ArchiveMe remembers" summary from
/// everything the archive already stores. Always fails softly so it can never
/// block the Patterns tab from loading.
abstract final class ArchiveMemorySummaryCoordinator {
  ArchiveMemorySummaryCoordinator._();

  static ArchiveMemorySummaryStore _store() =>
      ArchiveMemorySummaryStore.instance();

  /// Rebuilds the summary from current memory/progress/recap/key moments,
  /// saves it as the latest, and returns it. Returns null when there is not
  /// yet enough, or in the rare case something goes wrong.
  static Future<ArchiveMemorySummary?> refresh() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.archiveMemorySummarySample;
    }
    try {
      final memory = await PatternMemoryCoordinator.loadActive();
      final moments = await KeyMomentStore.instance().loadAll();
      final progress = await PatternMemoryCoordinator.loadLatestProgress();
      final weeklyRecap =
          await PatternMemoryCoordinator.loadLatestWeeklyRecap();
      final patternMap = memory == null
          ? null
          : buildPatternMap(memory: memory, moments: moments);

      final summary = buildArchiveMemorySummary(
        memory: memory,
        patternMap: patternMap,
        keyMoments: moments,
        progress: progress,
        weeklyRecap: weeklyRecap,
      );

      if (summary == null) {
        await _store().clear();
        return null;
      }
      await _store().saveLatest(summary);
      return summary;
    } catch (_) {
      // Soft failure: never block the surface that shows this.
      return null;
    }
  }

  /// The most recently saved summary, if any. In screenshot mode this returns
  /// the polished sample.
  static Future<ArchiveMemorySummary?> loadLatest() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.archiveMemorySummarySample;
    }
    try {
      return await _store().loadLatest();
    } catch (_) {
      return null;
    }
  }
}
