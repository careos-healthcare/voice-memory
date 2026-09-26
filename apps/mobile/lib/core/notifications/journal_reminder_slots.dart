/// Local times for the daily reflection and the Sunday recap.
abstract final class JournalReminderSlots {
  JournalReminderSlots._();

  static const dailyHour = 20;
  static const dailyMinute = 0;
  static const weeklyHour = 9;
  static const weeklyMinute = 0;

  static int nextDailyEpoch(
    DateTime now, {
    int hour = dailyHour,
    int minute = dailyMinute,
  }) {
    return _next(now, hour: hour, minute: minute, weekday: null);
  }

  static int nextWeeklyEpoch(
    DateTime now, {
    int hour = weeklyHour,
    int minute = weeklyMinute,
    int weekday = DateTime.sunday,
  }) {
    return _next(now, hour: hour, minute: minute, weekday: weekday);
  }

  static int _next(
    DateTime now, {
    required int hour,
    required int minute,
    required int? weekday,
  }) {
    var when = DateTime(now.year, now.month, now.day, hour, minute);
    if (weekday != null) {
      final days = (weekday - when.weekday) % 7;
      when = when.add(Duration(days: days));
    }
    if (!when.isAfter(now)) {
      when = when.add(Duration(days: weekday == null ? 1 : 7));
    }
    return when.millisecondsSinceEpoch;
  }
}

/// True when the device zone changed and reminders must be booked again.
bool journalRemindersNeedReschedule({
  required String? previousZone,
  required String nextZone,
}) {
  final previous = previousZone?.trim() ?? '';
  final next = nextZone.trim();
  return previous.isNotEmpty && next.isNotEmpty && previous != next;
}
