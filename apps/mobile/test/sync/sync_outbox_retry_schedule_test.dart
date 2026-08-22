import 'dart:io';
import '../storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/api/models/sync_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/features/encrypted_sync/encrypted_journal_snapshot.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/drift/journal_database.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/sync/sync_backoff_policy.dart';
import 'package:archiveme_mobile/sync/sync_engine.dart';
import 'package:archiveme_mobile/sync/sync_outbox_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _blob = SyncBlobPushDto(
  id: EncryptedSyncSchema.coreBlobId,
  type: EncryptedSyncSchema.coreBlobType,
  encrypted: EncryptedPayloadDto(ciphertext: 'abc', iv: 'iv'),
  updatedAt: '2026-08-11T12:00:00.000Z',
  byteLength: 12,
);

class _FailingSyncApiClient implements SyncApiClient {
  @override
  Future<ApiResult<Map<String, dynamic>>> syncChanges({required int since}) async {
    return const ApiSuccess({'changes': []});
  }

  @override
  Future<ApiResult<List<JournalEntry>>> listLegacyJournal({
    NetworkCancelToken? cancelToken,
  }) async {
    return const ApiSuccess([]);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncManifest() async {
    return const ApiSuccess({'blobs': []});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPull() async {
    return const ApiSuccess({'blobs': []});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPush(
    Map<String, dynamic> body,
  ) async {
    return ApiFailureResult(
      const ApiFailureOffline('offline during push'),
    );
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('pending excludes rows until next_retry_at elapses', () async {
    final db = await openTestAppSqliteDatabase();
    final store = SyncOutboxStore(
      AppDatabase.fromSqflite(db.database),
      backoff: const SyncBackoffPolicy(
        initialDelay: Duration(seconds: 30),
        maxAttempts: 5,
      ),
    );

    final outboxId = await store.enqueue(_blob);

    await store.markInFlight(outboxId);
    await store.markFailed(outboxId, 'NETWORK_ERROR');

    expect(await store.pendingCount(), 0);

    final row = (await db.database.query(
      'sync_outbox',
      where: 'outbox_id = ?',
      whereArgs: [outboxId],
    )).single;
    expect(row['next_retry_at'], isNotNull);

    final nextReady = await store.nextReadyAt();
    expect(nextReady, isNotNull);
    expect(nextReady!.isAfter(DateTime.now().toUtc()), isTrue);
  });

  test('dead letters row after max attempts', () async {
    final db = await openTestAppSqliteDatabase();
    final store = SyncOutboxStore(
      AppDatabase.fromSqflite(db.database),
      backoff: const SyncBackoffPolicy(maxAttempts: 2),
    );

    final outboxId = await store.enqueue(_blob);

    await store.markInFlight(outboxId);
    await store.markFailed(outboxId, 'NETWORK_ERROR');
    await store.markInFlight(outboxId);
    await store.markFailed(outboxId, 'NETWORK_ERROR');

    final row = (await db.database.query(
      'sync_outbox',
      where: 'outbox_id = ?',
      whereArgs: [outboxId],
    )).single;
    expect(row['status'], 'failed');
    expect(await store.pendingCount(), 0);
  });

  test('drainOutbox schedules retry when push fails', () async {
    final dir = Directory.systemTemp.createTempSync('sync_outbox_retry_');
    final journal = await JournalStore.open('${dir.path}/journal.json');
    final db = await openTestAppSqliteDatabase();
    final store = SyncOutboxStore(AppDatabase.fromSqflite(db.database));
    final engine = SyncEngine(
      syncApi: _FailingSyncApiClient(),
      journal: journal,
      outbox: store,
      backoff: const SyncBackoffPolicy(
        initialDelay: Duration(seconds: 10),
        maxAttempts: 1,
      ),
    );

    await store.enqueue(_blob);

    final drain = await engine.drainOutbox();
    expect(drain, isA<ApiFailureResult<SyncOutboxDrainResult>>());
    expect(await store.pendingCount(), 0);
    expect(await store.nextReadyAt(), isNotNull);
  });
}
