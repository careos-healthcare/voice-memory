import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/data/repositories/sync_repository.dart';
import 'package:archiveme_mobile/features/encrypted_sync/encrypted_journal_sync_coordinator.dart';
import 'package:archiveme_mobile/features/encrypted_sync/sync_master_key_store.dart';
import 'package:archiveme_mobile/features/sync/application/sync_notifier.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/services/journal_ownership_guard.dart';
import 'package:archiveme_mobile/services/sync_service.dart';
import 'package:archiveme_mobile/storage/drift/journal_database.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/sync/sync_backoff_policy.dart';
import 'package:archiveme_mobile/sync/sync_engine.dart';
import 'package:archiveme_mobile/sync/sync_outbox_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../storage/sqlite/support/sqlite_test_database.dart';

import '../../helpers/encrypted_sync_test_helpers.dart';
import '../../support/test_storage_sandbox.dart';

/// Zero-delay backoff so integration tests can drain the outbox immediately.
const syncIntegrationTestBackoff = SyncBackoffPolicy(
  initialDelay: Duration.zero,
  maxDelay: Duration.zero,
  maxAttempts: 5,
);

/// [RecordingSyncApiClient] with a toggleable network partition and optional
/// transient push failures for retry/recovery scenarios.
class PartitionedSyncApiClient extends RecordingSyncApiClient {
  PartitionedSyncApiClient({
    required super.keyStore,
    required super.accountNamespace,
    super.deviceId,
    super.pullEntries,
    super.syncPushError,
  });

  bool online = true;
  int transientPushFailuresRemaining = 0;

  void setOnline(bool value) {
    online = value;
    syncPushError = value ? null : const ApiFailureOffline('network partition');
  }

  void failNextPushAttempts(int count) {
    transientPushFailuresRemaining = count;
  }

  void setRemoteSnapshot(List<JournalEntry> entries) {
    pullEntries = entries;
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPush(
    Map<String, dynamic> body,
  ) async {
    if (!online) {
      syncPushCalls++;
      return ApiFailureResult(
        const ApiFailureOffline('network partition during push'),
      );
    }
    if (transientPushFailuresRemaining > 0) {
      syncPushCalls++;
      transientPushFailuresRemaining--;
      return ApiFailureResult(
        const ApiFailureOffline('transient push failure'),
      );
    }
    return super.syncPush(body);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPull() async {
    if (!online) {
      return ApiFailureResult(
        const ApiFailureOffline('network partition during pull'),
      );
    }
    return super.syncPull();
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncChanges({
    required int since,
  }) async {
    if (!online) {
      return ApiFailureResult(
        const ApiFailureOffline('network partition during syncChanges'),
      );
    }
    final pullResult = await super.syncPull();
    return pullResult.when(
      success: (body) {
        final blobs = body['blobs'];
        if (blobs is! List || blobs.isEmpty) {
          return ApiSuccess({
            'changes': const [],
            'blobs': const [],
            'latestSequence': since,
          });
        }
        return ApiSuccess({
          'changes': const [],
          'blobs': blobs,
          'latestSequence': since + 1,
        });
      },
      onFailure: ApiFailureResult.new,
    );
  }
}

/// Wires in-memory SQLite, encrypted sync, outbox, and journal mirror helpers
/// for end-to-end offline/conflict integration tests.
final class SyncIntegrationTestHarness {
  SyncIntegrationTestHarness._({
    required this.sandbox,
    required this.journal,
    required this.prefs,
    required this.sqlite,
    required this.outbox,
    required this.journalSqlite,
    required this.syncApi,
    required this.engine,
    required this.coordinator,
    required this.syncService,
  });

  final TestStorageSandbox sandbox;
  final JournalStore journal;
  final MobilePrefsStore prefs;
  final AppSqliteDatabase sqlite;
  final SyncOutboxStore outbox;
  final JournalSqliteRepository journalSqlite;
  final PartitionedSyncApiClient syncApi;
  final SyncEngine engine;
  final EncryptedJournalSyncCoordinator coordinator;
  final SyncService syncService;

  static Future<SyncIntegrationTestHarness> create({
    List<JournalEntry> initialRemoteEntries = const [],
    SyncBackoffPolicy outboxBackoff = syncIntegrationTestBackoff,
    SyncBackoffPolicy engineBackoff = syncIntegrationTestBackoff,
    String ownerKey = 'user-integration',
  }) async {
    AppConfig.configureForTest();

    final sandbox = TestStorageSandbox.create(prefix: 'vm_sync_integration_');
    final journal = await JournalStore.open(
      sandbox.journalPath,
      encryptAtRest: false,
    );
    journal.setActiveOwnerKey(ownerKey);

    final prefs = await MobilePrefsStore.open(sandbox.prefsPath);
    await prefs.writeString(JournalOwnershipGuard.ownerKeyPrefsKey, ownerKey);
    await prefs.writeBool(JournalOwnershipGuard.migrationPendingPrefsKey, false);
    await markLegacyMigrationComplete(prefs);

    final sqliteDb = await openTestAppSqliteDatabase();
    final driftDb = AppDatabase.fromSqflite(sqliteDb.database);
    final outbox = SyncOutboxStore(driftDb, backoff: outboxBackoff);

    final keyStore = InMemorySyncMasterKeyStore();
    final syncApi = PartitionedSyncApiClient(
      keyStore: keyStore,
      accountNamespace: ownerKey,
      pullEntries: initialRemoteEntries,
    );

    final engine = SyncEngine(
      syncApi: syncApi,
      journal: journal,
      outbox: outbox,
      backoff: engineBackoff,
    );

    final coordinator = EncryptedJournalSyncCoordinator(
      syncApi: syncApi,
      journal: journal,
      prefs: prefs,
      deviceIds: TestDeviceIdStore(),
      keyStore: keyStore,
      outboxStore: outbox,
      syncEngine: engine,
    );

    final holder = SyncRepositoryHolder()
      ..value = SyncRepository(coordinator: coordinator, prefs: prefs);
    final container = ProviderContainer(
      overrides: [syncRepositoryHolderProvider.overrideWithValue(holder)],
    );
    final syncService = SyncService(container.read(syncProvider.notifier));

    return SyncIntegrationTestHarness._(
      sandbox: sandbox,
      journal: journal,
      prefs: prefs,
      sqlite: sqliteDb,
      outbox: outbox,
      journalSqlite: JournalSqliteRepository(sqliteDb),
      syncApi: syncApi,
      engine: engine,
      coordinator: coordinator,
      syncService: syncService,
    );
  }

  void setOnline(bool online) => syncApi.setOnline(online);

  void setRemoteSnapshot(List<JournalEntry> entries) =>
      syncApi.setRemoteSnapshot(entries);

  void failNextPushAttempts(int count) => syncApi.failNextPushAttempts(count);

  Future<SyncResult> syncNow() => syncService.syncNow();

  Future<void> savePendingEdit(JournalEntry entry) async {
    await journal.saveEdit(
      entry.copyWith(syncStatus: SyncStatus.pendingUpload),
    );
  }

  Future<void> mirrorJournalToSqlite() async {
    final entries = await journal.loadAllIncludingTombstones();
    await journalSqlite.mirrorEntireRemoteState(entries);
  }

  Future<List<Map<String, Object?>>> outboxRows() =>
      sqlite.database.query('sync_outbox');

  Future<Map<String, Object?>?> sqliteJournalRow(String entryId) async {
    final rows = await sqlite.database.query(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.single;
  }

  Future<void> expectSqliteMirrorMatchesJournal({required String entryId}) async {
    await mirrorJournalToSqlite();
    final journalEntry =
        await journal.getByIdIncludingTombstones(entryId);
    final sqliteRow = await sqliteJournalRow(entryId);

    if (journalEntry == null || journalEntry.isDeleted) {
      if (journalEntry?.isDeleted == true) {
        expect(sqliteRow, isNotNull);
        expect(sqliteRow!['deleted_at'], isNotNull);
      } else {
        expect(sqliteRow, isNull);
      }
      return;
    }

    expect(sqliteRow, isNotNull);
    expect(sqliteRow!['transcript'], journalEntry.transcript);
    expect(sqliteRow['deleted_at'], isNull);
  }

  void dispose() => sandbox.dispose();
}
