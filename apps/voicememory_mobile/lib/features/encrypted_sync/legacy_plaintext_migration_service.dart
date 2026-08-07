import '../../core/network/api_result.dart';
import '../../data/network/sync_api_client.dart';
import '../../models/journal_entry.dart';
import '../../storage/device_id.dart';
import '../../storage/journal_store.dart';
import '../../storage/mobile_prefs_store.dart';
import 'encrypted_journal_snapshot.dart';
import 'encrypted_sync_service.dart';
import 'sync_master_key_store.dart';

/// Safe, resumable migration from legacy plaintext `/api/journal` rows to
/// encrypted `/api/sync/*` blobs. Never deletes server plaintext automatically.
class LegacyPlaintextMigrationService {
  LegacyPlaintextMigrationService({
    required SyncApiClient syncApi,
    required JournalStore journal,
    required MobilePrefsStore prefs,
    required DeviceIdStore deviceIds,
    required SyncMasterKeyStore keyStore,
  }) : _syncApi = syncApi,
       _journal = journal,
       _prefs = prefs,
       _deviceIds = deviceIds,
       _keyStore = keyStore;

  static const stateKey = 'legacy_plaintext_migration_v1';
  static const eligibleDeletionKey = 'legacy_plaintext_deletion_eligible_v1';

  final SyncApiClient _syncApi;
  final JournalStore _journal;
  final MobilePrefsStore _prefs;
  final DeviceIdStore _deviceIds;
  final SyncMasterKeyStore _keyStore;

  Future<bool> isMigrationPending() async {
    final raw = await _prefs.readJsonMap(stateKey);
    if (raw == null) return true;
    return raw['status'] != 'completed';
  }

  /// Idempotent migration steps — safe to retry after interruption.
  Future<void> runMigrationIfNeeded() async {
    final state = await _prefs.readJsonMap(stateKey) ?? {};
    if (state['status'] == 'completed') return;

    state['status'] = 'in_progress';
    state['startedAt'] ??= DateTime.now().toUtc().toIso8601String();
    await _prefs.writeJsonMap(stateKey, state);

    // 1. Authenticated read of legacy plaintext (migration-only path).
    final legacyResult = await _syncApi.listLegacyJournal();
    if (legacyResult case ApiFailureResult(:final failure)) {
      throw failure.toApiException();
    }
    final legacyRemote = (legacyResult as ApiSuccess<List<JournalEntry>>).value;
    state['legacyRemoteCount'] = legacyRemote.length;

    // 2. Validate shape locally.
    final validated = <JournalEntry>[];
    for (final entry in legacyRemote) {
      if (_isValidLegacyEntry(entry)) {
        validated.add(entry);
      }
    }
    state['validatedCount'] = validated.length;

    // 3–4. Merge locally then upload encrypted replacement via encrypted sync.
    if (validated.isNotEmpty) {
      await _journal.mergeRemote(validated);
    }
    final encryptedSync = EncryptedSyncService(
      syncApi: _syncApi,
      journal: _journal,
      prefs: _prefs,
      deviceIds: _deviceIds,
      keyStore: _keyStore,
    );
    final syncResult = await encryptedSync.syncEncryptedJournal();
    if (syncResult case ApiFailureResult(:final failure)) {
      throw failure.toApiException();
    }

    // 5–6. Verify coverage against local merged state.
    final localIds = (await _journal.loadAllIncludingTombstones())
        .map((e) => e.id)
        .toSet();
    final legacyIds = legacyRemote
        .map((e) => e.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    final validatedIds = validated.map((e) => e.id).toSet();
    final unvalidatedLegacy = legacyIds.difference(validatedIds);
    final covered = legacyIds.difference(localIds);
    state['uncoveredLegacyIds'] = [...covered, ...unvalidatedLegacy];
    state['coverageComplete'] = covered.isEmpty && unvalidatedLegacy.isEmpty;

    // 7. Mark plaintext eligible for audited deletion — do not delete here.
    if (state['coverageComplete'] == true) {
      await _prefs.writeJsonMap(eligibleDeletionKey, {
        'eligibleAt': DateTime.now().toUtc().toIso8601String(),
        'legacyRowCount': legacyRemote.length,
        'note':
            'Server plaintext journal rows may be deleted only after operator audit.',
      });
      state['status'] = 'completed';
      state['completedAt'] = DateTime.now().toUtc().toIso8601String();
    } else {
      state['status'] = 'pending_retry';
    }

    await _prefs.writeJsonMap(stateKey, state);
  }

  bool _isValidLegacyEntry(JournalEntry entry) {
    return entry.id.isNotEmpty &&
        entry.createdAt.isBefore(DateTime.now().add(const Duration(days: 1)));
  }
}
