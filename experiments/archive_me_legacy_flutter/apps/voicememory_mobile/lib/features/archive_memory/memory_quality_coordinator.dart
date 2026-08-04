import '../../config/screenshot_mode.dart';
import '../../config/screenshot_sample_data.dart';
import '../../services/app_services.dart';
import '../archive_memory/archive_evolution_coordinator.dart';
import '../moments/key_moment_store.dart';
import '../pattern_memory/pattern_memory_coordinator.dart';
import 'archive_memory_summary_coordinator.dart';
import 'memory_quality_engine.dart';
import 'memory_quality_model.dart';

/// Loads saved pattern data and returns a conservative [MemoryQuality].
abstract class MemoryQualityCoordinator {
  MemoryQualityCoordinator._();

  static Future<MemoryQuality> load() async {
    if (ScreenshotMode.memoryQualityPreview) {
      return ScreenshotSampleData.memoryQualitySample;
    }
    if (!AppServices.isInitialized) return MemoryQuality.hidden;
    try {
      final summary = await ArchiveMemorySummaryCoordinator.loadLatest();
      final memory = await PatternMemoryCoordinator.loadActive();
      final keyMoments = await KeyMomentStore.instance().loadAll();
      final timeline = await ArchiveEvolutionCoordinator.loadLatest();
      final progress = await PatternMemoryCoordinator.loadLatestProgress();

      return buildMemoryQuality(
        summary: summary,
        memory: memory,
        keyMoments: keyMoments,
        timeline: timeline,
        progress: progress,
      );
    } catch (_) {
      return MemoryQuality.hidden;
    }
  }
}
