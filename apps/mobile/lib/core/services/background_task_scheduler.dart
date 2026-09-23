import 'dart:async';

import 'package:archiveme_mobile/core/database/sqlite_vec_indexer.dart';
import 'package:archiveme_mobile/core/services/device_state_service.dart';
import 'package:archiveme_mobile/core/services/task_queue_manager.dart';

/// Drains vector-index and mesh jobs when the device is charging or on Wi-Fi.
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

  /// Starts automatic drains when charging or Wi-Fi becomes available.
  void start() {
    _subscription ??= device.watch().listen((conditions) {
      if (conditions.allowsHeavyWork) {
        unawaited(drain());
      }
    });
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
    final conditions = await device.refresh();
    if (!conditions.allowsHeavyWork) return 0;
    final jobs = await queue.pending();
    var finished = 0;
    for (final job in jobs) {
      final still = await device.refresh();
      if (!still.allowsHeavyWork) break;
      await Future<void>.delayed(Duration.zero);
      await _indexer.execute(job);
      await Future<void>.delayed(Duration.zero);
      await queue.complete(job.id);
      finished++;
    }
    return finished;
  }
}
