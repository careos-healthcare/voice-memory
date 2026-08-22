import 'dart:io';
import '../storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/api/models/sync_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/features/encrypted_sync/encrypted_journal_snapshot.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/sync/sync_engine.dart';
import 'package:archiveme_mobile/storage/drift/journal_database.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/sync/sync_outbox_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

JournalEntry _offlineEntry({required String transcript}) => JournalEntry(
  id: SyncEngine.newOfflineEntryId(),
  createdAt: DateTime.utc(2026, 8, 11),
  transcript: transcript,
  durationSeconds: 3,
  reflection: _reflection(),
  syncStatus: SyncStatus.pendingUpload,
);

class _MidPayloadSyncApiClient implements SyncApiClient {
  _MidPayloadSyncApiClient();

  int pushAttempts = 0;
  bool serverHasBlob = false;

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
    pushAttempts++;
    if (pushAttempts == 1) {
      serverHasBlob = true;
      return ApiFailureResult(
        const ApiFailureOffline('Connection lost while uploading encrypted payload.'),
      );
    }

    final status = serverHasBlob ? 'existing' : 'created';
    return ApiSuccess({
      'ok': true,
      'manifest': {'latestSequence': 1, 'blobs': []},
      'statusMatrix': [
        {
          'id': EncryptedSyncSchema.coreBlobId,
          'type': EncryptedSyncSchema.coreBlobType,
          'status': status,
        },
      ],
    });
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('offline entries use ULIDs', () {
    final id = SyncEngine.newOfflineEntryId();
    expect(SyncEngine.isOfflineEntryId(id), isTrue);
    expect(id.length, 26);
  });

  test('journal store keeps ULID ids assigned at creation time', () async {
    final dir = Directory.systemTemp.createTempSync('vm_sync_ulid_');
    final store = await JournalStore.open('${dir.path}/journal.json', encryptAtRest: false);
    final ulid = SyncEngine.newOfflineEntryId();
    await store.save(
      JournalEntry(
        id: ulid,
        createdAt: DateTime.utc(2026),
        transcript: 'offline capture',
        durationSeconds: 1,
        reflection: _reflection(),
      ),
    );
    final saved = await store.getById(ulid);
    expect(saved?.id, ulid);
    expect(SyncEngine.isOfflineEntryId(saved!.id), isTrue);
  });

  test('recovers after mid-payload disconnect via idempotent retry', () async {
    final dir = Directory.systemTemp.createTempSync('vm_sync_recovery_');
    final journal = await JournalStore.open('${dir.path}/journal.json', encryptAtRest: false);
    final sqlite = await openTestAppSqliteDatabase();
    final outbox = SyncOutboxStore(AppDatabase.fromSqflite(sqlite.database));
    final client = _MidPayloadSyncApiClient();
    final engine = SyncEngine(
      syncApi: client,
      journal: journal,
      outbox: outbox,
      backoff: const SyncBackoffPolicy(
        initialDelay: Duration.zero,
        maxDelay: Duration.zero,
        maxAttempts: 3,
      ),
    );

    final entry = _offlineEntry(transcript: 'queued offline');
    await journal.save(entry);
    final savedId = (await journal.loadAll()).single.id;

    const blob = SyncBlobPushDto(
      id: EncryptedSyncSchema.coreBlobId,
      type: EncryptedSyncSchema.coreBlobType,
      encrypted: EncryptedPayloadDto(ciphertext: 'abc', iv: 'iv'),
      updatedAt: '2026-08-11T12:00:00.000Z',
      byteLength: 12,
    );

    final pendingBefore = await engine.pendingQueue();
    expect(pendingBefore, hasLength(1));
    expect(pendingBefore.single.syncStatus, isNot(SyncStatus.synced));
    expect(await outbox.pendingCount(), 0);

    await engine.enqueueBlob(blob);
    expect(await outbox.pendingCount(), 1);

    final result = await engine.flushOfflineQueue(
      blob: blob,
      coreBlobId: EncryptedSyncSchema.coreBlobId,
      pushedEntryIds: pendingBefore.map((e) => e.id),
    );

    expect(result, isA<ApiSuccess<int>>());
    expect(client.pushAttempts, 2);
    expect(await outbox.pendingCount(), 0);

    final synced = await journal.getById(savedId);
    expect(synced?.syncStatus, SyncStatus.synced);
    expect(await engine.pendingQueue(), isEmpty);
  });

  test('status matrix marks existing blobs as applied without duplicate writes', () {
    const matrix = SyncPushStatusMatrix([
      SyncBlobStatusMatrixEntry(
        id: EncryptedSyncSchema.coreBlobId,
        type: EncryptedSyncSchema.coreBlobType,
        status: SyncBlobUpsertStatus.existing,
      ),
    ]);

    expect(matrix.existingCount, 1);
    expect(matrix.createdCount, 0);
    expect(matrix.updatedCount, 0);
    expect(matrix.blobApplied(EncryptedSyncSchema.coreBlobId), isTrue);
  });
}