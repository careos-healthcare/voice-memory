import '../../config/screenshot_mode.dart';
import '../../config/screenshot_sample_data.dart';
import '../../product/consumer_ui_copy.dart';
import '../../services/app_services.dart';
import 'return_streak_model.dart';
import 'return_streak_store.dart';
import 'tomorrow_commitment_model.dart';

abstract final class ReturnStreakCoordinator {
  ReturnStreakCoordinator._();

  static ReturnStreakStore _store() =>
      ReturnStreakStore(AppServices.instance.prefs);

  static Future<ReturnStreak?> load() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.returnStreakSample;
    }
    return _store().read();
  }

  static Future<ReturnStreak> recordCompletion({DateTime? now}) async {
    if (ScreenshotMode.enabled) {
      return ScreenshotSampleData.returnStreakSample;
    }

    final clock = now ?? DateTime.now();
    final today = TomorrowCommitment.dateOnly(clock);
    final store = _store();
    final existing = await store.read();

    final dates = existing == null
        ? <DateTime>[today]
        : [...existing.completedDates, today];

    final unique = ReturnStreak.uniqueSortedDates(dates);
    final current = ReturnStreak.currentStreakFromDates(unique, clock);
    final longest = ReturnStreak.longestStreakFromDates(unique);
    final copy = _copyForStreak(current);

    final streak = ReturnStreak(
      currentStreakDays: current,
      longestStreakDays: longest,
      lastCompletedDate: today,
      completedDates: unique,
      headline: copy.$1,
      body: copy.$2,
    );

    await store.write(streak);
    return streak;
  }

  static (String, String) _copyForStreak(int days) {
    if (days <= 1) {
      return (
        ConsumerUiCopy.returnStreakHeadlineSingle,
        ConsumerUiCopy.returnStreakBodySingle,
      );
    }
    return (
      ConsumerUiCopy.returnStreakHeadline,
      ConsumerUiCopy.returnStreakBody(days),
    );
  }
}
