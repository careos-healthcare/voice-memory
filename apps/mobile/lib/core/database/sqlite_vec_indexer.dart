import 'dart:math' as math;

import 'package:archiveme_mobile/core/execution/isolate_compute_job.dart';
import 'package:archiveme_mobile/core/services/task_queue_manager.dart';

/// Parses and normalizes a comma-separated vector off the UI isolate.
List<double> parseAndNormalizeVector(String raw) {
  if (raw.trim().isEmpty) return const [];
  final values = <double>[
    for (final part in raw.split(','))
      if (part.trim().isNotEmpty) double.parse(part.trim()),
  ];
  var sumSquares = 0.0;
  for (final value in values) {
    sumSquares += value * value;
  }
  final norm = sumSquares == 0 ? 1.0 : math.sqrt(sumSquares);
  return [for (final value in values) value / norm];
}

/// Measures a sync payload without touching the UI isolate.
int sealSyncPayload(String payload) => payload.length;

/// Runs sqlite-vec parsing and P2P payload sealing on a background isolate.
class SqliteVecIndexer {
  const SqliteVecIndexer();

  Future<Object> execute(BackgroundTask task) {
    return switch (task.kind) {
      BackgroundTask.kindVectorIndex =>
        IsolateComputeJob.run<String, List<double>>(
          label: 'sqlite_vec_index',
          payload: task.payload,
          computeFn: parseAndNormalizeVector,
        ),
      _ => IsolateComputeJob.run<String, int>(
        label: 'p2p_sync_seal',
        payload: task.payload,
        computeFn: sealSyncPayload,
      ),
    };
  }
}
