import 'package:voicememory_mobile/core/network/api_failure.dart';
import 'package:voicememory_mobile/core/network/api_result.dart';
import 'package:voicememory_mobile/core/network/network_cancel_token.dart';
import 'package:voicememory_mobile/data/network/sync_api_client.dart';
import 'package:voicememory_mobile/features/encrypted_sync/encrypted_journal_snapshot.dart';
import 'package:voicememory_mobile/features/encrypted_sync/legacy_plaintext_migration_service.dart';
import 'package:voicememory_mobile/features/encrypted_sync/sync_crypto.dart';
import 'package:voicememory_mobile/features/encrypted_sync/sync_master_key_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

/// Marks legacy plaintext migration complete so encrypted sync tests skip it.
Future<void> markLegacyMigrationComplete(MobilePrefsStore prefs) async {
  await prefs.writeJsonMap(LegacyPlaintextMigrationService.stateKey, {
    'status': 'completed',
  });
}

/// Avoids flutter_secure_storage platform channels in plain `test()` harnesses.
class TestDeviceIdStore extends DeviceIdStore {
  TestDeviceIdStore([this.id = '00000000-0000-4000-8000-000000000001']);

  final String id;

  @override
  Future<String> getOrCreate() async => id;
}

/// Records encrypted push snapshots and serves configurable pull blobs.
class RecordingSyncApiClient implements SyncApiClient {
  RecordingSyncApiClient({
    required SyncMasterKeyStore keyStore,
    required String accountNamespace,
    this.deviceId = '00000000-0000-4000-8000-000000000001',
    List<JournalEntry> pullEntries = const [],
    Object? syncPushError,
  }) : _keyStore = keyStore,
       _accountNamespace = accountNamespace,
       _pullEntries = List<JournalEntry>.from(pullEntries),
       syncPushError = syncPushError;

  final SyncMasterKeyStore _keyStore;
  final String _accountNamespace;
  final String deviceId;
  List<JournalEntry> _pullEntries;

  final pushedSnapshots = <List<JournalEntry>>[];
  var syncPushCalls = 0;
  var syncPullCalls = 0;
  var listLegacyJournalCalls = 0;
  Object? syncPushError;

  set pullEntries(List<JournalEntry> entries) {
    _pullEntries = List<JournalEntry>.from(entries);
  }

  List<String> get lastPushedEntryIds =>
      pushedSnapshots.isEmpty
          ? const []
          : pushedSnapshots.last.map((entry) => entry.id).toList();

  @override
  Future<ApiResult<Map<String, dynamic>>> syncManifest() async {
    return const ApiSuccess({'blobs': []});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPull() async {
    syncPullCalls++;
    if (_pullEntries.isEmpty) {
      return const ApiSuccess({'blobs': []});
    }
    final blob = await _encryptedBlobFor(_pullEntries);
    return ApiSuccess({'blobs': [blob], 'latestSequence': 1});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncChanges({
    required int since,
  }) async {
    return const ApiSuccess({'changes': []});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> syncPush(
    Map<String, dynamic> body,
  ) async {
    syncPushCalls++;
    final error = syncPushError;
    if (error != null) {
      if (error is ApiFailure) {
        return ApiFailureResult(error);
      }
      throw error;
    }

    final blobs = body['blobs'];
    if (blobs is List) {
      for (final raw in blobs) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        if (map['id'] != EncryptedSyncSchema.coreBlobId) continue;
        final encJson = map['encrypted'];
        if (encJson is! Map) continue;
        final keyBytes = await _keyStore.ensureKey();
        final crypto = SyncCrypto(keyBytes);
        final decrypted = await crypto.decryptJson(
          EncryptedPayload.fromJson(Map<String, dynamic>.from(encJson)),
        );
        pushedSnapshots.add(journalEntriesFromSnapshot(decrypted));
      }
    }

    return const ApiSuccess({
      'ok': true,
      'manifest': {'latestSequence': 1, 'blobs': []},
    });
  }

  @override
  Future<ApiResult<List<JournalEntry>>> listLegacyJournal({
    NetworkCancelToken? cancelToken,
  }) async {
    listLegacyJournalCalls++;
    return const ApiSuccess([]);
  }

  Future<Map<String, dynamic>> _encryptedBlobFor(
    List<JournalEntry> entries,
  ) async {
    final keyBytes = await _keyStore.ensureKey();
    final crypto = SyncCrypto(keyBytes);
    final snapshot = buildEncryptedJournalSnapshot(
      deviceId: deviceId,
      accountNamespace: _accountNamespace,
      entries: entries,
      updatedAt: DateTime.now().toUtc(),
    );
    final encrypted = await crypto.encryptJson(snapshot);
    return {
      'id': EncryptedSyncSchema.coreBlobId,
      'type': EncryptedSyncSchema.coreBlobType,
      'encrypted': encrypted.toJson(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'byteLength': encrypted.ciphertext.length + encrypted.iv.length,
      'binding': SyncCrypto.envelopeBinding(
        accountNamespace: _accountNamespace,
        blobType: EncryptedSyncSchema.coreBlobType,
        blobId: EncryptedSyncSchema.coreBlobId,
        schemaVersion: EncryptedSyncSchema.version,
      ),
    };
  }
}
