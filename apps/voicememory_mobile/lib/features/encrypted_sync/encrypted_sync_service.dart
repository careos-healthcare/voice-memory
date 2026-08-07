import '../../core/network/api_result.dart';
import '../../data/network/sync_api_client.dart';
import '../../models/journal_entry.dart';
import '../../security/account_session_guard.dart';
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
    required SyncApiClient syncApi,
    required JournalStore journal,
    required MobilePrefsStore prefs,
    required DeviceIdStore deviceIds,
    required SyncMasterKeyStore keyStore,
    JournalOwnershipGuard ownershipGuard = const JournalOwnershipGuard(),
  }) : _syncApi = syncApi,
       _journal = journal,
       _prefs = prefs,
       _deviceIds = deviceIds,
       _keyStore = keyStore,
       _ownershipGuard = ownershipGuard;

  final SyncApiClient _syncApi;
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

  Future<ApiResult<({int pushed, int pulled, int blocked})>>
  syncEncryptedJournal() async {
    final session = AccountSessionGuard.capture();
    final accountNamespace =
        await _prefs.readString(JournalOwnershipGuard.ownerKeyPrefsKey) ??
        'guest';
    final keyBytes = await _keyStore.ensureKey();
    final crypto = SyncCrypto(keyBytes);
    final deviceId = await _deviceIds.getOrCreate();
    final binding = SyncCrypto.envelopeBinding(
      accountNamespace: accountNamespace,
      blobType: EncryptedSyncSchema.coreBlobType,
      blobId: EncryptedSyncSchema.coreBlobId,
      schemaVersion: EncryptedSyncSchema.version,
    );

    session.assertActive();
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

    session.assertActive();
    final pushResult = await _syncApi.syncPush({
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
    late final Map<String, dynamic> pushBody;
    switch (pushResult) {
      case ApiSuccess(:final value):
        pushBody = value;
      case ApiFailureResult(:final failure):
        return ApiFailureResult(failure);
    }

    session.assertActive();
    final pullResult = await _pullRemoteBlobs(session);
    late final List<Map<String, dynamic>> remoteBlobs;
    late final int? pullLatestSequence;
    switch (pullResult) {
      case ApiSuccess(:final value):
        remoteBlobs = value.blobs;
        pullLatestSequence = value.latestSequence;
      case ApiFailureResult(:final failure):
        return ApiFailureResult(failure);
    }
    var pulled = 0;
    var latestSequence = pullLatestSequence ?? _readLatestSequence(pushBody);
    for (final raw in remoteBlobs) {
      if (raw['id'] != EncryptedSyncSchema.coreBlobId) continue;
      if (raw['type'] != EncryptedSyncSchema.coreBlobType) continue;
      final encJson = raw['encrypted'];
      if (encJson is! Map<String, dynamic>) continue;
      session.assertActive();
      final payload = EncryptedPayload.fromJson(encJson);
      final decrypted = await crypto.decryptJson(payload);
      final remoteEntries = journalEntriesFromSnapshot(decrypted);
      await _journal.mergeRemoteBatch(remoteEntries);
      pulled = remoteEntries.length;
    }

    session.assertActive();
    await _journal.compactTombstonesBatch();
    await _prefs.setLastSyncAt(DateTime.now());
    if (latestSequence != null) {
      await _prefs.setLastSyncSequence(latestSequence);
    }
    await _journal.markSyncedBatch(
      partitioned.eligible.map((e) => e.id).toSet(),
    );

    return ApiSuccess((
      pushed: partitioned.eligible.length,
      pulled: pulled,
      blocked: partitioned.blocked,
    ));
  }

  Future<ApiResult<({List<Map<String, dynamic>> blobs, int? latestSequence})>>
  _pullRemoteBlobs(AccountSessionGuard session) async {
    final since = await _prefs.lastSyncSequence ?? 0;
    if (since > 0) {
      session.assertActive();
      final changesResult = await _syncApi.syncChanges(since: since);
      late final Map<String, dynamic> changesBody;
      switch (changesResult) {
        case ApiSuccess(:final value):
          changesBody = value;
        case ApiFailureResult(:final failure):
          return ApiFailureResult(failure);
      }
      final latestSequence = latestSequenceFromChanges(changesBody);
      final blobs = changesBody['blobs'];
      if (blobs is List) {
        return ApiSuccess((
          blobs: blobs
              .whereType<Map>()
              .map((blob) => Map<String, dynamic>.from(blob))
              .toList(),
          latestSequence: latestSequence,
        ));
      }
      return ApiSuccess((
        blobs: <Map<String, dynamic>>[],
        latestSequence: latestSequence,
      ));
    }

    session.assertActive();
    final pullResult = await _syncApi.syncPull();
    late final Map<String, dynamic> pullBody;
    switch (pullResult) {
      case ApiSuccess(:final value):
        pullBody = value;
      case ApiFailureResult(:final failure):
        return ApiFailureResult(failure);
    }
    final blobs = pullBody['blobs'];
    if (blobs is! List) {
      return ApiSuccess((blobs: <Map<String, dynamic>>[], latestSequence: null));
    }
    return ApiSuccess((
      blobs: blobs
          .whereType<Map>()
          .map((blob) => Map<String, dynamic>.from(blob))
          .toList(),
      latestSequence: null,
    ));
  }

  int? _readLatestSequence(Map<String, dynamic> pushBody) {
    final manifest = pushBody['manifest'];
    if (manifest is Map<String, dynamic>) {
      final raw = manifest['latestSequence'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
    }
    return null;
  }

  int? latestSequenceFromChanges(Map<String, dynamic> changesBody) {
    final raw = changesBody['latestSequence'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

  DateTime? _parseLastSync(String? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}
