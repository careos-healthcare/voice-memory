import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/sync/sync_outbox_drainer.dart';
import 'package:archiveme_mobile/sync/sync_push_status.dart';

export 'sync_outbox_drainer.dart';
export 'sync_push_status.dart';

/// Background drain hook for the drift-backed encrypted sync outbox.
class SyncOutboxBackgroundService {
  SyncOutboxBackgroundService({required SyncOutboxDrainer drainer})
    : _drainer = drainer;

  final SyncOutboxDrainer _drainer;

  /// Pushes any pending encrypted blobs saved locally in the outbox queue.
  Future<SyncOutboxDrainResult?> drainPending({
    bool Function(ApiFailure failure)? shouldRetry,
  }) async {
    if (!_drainer.hasOutbox) return null;
    final result = await _drainer.drainOutbox(shouldRetry: shouldRetry);
    return result.when(
      success: (value) => value,
      onFailure: (_) => null,
    );
  }

  Future<int> pendingCount() async {
    if (!_drainer.hasOutbox) return 0;
    return _drainer.outbox.pendingCount();
  }

  Future<DateTime?> nextRetryAt() async {
    if (!_drainer.hasOutbox) return null;
    return _drainer.outbox.nextReadyAt();
  }
}
