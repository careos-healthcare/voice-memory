import 'package:archiveme_mobile/api/models/sync_dto.dart';
import 'package:archiveme_mobile/core/execution/execution.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/sync/sync_backoff_policy.dart';
import 'package:archiveme_mobile/sync/sync_outbox_store.dart';
import 'package:archiveme_mobile/sync/sync_push_status.dart';

/// Pushes sealed records that were saved in the local outbox.
class SyncOutboxDrainer {
  SyncOutboxDrainer({
    required SyncApiClient syncApi,
    required JournalStore journal,
    SyncOutboxStore? outbox,
    SyncBackoffPolicy backoff = const SyncBackoffPolicy(),
    SyncExecutionStrategy? syncStrategy,
  }) : _syncApi = syncApi,
       _journal = journal,
       _outbox = outbox,
       _syncStrategy = syncStrategy ?? SyncExecutionStrategy(backoff: backoff);

  final SyncApiClient _syncApi;
  final JournalStore _journal;
  final SyncOutboxStore? _outbox;
  final SyncExecutionStrategy _syncStrategy;

  bool get hasOutbox => _outbox != null;

  SyncOutboxStore get outbox {
    final store = _outbox;
    if (store == null) {
      throw StateError('SyncOutboxStore is not configured');
    }
    return store;
  }

  Future<List<JournalEntry>> pendingQueue() => _journal.pendingSyncQueue();

  Future<String> enqueueBlob(SyncBlobPushDto blob) => outbox.enqueue(blob);

  Future<ApiResult<SyncOutboxDrainResult>> drainOutbox({
    bool Function(ApiFailure failure)? shouldRetry,
  }) async {
    final store = _outbox;
    if (store == null) {
      return const ApiFailureResult(
        ApiFailureUnknown('Sync outbox is not configured'),
      );
    }

    await store.requeueInFlight();
    final pending = await store.pending();
    if (pending.isEmpty) {
      return const ApiSuccess(
        SyncOutboxDrainResult(
          pushedCount: 0,
          remaining: 0,
          responseBody: {},
          matrix: SyncPushStatusMatrix([]),
        ),
      );
    }

    for (final entry in pending) {
      await store.markInFlight(entry.outboxId);
    }

    final body = {
      'blobs': pending.map((entry) => entry.blob.toJson()).toList(),
    };

    final push = await pushBlobsWithRetry(body, shouldRetry: shouldRetry);
    return push.when(
      success: (result) async {
        for (final entry in pending) {
          await store.markSent(entry.outboxId);
        }
        final remaining = await store.pendingCount();
        return ApiSuccess(
          SyncOutboxDrainResult(
            pushedCount: pending.length,
            remaining: remaining,
            responseBody: result.body,
            matrix: result.matrix,
          ),
        );
      },
      onFailure: (failure) async {
        for (final entry in pending) {
          await store.markFailed(entry.outboxId, failure.code);
        }
        return ApiFailureResult(failure);
      },
    );
  }

  Future<ApiResult<({Map<String, dynamic> body, SyncPushStatusMatrix matrix})>>
  pushBlobsWithRetry(
    Map<String, dynamic> body, {
    bool Function(ApiFailure failure)? shouldRetry,
  }) async {
    final execResult = await _syncStrategy.pushWithRetry<
      ({Map<String, dynamic> body, SyncPushStatusMatrix matrix})
    >(
      shouldRetry: shouldRetry,
      push: () async {
        final result = await _syncApi.syncPush(body);
        return result.when(
          success: (value) => ApiSuccess((
            body: value,
            matrix: SyncPushStatusMatrix.fromResponse(value),
          )),
          onFailure: ApiFailureResult.new,
        );
      },
    );

    return execResult.when(
      success: ApiSuccess.new,
      onFailure: (failure) =>
          ApiFailureResult(_syncFailureToApiFailure(failure)),
      onDeferred: (failure) =>
          ApiFailureResult(_syncFailureToApiFailure(failure)),
      onCancelled: () => const ApiFailureResult(ApiFailureCancelled()),
    );
  }

  Future<void> acknowledgeAppliedPush({
    required SyncPushStatusMatrix matrix,
    required String coreBlobId,
    required Iterable<String> pushedEntryIds,
  }) async {
    if (!matrix.blobApplied(coreBlobId)) return;
    await _journal.markSyncedBatch(pushedEntryIds.toSet());
  }

  Future<ApiResult<int>> flushOfflineQueue({
    required SyncBlobPushDto blob,
    required String coreBlobId,
    required Iterable<String> pushedEntryIds,
  }) async {
    if (_outbox != null) {
      await enqueueBlob(blob);
      final drain = await drainOutbox();
      return drain.when(
        success: (result) async {
          await acknowledgeAppliedPush(
            matrix: result.matrix,
            coreBlobId: coreBlobId,
            pushedEntryIds: pushedEntryIds,
          );
          return ApiSuccess(result.pushedCount);
        },
        onFailure: ApiFailureResult.new,
      );
    }

    final push = await pushBlobsWithRetry({
      'blobs': [blob.toJson()],
    });
    return push.when(
      success: (result) async {
        await acknowledgeAppliedPush(
          matrix: result.matrix,
          coreBlobId: coreBlobId,
          pushedEntryIds: pushedEntryIds,
        );
        return ApiSuccess(result.matrix.entries.length);
      },
      onFailure: ApiFailureResult.new,
    );
  }

  ApiFailure _syncFailureToApiFailure(ExecutionFailureState failure) {
    if (failure is SyncFailureOffline) {
      return ApiFailureOffline(failure.detail);
    }
    if (failure is SyncFailureAuthRequired) {
      return const ApiFailureAuthRequired();
    }
    if (failure is SyncFailureTimeout) {
      return const ApiFailureOffline('Sync timed out.');
    }
    return ApiFailureUnknown(failure.userMessage);
  }
}
