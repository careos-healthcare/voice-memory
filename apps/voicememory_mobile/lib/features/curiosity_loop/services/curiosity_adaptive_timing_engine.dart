import '../../../models/journal_entry.dart';

/// Computes when to fire the next curiosity notification from journal rhythm.
class CuriosityAdaptiveTimingEngine {
  const CuriosityAdaptiveTimingEngine();

  static const fallbackDelay = Duration(hours: 24);
  static const minHistoryEntries = 3;
  static const maxSampleSize = 5;

  /// Returns how long to wait after [currentEntryTime] before reminding.
  ///
  /// Uses the average recording hour from the last five entries and targets
  /// the next calendar day at that time. With fewer than three entries,
  /// returns a fixed twenty-four hour delay.
  Duration calculateOptimalDelay({
    required List<JournalEntry> history,
    required DateTime currentEntryTime,
  }) {
    if (history.length < minHistoryEntries) {
      return fallbackDelay;
    }

    final recent = _recentEntries(history, maxSampleSize);
    final averageHour = recent
            .map(_hourOfDay)
            .reduce((sum, hour) => sum + hour) /
        recent.length;

    final currentLocal = currentEntryTime.toLocal();
    final nextDay = DateTime(
      currentLocal.year,
      currentLocal.month,
      currentLocal.day,
    ).add(const Duration(days: 1));

    final targetHour = averageHour.floor().clamp(0, 23);
    final targetMinute =
        ((averageHour - targetHour) * 60).round().clamp(0, 59);

    final target = DateTime(
      nextDay.year,
      nextDay.month,
      nextDay.day,
      targetHour,
      targetMinute,
    );

    final delay = target.difference(currentLocal);
    if (!delay.isNegative) return delay;

    // Safety fallback — next-day target should always be in the future.
    return fallbackDelay;
  }

  static List<JournalEntry> _recentEntries(
    List<JournalEntry> history,
    int limit,
  ) {
    final sorted = [...history]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (sorted.length <= limit) return sorted;
    return sorted.sublist(sorted.length - limit);
  }

  static double _hourOfDay(JournalEntry entry) {
    final local = entry.createdAt.toLocal();
    return local.hour + (local.minute / 60.0);
  }
}
