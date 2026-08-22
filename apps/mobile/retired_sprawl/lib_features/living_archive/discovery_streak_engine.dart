import 'package:archiveme_mobile/features/living_archive/discovery_streak_store.dart';
import 'package:archiveme_mobile/features/living_archive/living_archive_models.dart';

/// Consecutive days with archive discoveries surfaced (not recording days).
class DiscoveryStreakEngine {
  const DiscoveryStreakEngine();

  DiscoveryStreak compute(Set<String> discoveryDayKeys, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final today = DiscoveryStreakStore.dayKey(clock);
    final hadToday = discoveryDayKeys.contains(today);

    var streak = 0;
    var cursor = hadToday ? clock : clock.subtract(const Duration(days: 1));

    while (discoveryDayKeys.contains(DiscoveryStreakStore.dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return DiscoveryStreak(
      consecutiveDays: streak,
      hadDiscoveryToday: hadToday,
    );
  }
}