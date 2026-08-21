import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/sync/sync_engine.dart';

/// Background drain hook for the drift-backed encrypted sync outbox.
class SyncOutboxBackgroundService {
  SyncOutboxBackgroundService({required SyncEngine syncEngine})
    : _syncEngine = syncEngine;

  final SyncEngine _syncEngine;

  /// Pushes any pending encrypted blobs saved locally in the outbox queue.
  Future<SyncOutboxDrainResult?> drainPending({
    bool Function(ApiFailure failure)? shouldRetry,
  }) async {
    if (!_syncEngine.hasOutbox) return null;
    final result = await _syncEngine.drainOutbox(shouldRetry: shouldRetry);
    return result.when(
      success: (value) => value,
      onFailure: (_) => null,
    );
  }

  Future<int> pendingCount() async {
    if (!_syncEngine.hasOutbox) return 0;
    return _syncEngine.outbox.pendingCount();
  }

  Future<DateTime?> nextRetryAt() async {
    if (!_syncEngine.hasOutbox) return null;
    return _syncEngine.outbox.nextReadyAt();
  }
}
