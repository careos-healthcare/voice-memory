import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/analytics/ffi_safety_monitor.dart';

void main() {
  test('tracks and releases app-owned resources without leaks', () {
    final monitor = FFISafetyMonitor(rssPressureThresholdBytes: 1 << 40);
    final lease = monitor.acquire(
      FFIResourceKind.llamaSession,
      owner: 'test-session',
      estimatedBytes: 4096,
    );

    expect(monitor.snapshot.activeCount, 1);
    expect(monitor.snapshot.activeEstimatedBytes, 4096);
    expect(() => monitor.assertNoLeaks(), throwsStateError);

    lease.release();
    monitor.assertNoLeaks();
    expect(monitor.snapshot.activeCount, 0);
  });

  test('runs registered disposal hooks under resource pressure', () async {
    final monitor = FFISafetyMonitor(
      rssPressureThresholdBytes: 1 << 40,
      resourcePressureThreshold: 1,
    );
    var purged = false;
    monitor.registerPressureHook('test', () => purged = true);
    final lease = monitor.acquire(
      FFIResourceKind.sqliteDatabase,
      owner: 'test-store',
    );

    expect(await monitor.checkPressure(), isTrue);
    expect(purged, isTrue);
    lease.release();
    await monitor.dispose();
  });

  test(
    'detects duplicate release and use-after-release with bounded events',
    () {
      final monitor = FFISafetyMonitor(
        rssPressureThresholdBytes: 1 << 40,
        maximumEventHistory: 3,
      );
      final lease = monitor.acquire(
        FFIResourceKind.loraJob,
        owner: 'neural-trainer',
      );
      expect(monitor.snapshot.byOwner, {'neural-trainer': 1});

      lease.ensureActive();
      lease.release();

      expect(lease.ensureActive, throwsStateError);
      expect(lease.release, throwsStateError);
      expect(monitor.events, hasLength(3));
      expect(
        monitor.events.map((event) => event.type),
        containsAll([
          FFISafetyEventType.released,
          FFISafetyEventType.useAfterRelease,
          FFISafetyEventType.duplicateRelease,
        ]),
      );
    },
  );

  test('records finalizer backstop diagnostics without implicit cleanup', () {
    final monitor = FFISafetyMonitor(rssPressureThresholdBytes: 1 << 40);
    final lease = monitor.acquire(
      FFIResourceKind.hivemindSession,
      owner: 'finalizer-fixture',
    );

    monitor.simulateFinalizerForTesting(lease);

    expect(monitor.snapshot.finalizerLeakCount, 1);
    expect(monitor.snapshot.activeCount, 1);
    expect(
      monitor.events.last.type,
      FFISafetyEventType.finalizedWithoutRelease,
    );
    lease.release();
    monitor.assertNoLeaks();
  });
}
