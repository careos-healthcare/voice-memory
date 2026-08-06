import '../../api/api_client.dart';
import '../../storage/device_id.dart';
import '../../storage/journal_store.dart';
import '../../storage/mobile_prefs_store.dart';
import 'encrypted_sync_service.dart';
import 'legacy_plaintext_migration_service.dart';
import 'sync_master_key_store.dart';

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
    required ApiClient api,
    required JournalStore journal,
    required MobilePrefsStore prefs,
    required DeviceIdStore deviceIds,
    required SyncMasterKeyStore keyStore,
  }) : _encrypted = EncryptedSyncService(
         api: api,
         journal: journal,
         prefs: prefs,
         deviceIds: deviceIds,
         keyStore: keyStore,
       ),
       _legacyMigration = LegacyPlaintextMigrationService(
         api: api,
         journal: journal,
         prefs: prefs,
         deviceIds: deviceIds,
         keyStore: keyStore,
       );

  final EncryptedSyncService _encrypted;
  final LegacyPlaintextMigrationService _legacyMigration;

  Future<({int pushed, int pulled, int blocked, bool migratedLegacy})>
  syncNow() async {
    var migratedLegacy = false;
    if (await _legacyMigration.isMigrationPending()) {
      await _legacyMigration.runMigrationIfNeeded();
      migratedLegacy = true;
    }
    final result = await _encrypted.syncEncryptedJournal();
    return (
      pushed: result.pushed,
      pulled: result.pulled,
      blocked: result.blocked,
      migratedLegacy: migratedLegacy,
    );
  }
}
