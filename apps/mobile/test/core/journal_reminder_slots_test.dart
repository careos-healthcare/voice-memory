import 'package:archiveme_mobile/core/notifications/journal_notification_plan.dart';
import 'package:archiveme_mobile/core/notifications/journal_reminder_slots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily reflection epoch is the next 8:00 PM', () {
    final fridayAfternoon = DateTime(2026, 9, 25, 15);
    final epoch = JournalReminderSlots.nextDailyEpoch(fridayAfternoon);
    expect(
      DateTime.fromMillisecondsSinceEpoch(epoch),
      DateTime(2026, 9, 25, 20),
    );

    final afterEight = DateTime(2026, 9, 25, 20, 1);
    expect(
      DateTime.fromMillisecondsSinceEpoch(
        JournalReminderSlots.nextDailyEpoch(afterEight),
      ),
      DateTime(2026, 9, 26, 20),
    );
  });

  test('weekly recap epoch is the next Sunday at 9:00 AM', () {
    final friday = DateTime(2026, 9, 25, 12);
    expect(
      DateTime.fromMillisecondsSinceEpoch(
        JournalReminderSlots.nextWeeklyEpoch(friday),
      ),
      DateTime(2026, 9, 27, 9),
    );

    final sundayAfter = DateTime(2026, 9, 27, 9, 30);
    expect(
      DateTime.fromMillisecondsSinceEpoch(
        JournalReminderSlots.nextWeeklyEpoch(sundayAfter),
      ),
      DateTime(2026, 10, 4, 9),
    );
  });

  test('a disabled reminder has no epoch and a tap opens capture', () {
    final plan = JournalReminderPlan.fromSettings(
      now: DateTime(2026, 9, 25, 12),
      dailyEnabled: false,
      weeklyEnabled: true,
    );
    expect(plan.dailyEpoch, isNull);
    expect(plan.weeklyEpoch, isNotNull);
    JournalNotificationPayload.remember(JournalNotificationPayload.autoRecord);
    expect(JournalNotificationPayload.takeAutoRecord(), isTrue);
    expect(JournalNotificationPayload.captureLocation, '/record?autoRecord=1');
    expect(
      journalRemindersNeedReschedule(
        previousZone: 'Europe/London',
        nextZone: 'America/New_York',
      ),
      isTrue,
    );
  });
}
