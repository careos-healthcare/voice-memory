import 'package:archiveme_mobile/core/notifications/journal_reminder_slots.dart';
import 'package:archiveme_mobile/features/reminders/gentle_reminders_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

/// Sunday evening reminder that opens the latest weekly recap.
class WeeklyRecapNotificationService {
  WeeklyRecapNotificationService._();

  static const title = 'Your week in your own words';
  static const payload = 'weekly-recap';
  static const eveningHour = 18;

  static bool pendingOpen = false;
  static DateTime? lastScheduled;
  static void Function()? onRouteRequested;

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
    if (rawPayload == NotificationService.onThisDayPayload) {
      NotificationService.pendingOnThisDay = true;
    }
    if (pendingOpen || NotificationService.pendingOnThisDay) {
      onRouteRequested?.call();
    }
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
    if (!await NotificationService.ensurePermission()) return;
    final when = nextSundayEvening(now);
    lastScheduled = when;
    NotificationService.scheduledAt[NotificationService.weeklyId] = when;
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

/// Schedules and fires the Sunday recap and On This Day reminders.
class NotificationService {
  NotificationService._();

  static const weeklyId = 7101;
  static const onThisDayId = 7102;
  static const onThisDayPayload = 'on-this-day';
  static const morningHour = 9;

  static bool isNotificationPermissionGranted = true;
  static bool pendingOnThisDay = false;
  static final Map<int, DateTime> scheduledAt = {};

  static bool takeOnThisDay() {
    final open = pendingOnThisDay;
    pendingOnThisDay = false;
    return open;
  }

  static Future<bool> ensurePermission({
    Future<PermissionStatus> Function()? request,
  }) async {
    try {
      final status = await (request ?? Permission.notification.request)();
      final granted =
          status.isGranted || status.isLimited || status.isProvisional;
      isNotificationPermissionGranted = granted;
      if (status.isPermanentlyDenied) {
        debugPrint(
          'Notification permission is permanently denied. Open Settings to allow reminders.',
        );
        isNotificationPermissionGranted = false;
      }
      return isNotificationPermissionGranted;
    } on Object catch (error) {
      debugPrint('Notification permission request failed: $error');
      isNotificationPermissionGranted = false;
      return false;
    }
  }

  /// Next Sunday at 18:00. A Sunday after 18:00 waits until the following week.
  static Future<DateTime?> scheduleWeeklyRecap({
    DateTime? now,
    Future<PermissionStatus> Function()? requestPermission,
    Future<void> Function({
      required String title,
      required DateTime when,
      required String payload,
    })?
    book,
  }) async {
    if (!await ensurePermission(request: requestPermission)) return null;
    final when = WeeklyRecapNotificationService.nextSundayEvening(
      now ?? DateTime.now(),
    );
    scheduledAt[weeklyId] = when;
    WeeklyRecapNotificationService.lastScheduled = when;
    try {
      await (book ?? _scheduleBook)(
        title: WeeklyRecapNotificationService.title,
        when: when,
        payload: WeeklyRecapNotificationService.payload,
      );
    } on Object catch (error) {
      debugPrint('Weekly recap was not scheduled: $error');
      return null;
    }
    return when;
  }

  /// Morning reminder when [entry] shares today's month and day in an earlier year.
  static Future<DateTime?> scheduleOnThisDay({
    required JournalEntry entry,
    DateTime? now,
    Future<PermissionStatus> Function()? requestPermission,
    Future<void> Function({
      required String title,
      required DateTime when,
      required String payload,
    })?
    book,
  }) async {
    final clock = now ?? DateTime.now();
    final recorded = entry.createdAt;
    final anniversary =
        recorded.month == clock.month &&
        recorded.day == clock.day &&
        recorded.year < clock.year;
    if (!anniversary) return null;
    if (!await ensurePermission(request: requestPermission)) return null;
    final when = DateTime(clock.year, clock.month, clock.day, morningHour);
    scheduledAt[onThisDayId] = when;
    try {
      await (book ?? _scheduleBook)(
        title: GentleRemindersCopy.onThisDayNotificationTitle,
        when: when,
        payload: onThisDayPayload,
      );
    } on Object catch (error) {
      debugPrint('On This Day was not scheduled: $error');
      return null;
    }
    return when;
  }

  static Future<void> triggerTestWeeklyRecapNotification({
    Future<PermissionStatus> Function()? requestPermission,
    Future<void> Function({
      required int id,
      required String title,
      required String body,
      required String payload,
    })?
    show,
  }) async {
    if (!await ensurePermission(request: requestPermission)) return;
    await (show ?? _showNow)(
      id: weeklyId,
      title: WeeklyRecapNotificationService.title,
      body: 'Open your week.',
      payload: WeeklyRecapNotificationService.payload,
    );
  }

  static Future<void> triggerTestOnThisDayNotification(
    JournalEntry mockEntry, {
    Future<PermissionStatus> Function()? requestPermission,
    Future<void> Function({
      required int id,
      required String title,
      required String body,
      required String payload,
    })?
    show,
  }) async {
    if (!await ensurePermission(request: requestPermission)) return;
    final quote = mockEntry.transcript.trim();
    await (show ?? _showNow)(
      id: onThisDayId,
      title: GentleRemindersCopy.onThisDayNotificationTitle,
      body: quote.isEmpty ? 'A moment from this day.' : quote,
      payload: onThisDayPayload,
    );
  }

  static Future<List<String>> checkPendingNotifications({
    Future<List<PendingNotificationRequest>> Function()? readPending,
    void Function(String line)? log,
  }) async {
    final pending = await (readPending ?? _readPending)();
    final lines = <String>[
      for (final item in pending)
        'id=${item.id} at=${scheduledAt[item.id]?.toIso8601String() ?? 'unspecified'} payload=${item.payload ?? ''}',
    ];
    final write = log ?? debugPrint;
    for (final line in lines) {
      write(line);
    }
    if (lines.isEmpty) write('No pending notifications.');
    return lines;
  }

  static Future<void> _scheduleBook({
    required String title,
    required DateTime when,
    required String payload,
  }) async {
    final id = payload == onThisDayPayload ? onThisDayId : weeklyId;
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.zonedSchedule(
      id,
      title,
      payload == onThisDayPayload ? 'A moment from this day.' : 'Open your week.',
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

Future<void> _showNow({
  required int id,
  required String title,
  required String body,
  required String payload,
}) {
  return FlutterLocalNotificationsPlugin().show(
    id,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails('weekly_recap', 'Weekly recap'),
      iOS: DarwinNotificationDetails(),
    ),
    payload: payload,
  );
}

Future<List<PendingNotificationRequest>> _readPending() {
  return FlutterLocalNotificationsPlugin().pendingNotificationRequests();
}
