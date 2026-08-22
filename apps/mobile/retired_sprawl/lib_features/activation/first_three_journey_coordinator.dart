import 'package:archiveme_mobile/config/first_three_session_preview.dart';
import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/activation/first_three_journey_engine.dart';
import 'package:archiveme_mobile/features/activation/first_three_journey_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/active_pattern_thread_coordinator.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_comparison_coordinator.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Exposes first-three journey state to Record and Patterns.
abstract class FirstThreeJourneyCoordinator {
  FirstThreeJourneyCoordinator._();

  static const _engine = FirstThreeJourneyEngine();

  static Future<int> reflectionCount() async {
    final preview = FirstThreeSessionPreview.forcedReflectionCount;
    if (preview != null) return preview;
    if (ScreenshotMode.enabled &&
        ScreenshotMode.screenshotJourneyReflectionCount >= 0) {
      return ScreenshotMode.screenshotJourneyReflectionCount;
    }
    final entries = await AppServices.instance.journal.loadAll();
    return entries.length;
  }

  static Future<FirstThreeJourneyModel> load() async {
    if (ScreenshotMode.enabled &&
        ScreenshotMode.screenshotJourneyReflectionCount >= 0) {
      return ScreenshotSampleData.firstThreeJourneyForCount(
        ScreenshotMode.screenshotJourneyReflectionCount,
      );
    }
    final count = await reflectionCount();
    final entries =
        ScreenshotMode.enabled &&
            ScreenshotMode.screenshotJourneyReflectionCount >= 0
        ? <JournalEntry>[]
        : await AppServices.instance.journal.loadAll();
    final thread = await ActivePatternThreadCoordinator.loadCurrentThread();
    final comparison = await ReturnComparisonCoordinator.loadLatest();
    return _engine.build(
      reflectionCount: count,
      entries: entries,
      activeThread: thread,
      latestComparison: comparison,
    );
  }

  static Future<FirstThreeJourneyModel> loadForCount(int count) async {
    return _engine.build(reflectionCount: count);
  }

  static bool isBeforeComplete(int reflectionCount) => reflectionCount < 3;

  static bool shouldHideAdvancedRetention(int reflectionCount) =>
      reflectionCount < 3;
}