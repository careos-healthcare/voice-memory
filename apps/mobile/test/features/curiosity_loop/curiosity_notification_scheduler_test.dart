import 'package:archiveme_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/curiosity_notification_scheduler.dart';
import 'package:archiveme_mobile/features/curiosity_loop/yesterdays_snapshot_copy.dart';
import 'package:flutter_test/flutter_test.dart';

CuriosityHook _hook({
  required String id,
  DateTime? createdAt,
  String dynamicPrompt =
      'Before "said yes again" showed up again, what got in the way?',
}) => CuriosityHook(
  id: id,
  entryId: 'entry_$id',
  createdAt: createdAt ?? DateTime.now().toUtc(),
  primaryAnchor: 'said yes again',
  hookType: CuriosityHookType.blocker,
  dynamicPrompt: dynamicPrompt,
);

void main() {
  tearDown(CuriosityNotificationScheduler.resetForTest);

  group('CuriosityNotificationPayload', () {
    test('round trips hook id with versioned prefix', () {
      const hookId = 'curiosity_e1_42';
      final payload = CuriosityNotificationPayload.encode(hookId);

      expect(payload, startsWith('curiosity_hook_v1:'));
      expect(CuriosityNotificationPayload.decodeHookId(payload), hookId);
    });

    test('rejects empty hook id on encode', () {
      expect(
        () => CuriosityNotificationPayload.encode('  '),
        throwsArgumentError,
      );
    });

    test('decode ignores unrelated payloads', () {
      expect(CuriosityNotificationPayload.decodeHookId(null), isNull);
      expect(CuriosityNotificationPayload.decodeHookId(''), isNull);
      expect(
        CuriosityNotificationPayload.decodeHookId('check_in:tci1'),
        isNull,
      );
      expect(
        CuriosityNotificationPayload.decodeHookId('curiosity_hook_v1:'),
        isNull,
      );
    });
  });

  group('CuriosityNotificationScheduler', () {
    test(
      'scheduleCuriosityNotification returns false when unavailable',
      () async {
        final scheduler = CuriosityNotificationScheduler();
        final hook = _hook(
          id: 'hook_future',
          createdAt: DateTime.now().toUtc(),
        );

        final scheduled = await scheduler.scheduleCuriosityNotification(hook);

        expect(scheduler.isAvailable, isFalse);
        expect(scheduled, isFalse);
      },
    );

    test(
      'scheduleCuriosityNotification returns false when fire time passed',
      () async {
        final scheduler = CuriosityNotificationScheduler();
        final hook = _hook(
          id: 'hook_past',
          createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 48)),
        );

        final scheduled = await scheduler.scheduleCuriosityNotification(hook);

        expect(scheduled, isFalse);
      },
    );

    test(
      'initialize and requestPermissions do not throw without plugin',
      () async {
        final scheduler = CuriosityNotificationScheduler();

        await expectLater(scheduler.initialize(), completes);
        await expectLater(scheduler.requestPermissions(), completion(isFalse));
      },
    );

    test('uses Carry this forward title constant', () {
      expect(YesterdaysSnapshotCopy.hookEyebrow, 'Carry this forward');
    });

    test('notification id is stable for hook id', () {
      expect(CuriosityNotificationScheduler.instance().isAvailable, isFalse);
      final payload = CuriosityNotificationPayload.encode('curiosity_stable');
      expect(
        CuriosityNotificationPayload.decodeHookId(payload),
        'curiosity_stable',
      );
    });
  });
}