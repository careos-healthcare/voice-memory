import 'dart:async';

import 'package:archiveme_mobile/api/models/sync_dto.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/crypto/passphrase_vault.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/data/network/http_sync_api_client.dart';
import 'package:archiveme_mobile/features/insights/knowledge_forget_service.dart';
import 'package:archiveme_mobile/features/settings/e2ee_sync_settings.dart';
import 'package:archiveme_mobile/features/sync/services/e2ee_journal_sync.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Sends journal text to the server fact ledger when cloud features are on.
class CloudSyncService {
  CloudSyncService({
    Future<void> Function(String entryId, String transcript)? upload,
    Future<bool> Function()? isCloudSyncEnabled,
    Future<List<JournalEntry>> Function()? loadEntries,
    Future<Set<String>> Function()? forgottenLabels,
  }) : _upload = upload ?? _postToApi,
       _isCloudSyncEnabled = isCloudSyncEnabled ?? _readCloudPreference,
       _loadEntries = loadEntries ?? _readLocalEntries,
       _forgottenLabels = forgottenLabels ?? _readForgottenLabels;

  static const ingestPath = '/api/ledger/ingest';

  final Future<void> Function(String entryId, String transcript) _upload;
  final Future<bool> Function() _isCloudSyncEnabled;
  final Future<List<JournalEntry>> Function() _loadEntries;
  final Future<Set<String>> Function() _forgottenLabels;

  /// Posts one entry. Does nothing while cloud features are off.
  /// Forgotten labels are left out of the copy sent to the server.
  Future<void> uploadEntryToLedger(JournalEntry entry) async {
    if (!await _isCloudSyncEnabled()) return;
    if (entry.isDeleted) return;
    final transcript = omitForgottenLabels(
      entry.transcript.trim(),
      await _forgottenLabels(),
    );
    if (transcript.isEmpty) return;
    try {
      await _upload(entry.id, transcript);
    } on Object {
      return;
    }
  }

  /// Pushes every local journal entry once cloud features are on.
  static Future<void> backfillLocalEntries() {
    return CloudSyncService().backfill();
  }

  Future<void> backfill() async {
    if (!await _isCloudSyncEnabled()) return;
    final entries = await _loadEntries();
    for (final entry in entries) {
      await uploadEntryToLedger(entry);
    }
  }

  static Future<void> _postToApi(String entryId, String transcript) async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.httpTransport.post(
      ingestPath,
      body: {'entryId': entryId, 'transcript': transcript},
    );
  }

  static Future<bool> _readCloudPreference() async {
    if (!AppServices.isInitialized) return false;
    final preferences = await UserPreferences.load(AppServices.instance.prefs);
    return preferences.isCloudSyncEnabled;
  }

  static Future<List<JournalEntry>> _readLocalEntries() {
    if (!AppServices.isInitialized) return Future.value(const []);
    return AppServices.instance.journal.loadAll();
  }

  static Future<Set<String>> _readForgottenLabels() async {
    if (!AppServices.isInitialized) return {};
    return ForgottenKnowledge.load(AppServices.instance.prefs);
  }
}

/// Runs encrypted sync jobs one at a time so a resume cannot overlap a startup.
class E2eeSyncQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> enqueue<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    _tail = result.then((_) {}, onError: (_, _) {});
    return result;
  }
}

/// Starts a delta sync when cloud features are on and a passphrase is stored.
abstract final class E2eeSyncLifecycle {
  E2eeSyncLifecycle._();

  static final queue = E2eeSyncQueue();

  static Future<void> syncIfEnabled() {
    return queue.enqueue(_syncIfEnabled);
  }

  static Future<void> _syncIfEnabled() async {
    if (!V1CapabilityRegistry.e2eeSync) return;
    if (!AppServices.isInitialized) return;
    try {
      final preferences = await UserPreferences.load(
        AppServices.instance.prefs,
      );
      if (!preferences.isCloudSyncEnabled) return;
      final box = SaltStore.secureStorage();
      final passphrase = await box.read(E2eeSyncSettings.passphraseKey);
      if (passphrase == null || passphrase.trim().isEmpty) return;
      final cipher = await E2eeJournalCipher.open(
        passphrase: passphrase,
        store: box,
      );
      final lastRaw = await AppServices.instance.prefs.readString(
        E2eeDeltaSync.lastSyncKey,
      );
      final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);
      final local = await AppServices.instance.journal.loadAll();
      final remote = await _pull(last);
      final result = await E2eeDeltaSync.run(
        cloudSyncEnabled: true,
        lastSyncTime: last,
        localEntries: local,
        remote: remote,
        encrypt: cipher.encryptPayload,
        decrypt: cipher.decryptPayload,
        saveLocal: (entry) => AppServices.instance.journalStore.save(entry),
        push: _push,
      );
      final syncedAt = result.syncedAt;
      if (result.completed && syncedAt != null) {
        await AppServices.instance.prefs.writeString(
          E2eeDeltaSync.lastSyncKey,
          syncedAt.toUtc().toIso8601String(),
        );
      }
    } on Object {
      return;
    }
  }

  static Future<List<RemoteEncryptedEntry>> _pull(DateTime? since) async {
    final client = HttpSyncApiClient(AppServices.instance.httpTransport);
    final result = await client.syncPull();
    return result.when(
      success: (body) {
        final pull = SyncPullResponseDto.fromJson(body);
        return [
          for (final blob in pull.blobs)
            if (blob.type == E2eeDeltaSync.entryBlobType)
              if (DateTime.tryParse(blob.updatedAt) case final updated?)
                if (since == null || updated.isAfter(since))
                  RemoteEncryptedEntry(
                    id: blob.id,
                    ciphertext: blob.encrypted.ciphertext,
                    nonce: blob.encrypted.iv,
                    updatedAt: updated,
                  ),
        ];
      },
      onFailure: (_) => const <RemoteEncryptedEntry>[],
    );
  }

  static Future<void> _push(List<EncryptedJournalPush> records) async {
    if (records.isEmpty) return;
    final client = HttpSyncApiClient(AppServices.instance.httpTransport);
    final result = await client.syncPush(
      SyncPushRequestDto(
        blobs: [
          for (final record in records)
            SyncBlobPushDto(
              id: record.id,
              type: E2eeDeltaSync.entryBlobType,
              encrypted: EncryptedPayloadDto(
                ciphertext: record.ciphertext,
                iv: record.nonce,
              ),
              updatedAt: record.updatedAt.toUtc().toIso8601String(),
              byteLength: record.ciphertext.length,
            ),
        ],
      ).toJson(),
    );
    final failed = result.when(success: (_) => false, onFailure: (_) => true);
    if (failed) throw StateError('Encrypted sync push did not succeed.');
  }
}
