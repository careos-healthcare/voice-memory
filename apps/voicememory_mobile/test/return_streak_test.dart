import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_streak_coordinator.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_streak_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_streak_store.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_commitment_model.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  test('streak increments on consecutive days', () {
    final dates = [
      DateTime(2026, 6, 1),
      DateTime(2026, 6, 2),
      DateTime(2026, 6, 3),
    ];
    expect(ReturnStreak.currentStreakFromDates(dates, DateTime(2026, 6, 3)), 3);
    expect(ReturnStreak.longestStreakFromDates(dates), 3);
  });

  test('streak does not duplicate same day', () {
    final day = DateTime(2026, 6, 5);
    final dates = ReturnStreak.uniqueSortedDates([day, day, day]);
    expect(dates.length, 1);
    expect(ReturnStreak.currentStreakFromDates(dates, day), 1);
  });

  test('streak resets after missed day', () {
    final dates = [
      DateTime(2026, 6, 1),
      DateTime(2026, 6, 2),
      DateTime(2026, 6, 4),
    ];
    expect(ReturnStreak.currentStreakFromDates(dates, DateTime(2026, 6, 4)), 1);
    expect(ReturnStreak.longestStreakFromDates(dates), 2);
  });

  test('screenshot mode exposes 3-day streak sample', () {
    final streak = ScreenshotSampleData.returnStreakSample;
    expect(streak.currentStreakDays, 3);
    expect(streak.showOnPatterns, isTrue);
    expect(streak.headline, contains('kept the loop'));
  });
}
