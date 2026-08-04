import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/notifications/thread_return_notification_service.dart';
import 'package:voicememory_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';

class _ScheduledNotification {
  const _ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    required this.payload,
    required this.quiet,
  });

  final String id;
  final String title;
  final String body;
  final DateTime when;
  final String payload;
  final bool quiet;
}

class _FakeBackend implements CheckInReminderBackend, QuietReminderBackend {
  final scheduled = <_ScheduledNotification>[];
  final cancelled = <String>[];

  @override
  bool get isAvailable => true;

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
  }) => _record(
    checkInId: checkInId,
    title: title,
    body: body,
    when: when,
    payload: payload,
    quiet: false,
  );

  @override
  Future<void> scheduleQuiet({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) => _record(
    checkInId: checkInId,
    title: title,
    body: body,
    when: when,
    payload: payload,
    quiet: true,
  );

  Future<void> _record({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
    required bool quiet,
  }) async {
    scheduled.add(
      _ScheduledNotification(
        id: checkInId,
        title: title,
        body: body,
        when: when,
        payload: payload,
        quiet: quiet,
      ),
    );
  }

  @override
  Future<void> cancel(String checkInId) async => cancelled.add(checkInId);

  @override
  Future<void> clearAll() async {}
}

JournalEntry _entry(String id) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 7, 1, 12),
  transcript: 'I noticed the pressure before I answered this time.',
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

WatchForItem _target({
  required String id,
  required String sourceEntryId,
  bool isSuppressed = false,
}) => WatchForItem(
  id: id,
  createdAt: DateTime.utc(2026, 7, 1, 12),
  targetDate: DateTime.utc(2026, 7, 2),
  sourceReflectionId: sourceEntryId,
  text: 'checking messages after I wanted to stop',
  chips: const ['checking messages'],
  status: WatchForStatus.pending,
  result: WatchForResult.none,
  isSuppressed: isSuppressed,
);

void main() {
  late _FakeBackend backend;
  late Directory tempDir;
  late WatchForStore store;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('adaptive_notification_');
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      prefsPath: '${tempDir.path}/prefs.json',
      skipRevenueCat: true,
    );
    backend = _FakeBackend();
    CheckInReminderService.setBackendForTest(backend);
    store = WatchForStore(AppServices.instance.prefs);
    await ThreadReturnNotificationService.resetForTest(
      AppServices.instance.prefs,
    );
  });

  tearDown(() {
    CheckInReminderService.resetBackendForTest();
    tempDir.deleteSync(recursive: true);
  });

  test('schedules quiet level 1, 2, and 3 reminders then stops', () async {
    final now = DateTime.utc(2026, 7, 1, 12);
    await store.writePending(_target(id: 'watch-1', sourceEntryId: 'entry-1'));

    await ThreadReturnNotificationService.onMomentSaved(
      _entry('entry-1'),
      now: now,
    );

    expect(backend.scheduled, hasLength(3));
    expect(backend.scheduled.every((item) => item.quiet), isTrue);
    expect(backend.scheduled.map((item) => item.title).toSet(), {'ArchiveMe'});
    expect(
      backend.scheduled.first.body,
      "You saved a thread about "
      "'checking messages after I wanted to stop' a few days ago. "
      'Come back if it showed up again today.',
    );
    expect(backend.scheduled.map((item) => item.when.difference(now).inDays), [
      3,
      10,
      24,
    ]);
    expect(backend.scheduled.map((item) => item.payload), [
      'thread_return_v2:watch-1:1',
      'thread_return_v2:watch-1:2',
      'thread_return_v2:watch-1:3',
    ]);
  });

  test('enforces one Watch Target notification per rolling 24 hours', () async {
    final now = DateTime.utc(2026, 7, 1, 12);
    await ThreadReturnNotificationService.onWatchTargetActivated(
      _target(id: 'watch-1', sourceEntryId: 'entry-1'),
      now: now,
    );
    await ThreadReturnNotificationService.onWatchTargetActivated(
      _target(id: 'watch-2', sourceEntryId: 'entry-2'),
      now: now,
    );

    final times = backend.scheduled.map((item) => item.when).toList()..sort();
    expect(times, hasLength(6));
    for (var i = 1; i < times.length; i++) {
      expect(
        times[i].difference(times[i - 1]),
        greaterThanOrEqualTo(ThreadReturnNotificationService.globalCooldown),
      );
    }
  });

  test('thread view cancels only the relevant target', () async {
    final now = DateTime.utc(2026, 7, 1, 12);
    await ThreadReturnNotificationService.onWatchTargetActivated(
      _target(id: 'watch-1', sourceEntryId: 'entry-1'),
      now: now,
    );
    await ThreadReturnNotificationService.onWatchTargetActivated(
      _target(id: 'watch-2', sourceEntryId: 'entry-2'),
      now: now,
    );

    await ThreadReturnNotificationService.markThreadViewed('entry-1');

    expect(backend.cancelled, [
      'thread_return:watch-1:1',
      'thread_return:watch-1:2',
      'thread_return:watch-1:3',
    ]);
    expect(backend.cancelled.any((key) => key.contains('watch-2')), isFalse);
  });

  test(
    'Not today snoozes the target for seven days after it was viewed',
    () async {
      final now = DateTime.utc(2026, 7, 1, 12);
      final target = _target(id: 'watch-1', sourceEntryId: 'entry-1');
      await store.writePending(target);
      await ThreadReturnNotificationService.onWatchTargetActivated(
        target,
        now: now,
      );
      await ThreadReturnNotificationService.markThreadViewed('entry-1');
      backend.scheduled.clear();

      await ThreadReturnNotificationService.snoozeThread('entry-1', now: now);

      expect(backend.scheduled, hasLength(3));
      expect(backend.scheduled.first.when.difference(now).inDays, 7);
    },
  );

  test("Don't remind again persists until new evidence links", () async {
    final now = DateTime.utc(2026, 7, 1, 12);
    final target = _target(id: 'watch-1', sourceEntryId: 'entry-1');
    await store.writePending(target);
    await ThreadReturnNotificationService.onWatchTargetActivated(
      target,
      now: now,
    );

    await ThreadReturnNotificationService.suppressThreadPermanently('entry-1');
    expect((await store.readPending())?.isSuppressed, isTrue);
    backend.scheduled.clear();

    await ThreadReturnNotificationService.onWatchTargetActivated(
      target.copyWith(isSuppressed: false),
      now: now.add(const Duration(hours: 1)),
    );
    expect(backend.scheduled, isEmpty);

    await ThreadReturnNotificationService.onMomentSaved(
      _entry('entry-2'),
      now: now.add(const Duration(days: 1)),
    );

    expect((await store.readPending())?.isSuppressed, isFalse);
    expect(backend.scheduled, hasLength(3));
  });

  test('completed, merged, and deleted targets cancel immediately', () async {
    final now = DateTime.utc(2026, 7, 1, 12);
    final actions = [
      ThreadReturnNotificationService.threadCompleted,
      ThreadReturnNotificationService.threadMerged,
      ThreadReturnNotificationService.threadDeleted,
    ];
    for (var index = 0; index < actions.length; index++) {
      backend.cancelled.clear();
      final targetId = 'watch-${index + 1}';
      await ThreadReturnNotificationService.onWatchTargetActivated(
        _target(id: targetId, sourceEntryId: 'entry-${index + 1}'),
        now: now,
      );
      await actions[index](targetId);
      expect(backend.cancelled, hasLength(3));
    }
  });

  test(
    'implementation has no recurring schedules or raw-open cancellation',
    () {
      final notificationFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where(
            (file) =>
                file.path.contains('notification') ||
                file.path.contains('reminder'),
          );
      final source = notificationFiles
          .map((file) => file.readAsStringSync())
          .join();
      final appSource = File('lib/app.dart').readAsStringSync();
      final startupSource = File(
        'lib/startup/archive_me_startup.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('periodicallyShow')));
      expect(source, isNot(contains('matchDateTimeComponents')));
      expect(source, isNot(contains('repeatInterval')));
      expect(appSource, isNot(contains('suppressPendingOnAppOpen')));
      expect(startupSource, isNot(contains('suppressPendingOnAppOpen')));
    },
  );
}
