import '../../config/screenshot_mode.dart';
import '../../config/screenshot_sample_data.dart';
import '../../services/app_services.dart';
import 'change_summary_engine.dart';
import 'change_summary_model.dart';
import 'change_summary_store.dart';
import 'return_comparison_model.dart';
import 'return_comparison_store.dart';
import 'return_streak_coordinator.dart';
import 'return_streak_model.dart';
import 'weekly_pattern_recap_engine.dart';

/// Updates streak, change summary, and recap after a return comparison.
abstract class ReturnRetentionCoordinator {
  ReturnRetentionCoordinator._();

  static ReturnComparisonStore _comparisonStore() =>
      ReturnComparisonStore(AppServices.instance.prefs);

  static ChangeSummaryStore _summaryStore() =>
      ChangeSummaryStore(AppServices.instance.prefs);

  static Future<void> onComparisonSaved(
    ReturnComparison comparison, {
    DateTime? now,
  }) async {
    if (ScreenshotMode.enabled) return;

    await ReturnStreakCoordinator.recordCompletion(now: now);

    final recent = await _comparisonStore().readRecent();
    final prior = recent
        .where((c) => c.createdAt != comparison.createdAt)
        .toList();
    final summary = const ChangeSummaryEngine().build(
      latest: comparison,
      recent: prior,
      now: now,
    );
    await _summaryStore().write(summary);
  }

  static Future<ReturnStreak?> loadStreak() => ReturnStreakCoordinator.load();

  static Future<ChangeSummary?> loadChangeSummary() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.changeSummarySample;
    }
    return _summaryStore().read();
  }

  static Future<WeeklyPatternRecap?> loadWeeklyRecap() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.weeklyRecapSample;
    }
    final streak = await ReturnStreakCoordinator.load();
    final comparisons = await _comparisonStore().readRecent();
    return const WeeklyPatternRecapEngine().build(
      streak: streak,
      comparisons: comparisons,
    );
  }
}
