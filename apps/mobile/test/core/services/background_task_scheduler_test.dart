import 'package:archiveme_mobile/core/hardware/hardware_monitor_channel.dart';
import 'package:archiveme_mobile/core/services/background_task_scheduler.dart';
import 'package:archiveme_mobile/core/services/device_state_service.dart';
import 'package:archiveme_mobile/core/services/frame_budget_overlay.dart';
import 'package:archiveme_mobile/core/services/task_queue_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defers mesh and embedding jobs until charging or Wi-Fi', () async {
    final device = ManualDeviceState(
      const DeviceConditions(isCharging: false, isWifiConnected: false),
    );
    final queue = MemoryTaskQueue();
    final scheduler = BackgroundTaskScheduler(
      device: DeviceStateService(source: device),
      queue: queue,
    );

    await scheduler.submit(
      const BackgroundTask(
        id: 'vec-1',
        kind: BackgroundTask.kindVectorIndex,
        entryId: 'entry-1',
        payload: '3,4',
        status: BackgroundTask.statusPending,
      ),
    );
    expect((await queue.pending()).single.id, 'vec-1');

    device.emit(
      const DeviceConditions(isCharging: true, isWifiConnected: false),
    );
    final monitor = FrameBudgetMonitor();
    expect(await scheduler.drain(), 1);
    monitor.record(
      build: const Duration(milliseconds: 2),
      raster: const Duration(milliseconds: 2),
    );
    expect(monitor.droppedFrames, 0);
    expect(await queue.pending(), isEmpty);
  });

  test('Wi-Fi alone drains a pending embedding job', () async {
    final device = ManualDeviceState(
      const DeviceConditions(isCharging: false, isWifiConnected: true),
    );
    final queue = MemoryTaskQueue();
    final scheduler = BackgroundTaskScheduler(
      device: DeviceStateService(source: device),
      queue: queue,
    );
    await queue.enqueue(
      const BackgroundTask(
        id: 'vec-wifi',
        kind: BackgroundTask.kindVectorIndex,
        entryId: 'entry-wifi',
        payload: '1,0',
        status: BackgroundTask.statusPending,
      ),
    );
    expect(await scheduler.drain(), 1);
    expect(await queue.pending(), isEmpty);
  });

  test('connecting power and Wi-Fi drains the queue automatically', () async {
    final device = ManualDeviceState(
      const DeviceConditions(isCharging: false, isWifiConnected: false),
    );
    final queue = MemoryTaskQueue();
    final scheduler = BackgroundTaskScheduler(
      device: DeviceStateService(source: device),
      queue: queue,
    );
    await queue.enqueue(
      const BackgroundTask(
        id: 'sync-1',
        kind: BackgroundTask.kindP2pSync,
        entryId: 'entry-2',
        payload: 'peer-envelope',
        status: BackgroundTask.statusPending,
      ),
    );
    scheduler.start();
    await Future<void>.delayed(Duration.zero);
    device.emit(
      const DeviceConditions(isCharging: true, isWifiConnected: true),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await queue.pending(), isEmpty);
    await scheduler.dispose();
  });

  test('sqlite keeps deferred jobs pending', () async {
    configureSqliteTestFfi();
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final queue = SqliteTaskQueue(db);
    await queue.enqueue(
      const BackgroundTask(
        id: 'vec-2',
        kind: BackgroundTask.kindVectorIndex,
        entryId: 'entry-3',
        payload: '1,0',
        status: BackgroundTask.statusPending,
        enqueuedAt: 5,
      ),
    );
    final pending = await queue.pending();
    expect(pending.single.status, BackgroundTask.statusPending);
    await queue.enqueue(
      const BackgroundTask(
        id: 'sync-later',
        kind: BackgroundTask.kindP2pSync,
        entryId: 'entry-4',
        payload: 'peer',
        status: BackgroundTask.statusPending,
        enqueuedAt: 20,
      ),
    );
    await queue.enqueue(
      const BackgroundTask(
        id: 'vec-earlier',
        kind: BackgroundTask.kindVectorIndex,
        entryId: 'entry-5',
        payload: '0,1',
        status: BackgroundTask.statusPending,
        enqueuedAt: 10,
      ),
    );
    final ordered = await queue.pending();
    expect(ordered.map((task) => task.id).toList(), [
      'vec-2',
      'vec-earlier',
      'sync-later',
    ]);
    await queue.complete('vec-2');
    await queue.complete('vec-earlier');
    await queue.complete('sync-later');
    expect(await queue.pending(), isEmpty);
  });

  test(
    'pattern synthesis waits for idle, charge, and a safe battery',
    () async {
      final device = ManualDeviceState(
        const DeviceConditions(isCharging: true, isWifiConnected: false),
      );
      final queue = MemoryTaskQueue();
      final scheduler = BackgroundTaskScheduler(
        device: DeviceStateService(source: device),
        queue: queue,
      );
      await queue.enqueue(
        const BackgroundTask(
          id: 'patterns',
          kind: BackgroundTask.kindPatternSynthesis,
          entryId: 'entry-p',
          payload: 'week',
          status: BackgroundTask.statusPending,
        ),
      );
      expect(await scheduler.drain(), 0);
      expect((await queue.pending()).single.id, 'patterns');

      device.emit(
        const DeviceConditions(
          isCharging: true,
          isWifiConnected: false,
          isIdle: true,
          batteryLevel: 40,
        ),
      );
      expect(await scheduler.drain(), 1);
      expect(await queue.pending(), isEmpty);
    },
  );

  test('serious heat suspends coaching and transcription', () async {
    final device = ManualDeviceState(
      const DeviceConditions(
        isCharging: true,
        isWifiConnected: true,
        isIdle: true,
        batteryLevel: 80,
        thermalStatus: DeviceThermalStatus.serious,
      ),
    );
    final queue = MemoryTaskQueue();
    final scheduler = BackgroundTaskScheduler(
      device: DeviceStateService(source: device),
      queue: queue,
    );
    await queue.enqueue(
      const BackgroundTask(
        id: 'coach',
        kind: BackgroundTask.kindLocalCoaching,
        entryId: 'entry-c',
        payload: 'note',
        status: BackgroundTask.statusPending,
      ),
    );
    await queue.enqueue(
      const BackgroundTask(
        id: 'transcript',
        kind: BackgroundTask.kindOnDeviceTranscription,
        entryId: 'entry-t',
        payload: 'audio',
        status: BackgroundTask.statusPending,
      ),
    );
    expect(await scheduler.drain(), 0);
    expect((await queue.pending()).map((task) => task.id), [
      'coach',
      'transcript',
    ]);
  });

  testWidgets('debug overlay stays stable inside the 8.3ms budget', (
    tester,
  ) async {
    final monitor = FrameBudgetMonitor();
    monitor.record(
      build: const Duration(milliseconds: 3),
      raster: const Duration(milliseconds: 3),
    );
    expect(monitor.stable, isTrue);
    monitor.record(
      build: const Duration(milliseconds: 9),
      raster: Duration.zero,
    );
    expect(monitor.droppedFrames, 1);

    await tester.pumpWidget(
      const MaterialApp(
        home: FrameBudgetOverlay(child: SizedBox.expand()),
      ),
    );
    expect(find.text('Frames stable'), findsOneWidget);
  });
}
