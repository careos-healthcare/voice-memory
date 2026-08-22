import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:archiveme_mobile/features/sync/application/background_sync_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackgroundSyncStateMachine', () {
    test('transitions through pipeline phases to completed', () {
      final machine = BackgroundSyncStateMachine();
      machine.beginPhase(BackgroundSyncPhase.attestation);
      expect(machine.state.phase, BackgroundSyncPhase.attestation);

      machine.beginPhase(BackgroundSyncPhase.outboxDrain);
      expect(machine.state.phase, BackgroundSyncPhase.outboxDrain);

      machine.complete(
        transcriptsReconciled: 2,
        proofsAdmitted: 1,
        cloudSyncSucceeded: true,
      );

      expect(machine.state.phase, BackgroundSyncPhase.completed);
      expect(machine.state.transcriptsReconciled, 2);
      expect(machine.state.proofsAdmitted, 1);
      expect(machine.state.cloudSyncSucceeded, isTrue);
    });

    test('marks waitingForNetwork when offline', () {
      final machine = BackgroundSyncStateMachine();
      machine.beginPhase(BackgroundSyncPhase.cloudSync);
      machine.setConnectivity(isOnline: false);
      expect(machine.state.phase, BackgroundSyncPhase.waitingForNetwork);
      expect(machine.state.isOnline, isFalse);
    });

    test('schedules retry backoff state', () {
      final machine = BackgroundSyncStateMachine();
      final retryAt = DateTime.utc(2026, 8, 19, 12);
      machine.scheduleRetry(retryAt);
      expect(machine.state.phase, BackgroundSyncPhase.waitingForRetry);
      expect(machine.state.nextRetryAt, retryAt);
    });

    test('records non-terminal phase failures', () {
      final machine = BackgroundSyncStateMachine();
      machine.beginPhase(BackgroundSyncPhase.transcription);
      machine.recordPhaseFailure(BackgroundSyncPhase.transcription, 'timeout');
      expect(machine.state.phase, BackgroundSyncPhase.transcription);
      expect(machine.state.lastError, contains('timeout'));
    });
  });

  group('BackgroundSyncController', () {
    test('notifies listener on state changes', () {
      BackgroundSyncState? latest;
      final controller = BackgroundSyncController(
        onStateChanged: (state) => latest = state,
      );

      controller.beginPhase(BackgroundSyncPhase.cloudSync);
      expect(latest?.phase, BackgroundSyncPhase.cloudSync);

      controller.setQueueCounts(
        queuedEntryCount: 3,
        pendingOutboxCount: 2,
      );
      expect(latest?.queuedEntryCount, 3);
      expect(latest?.pendingOutboxCount, 2);
    });
  });
}
