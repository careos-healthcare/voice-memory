/// Builds a compact weekly review from existing archive proof engines.
abstract final class WeeklyArchiveWeekReviewEngine {
  WeeklyArchiveWeekReviewEngine._();

  static const weekWindowDays = 7;
  static const minEntriesForFiveEntryGate = 5;
}
