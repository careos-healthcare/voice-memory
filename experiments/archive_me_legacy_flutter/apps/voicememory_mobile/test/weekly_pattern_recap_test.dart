import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_comparison_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_streak_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/weekly_pattern_recap_engine.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

ReturnComparison _cmp() {
  return ReturnComparison(
    yesterdayWatchFor: 'responsibility',
    todayReflectionSummary: 'yes too fast',
    comparisonStatus: ReturnComparisonStatus.repeated,
    headline: 'h',
    body: 'b',
    chips: const ['showed up again', 'saying yes too fast'],
    createdAt: DateTime(2026, 6, 1),
  );
}

void main() {
  test('weekly recap appears only after enough data', () {
    const engine = WeeklyPatternRecapEngine();
    expect(engine.build(comparisons: [_cmp(), _cmp()]), isNull);

    final recap = engine.build(comparisons: [_cmp(), _cmp(), _cmp()]);
    expect(recap, isNotNull);
    expect(recap!.title, ConsumerUiCopy.weeklyRecapTitle);
    expect(recap.body, isNotEmpty);
  });

  test('weekly recap uses streak completed dates', () {
    const engine = WeeklyPatternRecapEngine();
    final streak = ReturnStreak(
      currentStreakDays: 3,
      longestStreakDays: 3,
      completedDates: [
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 2),
        DateTime(2026, 6, 3),
      ],
      headline: 'h',
      body: 'b',
    );
    final recap = engine.build(streak: streak, comparisons: const []);
    expect(recap, isNotNull);
  });

  test('screenshot mode exposes weekly recap sample', () {
    final recap = ScreenshotSampleData.weeklyRecapSample;
    expect(recap.title, ConsumerUiCopy.weeklyRecapTitle);
    expect(recap.body, contains('Responsibility'));
    expect(recap.chips.length, greaterThanOrEqualTo(2));
  });
}
