import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/reminders/gentle_reminders_copy.dart';
import 'package:archiveme_mobile/features/reminders/gentle_reminders_schedule.dart';
import 'package:archiveme_mobile/features/reminders/gentle_reminders_service.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gentle reminders stay off', () {
    expect(V1CapabilityRegistry.gentleReminders, isFalse);
    expect(
      GentleReminderSchedule.offerAfterThirdEntry(
        entryCount: 0,
        alreadyAnswered: false,
      ),
      isFalse,
    );
    expect(
      GentleReminderSchedule.offerAfterThirdEntry(
        entryCount: 3,
        alreadyAnswered: false,
      ),
      isTrue,
    );
  });

  test('daily nudge uses the chosen time and quiet hours move it', () {
    final now = DateTime(2026, 3, 15, 8);
    final open = GentleReminderSchedule.daily(
      enabled: true,
      now: now,
      hour: 9,
      minute: 30,
    );
    expect(open?.when, DateTime(2026, 3, 15, 9, 30));

    final slots = GentleReminderSchedule.dailySlots(
      enabled: true,
      now: now,
      hour: 9,
      minute: 30,
    );
    expect(slots, hasLength(GentleReminderSchedule.dailySlotCount));
    expect(slots.first.when, DateTime(2026, 3, 15, 9, 30));
    expect(slots.last.when, DateTime(2026, 3, 28, 9, 30));
    expect(slots.map((notice) => notice.id).toSet(), hasLength(slots.length));

    final quiet = GentleReminderSchedule.daily(
      enabled: true,
      now: now,
      hour: 22,
      minute: 0,
      quietHours: const QuietHours(startMinute: 21 * 60, endMinute: 7 * 60),
    );
    expect(quiet?.when, DateTime(2026, 3, 16, 7));
  });

  test('on this day uses a verbatim quote from a week, month, or year ago', () {
    final now = DateTime(2026, 3, 15, 12);
    final notices = GentleReminderSchedule.onThisDay(
      enabled: true,
      now: now,
      entries: [
        OnThisDayCandidate(
          entryId: 'week',
          createdAt: DateTime(2026, 3, 8, 18),
          verbatimQuote: 'I said this last week.',
        ),
        OnThisDayCandidate(
          entryId: 'month',
          createdAt: DateTime(2026, 2, 15, 18),
          verbatimQuote: 'I said this last month.',
        ),
        OnThisDayCandidate(
          entryId: 'year',
          createdAt: DateTime(2025, 3, 15, 18),
          verbatimQuote: 'I said this last year.',
        ),
        OnThisDayCandidate(
          entryId: 'empty',
          createdAt: DateTime(2026, 3, 8),
          verbatimQuote: '   ',
        ),
        OnThisDayCandidate(
          entryId: 'recent',
          createdAt: DateTime(2026, 3, 14),
          verbatimQuote: 'Yesterday.',
        ),
      ],
    );
    expect(notices.map((notice) => notice.body), [
      'I said this last week.',
      'I said this last month.',
      'I said this last year.',
    ]);
    expect(
      notices.every(
        (notice) =>
            notice.title == GentleRemindersCopy.onThisDayNotificationTitle,
      ),
      isTrue,
    );
  });

  test('scheduling and cancellation follow the toggles', () async {
    final backend = _RecordingBackend();
    final service = GentleRemindersService(backend: backend);
    final now = DateTime(2026, 3, 15, 8);

    final scheduled = await service.sync(
      settings: const GentleReminderSettings(dailyEnabled: true),
      previouslyScheduledIds: const [],
      now: now,
    );
    expect(scheduled, isEmpty);
    expect(backend.scheduled, isEmpty);

    final cancelled = await service.sync(
      settings: const GentleReminderSettings(),
      previouslyScheduledIds: const ['gentle.daily'],
      now: now,
    );
    expect(cancelled, isEmpty);
    expect(backend.cancelled, ['gentle.daily']);
  });

  test(
    'check back schedules a week later and cancels when turned off',
    () async {
      final backend = _RecordingBackend();
      final service = GentleRemindersService(backend: backend);
      final now = DateTime(2026, 3, 15, 8);

      final scheduled = await service.scheduleCheckBack(
        entryId: 'entry-1',
        verbatimQuote: 'The words I said.',
        now: now,
        previouslyScheduledIds: const [],
      );
      expect(scheduled, isEmpty);
      expect(backend.scheduled, isEmpty);
      final notice = GentleReminderSchedule.checkBack(
        entryId: 'entry-1',
        verbatimQuote: 'The words I said.',
        now: now,
      );
      expect(notice.when, DateTime(2026, 3, 22, 8));
      expect(notice.body, 'The words I said.');

      final cancelled = await service.scheduleCheckBack(
        entryId: 'entry-1',
        verbatimQuote: 'The words I said.',
        now: now,
        previouslyScheduledIds: const ['gentle.check_back.entry-1'],
        enabled: false,
      );
    expect(cancelled, isEmpty);
    expect(backend.cancelled, contains('gentle.check_back.entry-1'));
    },
  );

  test('weekly recap is Sunday at 19:00 and survives reschedule', () {
    final friday = DateTime(2026, 9, 25, 12);
    final settings = const GentleReminderSettings(weeklyRecapEnabled: true);
    final first = GentleRemindersService.noticesFor(
      settings: settings,
      now: friday,
    );
    final weekly = first.singleWhere(
      (notice) => notice.id == GentleReminderSchedule.weeklyRecapId,
    );
    expect(weekly.when, DateTime(2026, 9, 27, 19));
    expect(weekly.body, 'Your week in your own words is ready.');
    expect(weekly.payload, 'weekly-recap');

    final again = GentleRemindersService.noticesFor(
      settings: settings,
      now: DateTime(2026, 9, 26, 8),
    );
    final weeklyAgain = again.singleWhere((notice) => notice.id == weekly.id);
    expect(weeklyAgain.when, weekly.when);
    expect(weeklyAgain.payload, weekly.payload);
  });

  test('copy has no streak counter', () {
    final visible = [
      GentleRemindersCopy.optInTitle,
      GentleRemindersCopy.optInBody,
      GentleRemindersCopy.dailyNotificationTitle,
      GentleRemindersCopy.dailyNotificationBody,
      GentleRemindersCopy.onThisDayNotificationTitle,
      GentleRemindersCopy.checkBackNotificationTitle,
    ].join(' ').toLowerCase();
    expect(visible.contains('streak'), isFalse);
    expect(visible.contains("don't miss"), isFalse);
  });
}

class _RecordingBackend implements CheckInReminderBackend {
  final scheduled = <String, DateTime>{};
  final cancelled = <String>[];

  @override
  bool get isAvailable => true;

  @override
  Future<void> cancel(String checkInId) async {
    cancelled.add(checkInId);
    scheduled.remove(checkInId);
  }

  @override
  Future<void> clearAll() async {
    scheduled.clear();
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    scheduled[checkInId] = when;
  }
}
