import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/archive_memory/archive_evolution_coordinator.dart';
import 'package:archiveme_mobile/features/archive_memory/archive_memory_summary_coordinator.dart';
import 'package:archiveme_mobile/features/moments/key_moment_store.dart';
import 'package:archiveme_mobile/features/pattern_map/pattern_map_engine.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_coordinator.dart';
import 'package:archiveme_mobile/features/pattern_profile/pattern_profile_engine.dart';
import 'package:archiveme_mobile/features/pattern_profile/pattern_profile_model.dart';

/// Loads saved pattern data and builds a [PatternProfile]. Always fails softly.
abstract class PatternProfileCoordinator {
  PatternProfileCoordinator._();

  static Future<PatternProfile?> load() async {
    if (ScreenshotMode.patternProfilePreview) {
      return _screenshotProfile();
    }
    try {
      final memory = await PatternMemoryCoordinator.loadActive();
      final summary = await ArchiveMemorySummaryCoordinator.loadLatest();
      final timeline = await ArchiveEvolutionCoordinator.loadLatest();
      final moments = await KeyMomentStore.instance().loadAll();
      final map = memory != null
          ? buildPatternMap(memory: memory, moments: moments)
          : null;

      return buildPatternProfile(
        memory: memory,
        summary: summary,
        map: map,
        timeline: timeline,
        keyMoments: moments,
      );
    } catch (_, stackTrace) {
      return null;
    }
  }

  static PatternProfile? _screenshotProfile() {
    final memory = ScreenshotSampleData.patternMemorySample;
    final moments = ScreenshotSampleData.archiveCleanKeyMomentsSample;
    final summary = ScreenshotSampleData.archiveMemorySummarySample;
    final timeline = ScreenshotSampleData.archiveEvolutionTimelineSample;
    final map = buildPatternMap(memory: memory, moments: moments);

    return buildPatternProfile(
      memory: memory,
      summary: summary,
      map: map,
      timeline: timeline,
      keyMoments: moments,
    );
  }
}