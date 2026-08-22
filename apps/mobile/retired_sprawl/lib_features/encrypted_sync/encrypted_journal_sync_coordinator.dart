import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/features/encrypted_sync/encrypted_sync_service.dart';
import 'package:archiveme_mobile/features/encrypted_sync/legacy_plaintext_migration_service.dart';
import 'package:archiveme_mobile/features/encrypted_sync/sync_master_key_store.dart';
import 'package:archiveme_mobile/storage/device_id.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/sync/sync_engine.dart';
import 'package:archiveme_mobile/sync/sync_outbox_store.dart';

export 'encrypted_sync_service.dart';
export 'legacy_plaintext_migration_service.dart';
export 'sync_crypto.dart';
export 'sync_master_key_store.dart';

/// Orchestrates encrypted journal sync and optional legacy plaintext migration.
///
/// Production mobile never uploads plaintext journal content. Plaintext
/// `/api/journal` is used only inside [LegacyPlaintextMigrationService] when
/// the user explicitly runs a one-time migration.
class EncryptedJournalSyncCoordinator {
  EncryptedJournalSyncCoordinator({
    required SyncApiClient syncApi,
    required JournalStore journal,
    required MobilePrefsStore prefs,
    required DeviceIdStore deviceIds,
    required SyncMasterKeyStore keyStore,
    SyncOutboxStore? outboxStore,
    SyncEngine? syncEngine,
  }) : _encrypted = EncryptedSyncService(
         syncApi: syncApi,
         journal: journal,
         prefs: prefs,
         deviceIds: deviceIds,
         keyStore: keyStore,
         outboxStore: outboxStore,
         syncEngine: syncEngine,
       ),
       _legacyMigration = LegacyPlaintextMigrationService(
         syncApi: syncApi,
         journal: journal,
         prefs: prefs,
         deviceIds: deviceIds,
         keyStore: keyStore,
       );

  final EncryptedSyncService _encrypted;
  final LegacyPlaintextMigrationService _legacyMigration;

  Future<
    ApiResult<({int pushed, int pulled, int blocked, bool migratedLegacy})>
  >
  syncNow() async {
    var migratedLegacy = false;
    try {
      if (await _legacyMigration.isMigrationPending()) {
        await _legacyMigration.runMigrationIfNeeded();
        migratedLegacy = true;
      }
    } on Object catch (error, stackTrace) {
      return ApiFailureResult(ApiFailureMapper.fromException(error));
    }

    final encrypted = await _encrypted.syncEncryptedJournal();
    return encrypted.when(
      success: (result) => ApiSuccess((
        pushed: result.pushed,
        pulled: result.pulled,
        blocked: result.blocked,
        migratedLegacy: migratedLegacy,
      )),
      onFailure: ApiFailureResult.new,
    );
  }
}