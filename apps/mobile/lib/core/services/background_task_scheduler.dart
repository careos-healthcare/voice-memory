import 'dart:async';

import 'package:archiveme_mobile/core/database/sqlite_vec_indexer.dart';
import 'package:archiveme_mobile/core/services/device_state_service.dart';
import 'package:archiveme_mobile/core/services/task_queue_manager.dart';

/// Drains vector-index and P2P jobs only while the device is charging on Wi-Fi.
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

  /// Starts automatic drains when power and Wi-Fi become available together.
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

  /// Processes pending jobs. Returns how many finished.
  ///
  /// On battery or off Wi-Fi the queue stays `pending` and nothing runs.
  Future<int> drain() async {
    final conditions = await device.refresh();
    if (!conditions.allowsHeavyWork) return 0;
    final jobs = await queue.pending();
    var finished = 0;
    for (final job in jobs) {
      final still = await device.refresh();
      if (!still.allowsHeavyWork) break;
      await _indexer.execute(job);
      await queue.complete(job.id);
      finished++;
    }
    return finished;
  }
}
