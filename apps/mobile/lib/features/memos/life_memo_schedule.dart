/// When the Sunday memo should run, in local time.
abstract final class LifeMemoSchedule {
  static const hour = 20;
  static const taskName = 'lifeMemoSunday';
  static const taskUniqueName = 'com.voicememory.mobile.lifeMemoSunday';

  /// The next Sunday at 20:00, or the current moment when that slot is now.
  static DateTime upcomingSundayAt20(DateTime now) {
    final local = now.toLocal();
    var candidate = DateTime(local.year, local.month, local.day, hour);
    final daysUntilSunday = (DateTime.sunday - local.weekday) % 7;
    candidate = candidate.add(Duration(days: daysUntilSunday));
    if (candidate.isBefore(local)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  /// Delay from [now] until [upcomingSundayAt20].
  static Duration initialDelay(DateTime now) {
    final wait = upcomingSundayAt20(now).difference(now.toLocal());
    if (wait.isNegative) return Duration.zero;
    return wait;
  }

  /// Sunday 20:00 that this moment belongs to, once that clock time has passed.
  static DateTime currentSlot(DateTime now) {
    final upcoming = upcomingSundayAt20(now);
    if (!upcoming.isAfter(now.toLocal())) return upcoming;
    return upcoming.subtract(const Duration(days: 7));
  }

  /// First Sunday of a month also writes the 30-day memo.
  static bool isMonthlySlot(DateTime slot) => slot.day <= 7;
}
