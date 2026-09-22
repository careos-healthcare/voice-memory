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

  test('defers vector and sync jobs until charging on Wi-Fi', () async {
    final device = ManualDeviceState(
      const DeviceConditions(isCharging: false, isWifiConnected: true),
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
    expect(await scheduler.drain(), 0);
    expect(await queue.pending(), isNotEmpty);

    device.emit(
      const DeviceConditions(isCharging: true, isWifiConnected: true),
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
      ),
    );
    final pending = await queue.pending();
    expect(pending.single.status, BackgroundTask.statusPending);
    await queue.complete('vec-2');
    expect(await queue.pending(), isEmpty);
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
