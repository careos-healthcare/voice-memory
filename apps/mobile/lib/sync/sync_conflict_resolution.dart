import 'package:archiveme_mobile/core/execution/sync_execution_strategy.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/sync/sync_engine.dart';

export 'package:archiveme_mobile/core/execution/sync_execution_strategy.dart'
    show SyncConflictResolution;

extension SyncEngineConflictResolution on SyncExecutionStrategy {
  /// Resolves whether a pushed blob was applied or needs another attempt.
  SyncConflictResolution resolvePushOutcome({
    required SyncPushStatusMatrix matrix,
    required String blobId,
    ApiFailure? pushFailure,
  }) {
    if (pushFailure != null) {
      if (isRetryableFailure(pushFailure)) {
        return SyncConflictResolution.retry;
      }
      if (pushFailure is ApiFailureAuthRequired) {
        return SyncConflictResolution.failed;
      }
      return SyncConflictResolution.retry;
    }

    if (matrix.blobApplied(blobId)) {
      return SyncConflictResolution.acknowledged;
    }

    final entry = matrix.entries.where((row) => row.id == blobId).firstOrNull;
    if (entry?.status == SyncBlobUpsertStatus.existing) {
      return SyncConflictResolution.acknowledged;
    }

    return SyncConflictResolution.retry;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
