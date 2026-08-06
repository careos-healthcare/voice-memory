import '../../api/api_client.dart';
import '../../api/api_exceptions.dart';
import '../../models/journal_entry.dart';
import '../../services/journal_ownership_guard.dart';
import '../../storage/device_id.dart';
import '../../storage/journal_store.dart';
import '../../storage/mobile_prefs_store.dart';
import 'encrypted_journal_snapshot.dart';
import 'sync_crypto.dart';
import 'sync_master_key_store.dart';

/// Encrypted journal sync via `/api/sync/*` — no plaintext journal fields leave
/// the device. The server stores ciphertext envelopes only.
class EncryptedSyncService {
  EncryptedSyncService({
    required ApiClient api,
    required JournalStore journal,
    required MobilePrefsStore prefs,
    required DeviceIdStore deviceIds,
    required SyncMasterKeyStore keyStore,
    JournalOwnershipGuard ownershipGuard = const JournalOwnershipGuard(),
  }) : _api = api,
       _journal = journal,
       _prefs = prefs,
       _deviceIds = deviceIds,
       _keyStore = keyStore,
       _ownershipGuard = ownershipGuard;

  final ApiClient _api;
  final JournalStore _journal;
  final MobilePrefsStore _prefs;
  final DeviceIdStore _deviceIds;
  final SyncMasterKeyStore _keyStore;
  final JournalOwnershipGuard _ownershipGuard;

  Future<({List<JournalEntry> eligible, int blocked})> _partitionByOwnership(
    List<JournalEntry> entries,
  ) async {
    final currentOwnerKey =
        await _prefs.readString(JournalOwnershipGuard.ownerKeyPrefsKey) ?? '';
    final migrationPending =
        await _prefs.readBool(JournalOwnershipGuard.migrationPendingPrefsKey) ??
        false;
    final eligible = <JournalEntry>[];
    var blocked = 0;
    for (final entry in entries) {
      if (_ownershipGuard.isEligibleForSync(
        entryOwnerKey: entry.ownerKey,
        currentUserId: currentOwnerKey,
        migrationPending: migrationPending,
      )) {
        eligible.add(entry);
      } else {
        blocked++;
      }
    }
    return (eligible: eligible, blocked: blocked);
  }

  Future<({int pushed, int pulled, int blocked})> syncEncryptedJournal() async {
    final accountNamespace =
        await _prefs.readString(JournalOwnershipGuard.ownerKeyPrefsKey) ?? 'guest';
    final keyBytes = await _keyStore.ensureKey();
    final crypto = SyncCrypto(keyBytes);
    final deviceId = await _deviceIds.getOrCreate();
    final binding = SyncCrypto.envelopeBinding(
      accountNamespace: accountNamespace,
      blobType: EncryptedSyncSchema.coreBlobType,
      blobId: EncryptedSyncSchema.coreBlobId,
      schemaVersion: EncryptedSyncSchema.version,
    );

    final localAll = await _journal.loadAllIncludingTombstones();
    final partitioned = await _partitionByOwnership(localAll);
    final snapshot = buildEncryptedJournalSnapshot(
      deviceId: deviceId,
      accountNamespace: accountNamespace,
      entries: partitioned.eligible,
      updatedAt: DateTime.now().toUtc(),
      lastSyncedAt: _parseLastSync(await _prefs.lastSyncAt),
    );

    final encrypted = await crypto.encryptJson(snapshot);
    final byteLength = encrypted.ciphertext.length + encrypted.iv.length;
    final updatedAt = DateTime.now().toUtc().toIso8601String();

    await _api.syncPush({
      'blobs': [
        {
          'id': EncryptedSyncSchema.coreBlobId,
          'type': EncryptedSyncSchema.coreBlobType,
          'encrypted': encrypted.toJson(),
          'updatedAt': updatedAt,
          'byteLength': byteLength,
          'binding': binding,
        },
      ],
    });

    final pullBody = await _api.syncPull();
    final blobs = pullBody['blobs'];
    var pulled = 0;
    if (blobs is List) {
      for (final raw in blobs) {
        if (raw is! Map<String, dynamic>) continue;
        if (raw['id'] != EncryptedSyncSchema.coreBlobId) continue;
        if (raw['type'] != EncryptedSyncSchema.coreBlobType) continue;
        final encJson = raw['encrypted'];
        if (encJson is! Map<String, dynamic>) continue;
        final payload = EncryptedPayload.fromJson(encJson);
        final decrypted = await crypto.decryptJson(payload);
        final remoteEntries = journalEntriesFromSnapshot(decrypted);
        await _journal.mergeRemoteBatch(remoteEntries);
        pulled = remoteEntries.length;
      }
    }

    await _journal.compactTombstonesBatch();
    await _prefs.setLastSyncAt(DateTime.now());
    await _journal.markSyncedBatch(partitioned.eligible.map((e) => e.id).toSet());

    return (pushed: partitioned.eligible.length, pulled: pulled, blocked: partitioned.blocked);
  }

  DateTime? _parseLastSync(String? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}
