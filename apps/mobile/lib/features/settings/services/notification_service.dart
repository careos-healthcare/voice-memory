import 'package:archiveme_mobile/core/notifications/journal_reminder_slots.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Sunday evening reminder that opens the latest weekly recap.
class WeeklyRecapNotificationService {
  WeeklyRecapNotificationService._();

  static const title = 'Your week in your own words';
  static const payload = 'weekly-recap';
  static const eveningHour = 18;

  static bool pendingOpen = false;
  static DateTime? lastScheduled;

  static DateTime nextSundayEvening(DateTime now) {
    return DateTime.fromMillisecondsSinceEpoch(
      JournalReminderSlots.nextWeeklyEpoch(
        now,
        hour: eveningHour,
        minute: 0,
      ),
    );
  }

  static void rememberTap(String? rawPayload) {
    if (rawPayload == payload) pendingOpen = true;
  }

  static bool takePending() {
    final open = pendingOpen;
    pendingOpen = false;
    return open;
  }

  static Future<void> schedule({
    required DateTime now,
    Future<void> Function({
      required String title,
      required DateTime when,
      required String payload,
    })?
    book,
  }) async {
    final when = nextSundayEvening(now);
    lastScheduled = when;
    try {
      await (book ?? _book)(title: title, when: when, payload: payload);
    } on Object {
      return;
    }
  }

  static Future<void> _book({
    required String title,
    required DateTime when,
    required String payload,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.zonedSchedule(
      7101,
      title,
      'Open your week.',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('weekly_recap', 'Weekly recap'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }
}
