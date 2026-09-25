import 'package:archiveme_mobile/core/notifications/journal_reminder_slots.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Payload that opens the capture screen and starts recording.
abstract final class JournalNotificationPayload {
  JournalNotificationPayload._();

  static const autoRecord = 'capture:auto-record';

  static bool pendingAutoRecord = false;

  static bool takeAutoRecord() {
    final pending = pendingAutoRecord;
    pendingAutoRecord = false;
    return pending;
  }

  static void remember(String? payload) {
    if (payload == autoRecord) pendingAutoRecord = true;
  }

  static String get captureLocation =>
      '${RouteCatalog.recordHome}?autoRecord=1';
}

/// Exact alarms on Android. iOS uses the same scheduled notification details.
const journalAndroidScheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

class JournalReminderPlan {
  const JournalReminderPlan({
    required this.dailyEpoch,
    required this.weeklyEpoch,
  });

  /// Last plan built from the Settings reminder switches.
  static JournalReminderPlan? scheduled;

  final int? dailyEpoch;
  final int? weeklyEpoch;

  factory JournalReminderPlan.fromSettings({
    required DateTime now,
    required bool dailyEnabled,
    required bool weeklyEnabled,
  }) {
    return JournalReminderPlan(
      dailyEpoch: dailyEnabled ? JournalReminderSlots.nextDailyEpoch(now) : null,
      weeklyEpoch: weeklyEnabled
          ? JournalReminderSlots.nextWeeklyEpoch(now)
          : null,
    );
  }
}
