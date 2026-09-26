import 'package:archiveme_mobile/features/sync/services/sync_scheduler.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local edits share one push after two seconds', () {
    fakeAsync((async) {
      var pushes = 0;
      final status = SyncStatusNotifier();
      final scheduler = SyncScheduler(
        status: status,
        push: () async {
          pushes += 1;
          return true;
        },
        pull: () async => false,
      );
      addTearDown(scheduler.stop);

      scheduler.noteLocalChange();
      scheduler.noteLocalChange();
      async.elapse(const Duration(seconds: 1));
      expect(pushes, 0);
      expect(status.value.label(DateTime.now()), 'Not synced yet');

      async.elapse(const Duration(seconds: 1));
      expect(pushes, 1);
      expect(status.value.label(DateTime.now()), 'Synced just now');
    });
  });

  test('a foreground timer pulls every 15 minutes', () {
    fakeAsync((async) {
      var pulls = 0;
      final status = SyncStatusNotifier();
      final scheduler = SyncScheduler(
        status: status,
        push: () async => false,
        pull: () async {
          pulls += 1;
          return true;
        },
      );
      addTearDown(scheduler.stop);

      scheduler.startForeground();
      async.elapse(const Duration(minutes: 15));
      expect(pulls, 1);
      expect(status.value.phase, SyncPhase.synced);

      async.elapse(const Duration(minutes: 15));
      expect(pulls, 2);
    });
  });

  test('a failed sync names the reason', () {
    fakeAsync((async) {
      final status = SyncStatusNotifier();
      final scheduler = SyncScheduler(
        status: status,
        push: () async => throw const SyncSchedulerException('offline'),
        pull: () async => false,
      );
      addTearDown(scheduler.stop);
      scheduler.noteLocalChange();
      async.elapse(const Duration(seconds: 2));
      expect(status.value.label(DateTime.now()), 'Sync failed: offline');
    });
  });
}
