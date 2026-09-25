import 'package:archiveme_mobile/features/reminders/gentle_reminders_copy.dart';

/// Hours when a reminder must not fire. [startMinute] and [endMinute] are
/// minutes from midnight. An overnight window has [startMinute] > [endMinute].
class QuietHours {
  const QuietHours({required this.startMinute, required this.endMinute});

  static const off = QuietHours(startMinute: 0, endMinute: 0);

  final int startMinute;
  final int endMinute;

  bool get isOff => startMinute == endMinute;

  bool contains(DateTime when) {
    if (isOff) return false;
    final minute = when.hour * 60 + when.minute;
    if (startMinute < endMinute) {
      return minute >= startMinute && minute < endMinute;
    }
    return minute >= startMinute || minute < endMinute;
  }

  /// Moves [when] to the first minute outside this window.
  DateTime place(DateTime when) {
    if (!contains(when)) return when;
    final end = DateTime(when.year, when.month, when.day, 0, endMinute);
    if (!end.isAfter(when)) {
      return end.add(const Duration(days: 1));
    }
    return end;
  }
}

class GentleReminderNotice {
  const GentleReminderNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
  });

  final String id;
  final String title;
  final String body;
  final DateTime when;
}

class OnThisDayCandidate {
  const OnThisDayCandidate({
    required this.entryId,
    required this.createdAt,
    required this.verbatimQuote,
  });

  final String entryId;
  final DateTime createdAt;
  final String verbatimQuote;
}

/// Pure scheduling. Callers persist and send the notices.
abstract final class GentleReminderSchedule {
  GentleReminderSchedule._();

  static const dailyId = 'gentle.daily';
  static const dailySlotCount = 14;

  static String dailySlotId(int index) => '$dailyId.$index';

  static String onThisDayId(String entryId) => 'gentle.on_this_day.$entryId';

  static String checkBackId(String entryId) => 'gentle.check_back.$entryId';

  static DateTime nextDaily({
    required DateTime now,
    required int hour,
    required int minute,
    QuietHours quietHours = QuietHours.off,
  }) {
    var when = DateTime(now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    return quietHours.place(when);
  }

  /// The next [dailySlotCount] days at the chosen time.
  ///
  /// One-shot alarms do not repeat, so each day is its own notification.
  /// [GentleRemindersService.rescheduleReminders] replaces the window on
  /// launch and resume.
  static List<GentleReminderNotice> dailySlots({
    required bool enabled,
    required DateTime now,
    required int hour,
    required int minute,
    QuietHours quietHours = QuietHours.off,
  }) {
    if (!enabled) return const [];
    final first = nextDaily(
      now: now,
      hour: hour,
      minute: minute,
      quietHours: quietHours,
    );
    return [
      for (var index = 0; index < dailySlotCount; index++)
        GentleReminderNotice(
          id: dailySlotId(index),
          title: GentleRemindersCopy.dailyNotificationTitle,
          body: GentleRemindersCopy.dailyNotificationBody,
          when: first.add(Duration(days: index)),
        ),
    ];
  }

  static GentleReminderNotice? daily({
    required bool enabled,
    required DateTime now,
    required int hour,
    required int minute,
    QuietHours quietHours = QuietHours.off,
  }) {
    if (!enabled) return null;
    return GentleReminderNotice(
      id: dailyId,
      title: GentleRemindersCopy.dailyNotificationTitle,
      body: GentleRemindersCopy.dailyNotificationBody,
      when: nextDaily(
        now: now,
        hour: hour,
        minute: minute,
        quietHours: quietHours,
      ),
    );
  }

  static List<GentleReminderNotice> onThisDay({
    required bool enabled,
    required DateTime now,
    required List<OnThisDayCandidate> entries,
    QuietHours quietHours = QuietHours.off,
    int hour = 9,
    int minute = 0,
  }) {
    if (!enabled) return const [];
    final when = nextDaily(
      now: now,
      hour: hour,
      minute: minute,
      quietHours: quietHours,
    );
    final notices = <GentleReminderNotice>[];
    for (final entry in entries) {
      final quote = entry.verbatimQuote.trim();
      if (quote.isEmpty || !_isAnniversary(entry.createdAt, now)) continue;
      notices.add(
        GentleReminderNotice(
          id: onThisDayId(entry.entryId),
          title: GentleRemindersCopy.onThisDayNotificationTitle,
          body: quote,
          when: when,
        ),
      );
    }
    return notices;
  }

  static GentleReminderNotice checkBack({
    required String entryId,
    required String verbatimQuote,
    required DateTime now,
    QuietHours quietHours = QuietHours.off,
  }) {
    final quote = verbatimQuote.trim();
    return GentleReminderNotice(
      id: checkBackId(entryId),
      title: GentleRemindersCopy.checkBackNotificationTitle,
      body: quote,
      when: quietHours.place(now.add(const Duration(days: 7))),
    );
  }

  static bool offerAfterThirdEntry({
    required int entryCount,
    required bool alreadyAnswered,
  }) => entryCount >= 3 && !alreadyAnswered;

  static bool _isAnniversary(DateTime createdAt, DateTime now) {
    final created = _dateOnly(createdAt.toLocal());
    final today = _dateOnly(now.toLocal());
    if (created == today.subtract(const Duration(days: 7))) return true;
    if (created == _shiftMonths(today, -1)) return true;
    if (created == DateTime(today.year - 1, today.month, today.day)) {
      return true;
    }
    return false;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _shiftMonths(DateTime date, int months) {
    final monthIndex = date.month - 1 + months;
    final year = date.year + (monthIndex ~/ 12);
    final month = monthIndex % 12;
    final normalizedMonth = month < 0 ? month + 12 : month;
    final normalizedYear = month < 0 ? year - 1 : year;
    final lastDay = DateTime(normalizedYear, normalizedMonth + 2, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(normalizedYear, normalizedMonth + 1, day);
  }
}
