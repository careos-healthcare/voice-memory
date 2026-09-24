import 'dart:async';

import 'package:archiveme_mobile/core/database/sqlite_vec_indexer.dart';
import 'package:archiveme_mobile/core/services/device_state_service.dart';
import 'package:archiveme_mobile/core/services/task_queue_manager.dart';

/// Drains heavy jobs when device power, idle, and thermal checks allow them.
///
/// Vector indexing and mesh sync still run on charge or Wi-Fi. Pattern
/// synthesis and on-device transcription also require an idle, charging
/// device with a safe battery. Serious heat suspends every pending job.
class BackgroundTaskScheduler {
  BackgroundTaskScheduler({
    required this.device,
    required this.queue,
    SqliteVecIndexer? indexer,
  }) : _indexer = indexer ?? const SqliteVecIndexer();

  final DeviceStateService device;
  final TaskQueueManager queue;
  final SqliteVecIndexer _indexer;

  StreamSubscription<DeviceConditions>? _subscription;

  /// Holds an embedding or sync request until a drain cycle can run it.
  Future<void> submit(BackgroundTask task) async {
    await queue.enqueue(task);
    await drain();
  }

  /// Starts automatic drains when power, idle, or thermal state changes.
  void start() {
    _subscription ??= device.watch().listen((conditions) {
      if (conditions.allowsHeavyWork ||
          conditions.allowsPatternAndTranscription) {
        unawaited(drain());
      }
    });
  }

  /// True when [job] may run under the latest device snapshot.
  static bool admits(BackgroundTask job, DeviceConditions conditions) {
    if (!conditions.thermalAllowsWork) return false;
    if (BackgroundTask.idlePowerKinds.contains(job.kind)) {
      return conditions.allowsPatternAndTranscription;
    }
    if (BackgroundTask.heavyProcessingKinds.contains(job.kind)) {
      return conditions.isCharging && conditions.batteryIsSafe;
    }
    return conditions.allowsHeavyWork;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Processes pending jobs in enqueue order. Returns how many finished.
  ///
  /// With neither charging nor Wi-Fi the queue stays `pending` and nothing runs.
  /// Each SQLite status update yields so the current UI frame is not held.
  Future<int> drain() async {
    await device.refresh();
    final jobs = await queue.pending();
    var finished = 0;
    for (final job in jobs) {
      final still = await device.refresh();
      if (!admits(job, still)) continue;
      await Future<void>.delayed(Duration.zero);
      await _indexer.execute(job);
      await Future<void>.delayed(Duration.zero);
      await queue.complete(job.id);
      finished++;
    }
    return finished;
  }
}
