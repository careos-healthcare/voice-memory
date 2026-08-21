import 'dart:async';

import 'package:archiveme_mobile/api/models/sync_dto.dart';
import 'package:archiveme_mobile/core/execution/execution.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/sync/sync_backoff_policy.dart';
import 'package:archiveme_mobile/sync/sync_conflict_resolution.dart';
import 'package:archiveme_mobile/sync/sync_outbox_store.dart';
import 'package:archiveme_mobile/sync/ulid.dart';

export 'sync_backoff_policy.dart';
export 'sync_outbox_background_service.dart';
export 'sync_outbox_store.dart';
export 'ulid.dart' show generateUlid, isValidUlid;

/// Server-reported blob upsert status from `POST /api/sync/push`.
enum SyncBlobUpsertStatus {
  created,
  updated,
  existing;

  static SyncBlobUpsertStatus? parse(String? raw) {
    switch (raw) {
      case 'created':
        return SyncBlobUpsertStatus.created;
      case 'updated':
        return SyncBlobUpsertStatus.updated;
      case 'existing':
        return SyncBlobUpsertStatus.existing;
      default:
        return null;
    }
  }
}

class SyncBlobStatusMatrixEntry {
  const SyncBlobStatusMatrixEntry({
    required this.id,
    required this.type,
    required this.status,
  });

  factory SyncBlobStatusMatrixEntry.fromJson(Map<String, dynamic> json) {
    return SyncBlobStatusMatrixEntry(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      status:
          SyncBlobUpsertStatus.parse(json['status'] as String?) ??
          SyncBlobUpsertStatus.updated,
    );
  }

  final String id;
  final String type;
  final SyncBlobUpsertStatus status;

  bool get applied =>
      status == SyncBlobUpsertStatus.created ||
      status == SyncBlobUpsertStatus.updated ||
      status == SyncBlobUpsertStatus.existing;
}

class SyncPushStatusMatrix {
  const SyncPushStatusMatrix(this.entries);

  factory SyncPushStatusMatrix.fromResponse(Map<String, dynamic> body) {
    final raw = body['statusMatrix'];
    if (raw is! List) return const SyncPushStatusMatrix([]);
    return SyncPushStatusMatrix(
      raw
          .whereType<Map>()
          .map((entry) => SyncBlobStatusMatrixEntry.fromJson(
                Map<String, dynamic>.from(entry),
              ))
          .toList(),
    );
  }

  final List<SyncBlobStatusMatrixEntry> entries;

  bool blobApplied(String blobId) =>
      entries.any((entry) => entry.id == blobId && entry.applied);

  int get createdCount => entries
      .where((entry) => entry.status == SyncBlobUpsertStatus.created)
      .length;

  int get updatedCount => entries
      .where((entry) => entry.status == SyncBlobUpsertStatus.updated)
      .length;

  int get existingCount => entries
      .where((entry) => entry.status == SyncBlobUpsertStatus.existing)
      .length;
}

/// Summary of draining the drift-backed encrypted sync outbox.
class SyncOutboxDrainResult {
  const SyncOutboxDrainResult({
    required this.pushedCount,
    required this.remaining,
    required this.responseBody,
    required this.matrix,
  });

  final int pushedCount;
  final int remaining;
  final Map<String, dynamic> responseBody;
  final SyncPushStatusMatrix matrix;
}

/// Offline-first journal sync with a local SQLite outbox as source of truth.
class SyncEngine {
  SyncEngine({
    required SyncApiClient syncApi,
    required JournalStore journal,
    SyncOutboxStore? outbox,
    SyncBackoffPolicy backoff = const SyncBackoffPolicy(),
    SyncExecutionStrategy? syncStrategy,
  }) : _syncApi = syncApi,
       _journal = journal,
       _outbox = outbox,
       _backoff = backoff,
       _syncStrategy = syncStrategy ?? SyncExecutionStrategy(backoff: backoff);

  final SyncApiClient _syncApi;
  final JournalStore _journal;
  final SyncOutboxStore? _outbox;
  final SyncBackoffPolicy _backoff;
  final SyncExecutionStrategy _syncStrategy;

  bool get hasOutbox => _outbox != null;

  SyncOutboxStore get outbox {
    final store = _outbox;
    if (store == null) {
      throw StateError('SyncOutboxStore is not configured on this SyncEngine');
    }
    return store;
  }

  /// All offline journal entries must use ULIDs so retries stay idempotent.
  static String newOfflineEntryId() => generateUlid();

  static bool isOfflineEntryId(String id) => isValidUlid(id);

  static JournalEntry ensureOfflineEntryId(JournalEntry entry) {
    if (isOfflineEntryId(entry.id)) return entry;
    return entry.copyWith(id: newOfflineEntryId());
  }

  Future<List<JournalEntry>> pendingQueue() => _journal.pendingSyncQueue();

  /// Saves [blob] to the drift outbox before any network I/O.
  Future<String> enqueueBlob(SyncBlobPushDto blob) async {
    return outbox.enqueue(blob);
  }

  /// Builds a [SyncBlobPushDto] map body from pending outbox rows and pushes
  /// it to the remote sync target with retry/backoff.
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
      return ApiSuccess(
        SyncOutboxDrainResult(
          pushedCount: 0,
          remaining: 0,
          responseBody: const {},
          matrix: const SyncPushStatusMatrix([]),
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
        ({Map<String, dynamic> body, SyncPushStatusMatrix matrix})>(
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
      success: (value) => ApiSuccess(value),
      onFailure: (failure) =>
          ApiFailureResult(_syncFailureToApiFailure(failure)),
      onDeferred: (failure) =>
          ApiFailureResult(_syncFailureToApiFailure(failure)),
      onCancelled: () => const ApiFailureResult(ApiFailureCancelled()),
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
      return ApiFailureOffline('Sync timed out.');
    }
    return ApiFailureUnknown(failure.userMessage);
  }

  /// Marks queued entries synced once the server acknowledges the blob push.
  Future<void> acknowledgeAppliedPush({
    required SyncPushStatusMatrix matrix,
    required String coreBlobId,
    required Iterable<String> pushedEntryIds,
  }) async {
    if (!matrix.blobApplied(coreBlobId)) return;
    await _journal.markSyncedBatch(pushedEntryIds.toSet());
  }

  /// Enqueues encrypted blobs locally, drains the outbox, then acks journal rows.
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
}
