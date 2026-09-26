import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/core/crypto/passphrase_vault.dart';
import 'package:archiveme_mobile/features/settings/e2ee_sync_settings.dart';
import 'package:archiveme_mobile/features/sync/services/sync_conflict_resolver.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/sync/e2ee_journal_sync.dart';

/// Ciphertext for one journal row. The derived key stays inside [PassphraseVault].
class E2eeCipherPayload {
  const E2eeCipherPayload({required this.ciphertext, required this.nonce});

  final String ciphertext;
  final String nonce;
}

/// AES-256-GCM over a journal JSON string. Only ciphertext and a nonce leave.
class E2eeJournalCipher {
  E2eeJournalCipher(this._vault);

  final PassphraseVault _vault;

  static Future<E2eeJournalCipher> open({
    required String passphrase,
    SaltStore? store,
  }) async {
    final vault = await PassphraseVault.open(
      passphrase: passphrase,
      store: store ?? SaltStore.secureStorage(),
    );
    return E2eeJournalCipher(vault);
  }

  /// Creates a high-entropy passphrase, stores it in the secure vault, and
  /// derives the local key. The key itself is not returned.
  static Future<String> generateAndStore({
    SaltStore? store,
    Random? random,
  }) async {
    final passphrase = E2eeJournalSync.generatePassphrase(random);
    final box = store ?? SaltStore.secureStorage();
    await box.write(E2eeSyncSettings.passphraseKey, passphrase);
    await PassphraseVault.open(passphrase: passphrase, store: box);
    return passphrase;
  }

  Future<E2eeCipherPayload> encryptEntry(JournalEntry entry) {
    return encryptPayload(jsonEncode(entry.toJson()));
  }

  Future<JournalEntry> decryptEntry(String ciphertext, String nonce) async {
    final clear = await decryptPayload(ciphertext, nonce);
    final decoded = jsonDecode(clear);
    if (decoded is! Map) {
      throw const FormatException('Encrypted journal entry was not an object.');
    }
    return JournalEntry.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<E2eeCipherPayload> encryptPayload(String jsonData) async {
    final sealed = await _vault.encrypt(utf8.encode(jsonData));
    return E2eeCipherPayload(
      ciphertext: sealed.ciphertext,
      nonce: sealed.nonce,
    );
  }

  Future<String> decryptPayload(String ciphertext, String nonce) async {
    final clear = await _vault.decrypt(
      CiphertextBlob(
        ciphertext: ciphertext,
        nonce: nonce,
        salt: base64Encode(_vault.salt),
      ),
    );
    return utf8.decode(clear);
  }
}

class RemoteEncryptedEntry {
  const RemoteEncryptedEntry({
    required this.id,
    required this.ciphertext,
    required this.nonce,
    required this.updatedAt,
  });

  final String id;
  final String ciphertext;
  final String nonce;
  final DateTime updatedAt;
}

class EncryptedJournalPush {
  const EncryptedJournalPush({
    required this.id,
    required this.ciphertext,
    required this.nonce,
    required this.updatedAt,
  });

  final String id;
  final String ciphertext;
  final String nonce;
  final DateTime updatedAt;
}

class E2eeDeltaSyncResult {
  const E2eeDeltaSyncResult({
    required this.completed,
    required this.overwrittenIds,
    required this.pushedIds,
    this.syncedAt,
  });

  final bool completed;
  final DateTime? syncedAt;
  final List<String> overwrittenIds;
  final List<String> pushedIds;
}

/// Pulls encrypted rows since [lastSyncTime], applies last-write-wins, then
/// pushes local rows that are newer or still pending.
abstract final class E2eeDeltaSync {
  E2eeDeltaSync._();

  static const lastSyncKey = 'last_sync_time';
  static const entryBlobType = 'journal_entry';

  static Future<E2eeDeltaSyncResult> run({
    required bool cloudSyncEnabled,
    required DateTime? lastSyncTime,
    required List<JournalEntry> localEntries,
    required List<RemoteEncryptedEntry> remote,
    required Future<E2eeCipherPayload> Function(JournalEntry entry) encryptEntry,
    required Future<JournalEntry> Function(String ciphertext, String nonce)
    decryptEntry,
    required Future<void> Function(JournalEntry entry) saveLocal,
    required Future<void> Function(List<EncryptedJournalPush> records) push,
  }) async {
    if (!cloudSyncEnabled) {
      return const E2eeDeltaSyncResult(
        completed: false,
        overwrittenIds: [],
        pushedIds: [],
      );
    }

    final local = {for (final entry in localEntries) entry.id: entry};
    final tookFromServer = <String>{};
    final pushLocal = <JournalEntry>[];

    for (final record in remote) {
      if (lastSyncTime != null && !record.updatedAt.isAfter(lastSyncTime)) {
        continue;
      }
      final current = local[record.id];
      final action = SyncConflictResolver.resolve(
        localUpdatedAt: current?.updatedAt,
        remoteUpdatedAt: record.updatedAt,
      );
      if (action == SyncConflictAction.keepRemote) {
        final entry = await decryptEntry(record.ciphertext, record.nonce);
        await saveLocal(entry);
        local[entry.id] = entry;
        tookFromServer.add(entry.id);
      } else if (current != null) {
        pushLocal.add(current);
      }
    }

    for (final entry in local.values) {
      if (tookFromServer.contains(entry.id)) continue;
      if (pushLocal.any((row) => row.id == entry.id)) continue;
      final pending = entry.syncStatus == SyncStatus.pendingUpload;
      final newer =
          lastSyncTime == null || entry.updatedAt.isAfter(lastSyncTime);
      if (pending || newer) pushLocal.add(entry);
    }

    final encrypted = <EncryptedJournalPush>[];
    for (final entry in pushLocal) {
      final payload = await encryptEntry(entry);
      encrypted.add(
        EncryptedJournalPush(
          id: entry.id,
          ciphertext: payload.ciphertext,
          nonce: payload.nonce,
          updatedAt: entry.updatedAt,
        ),
      );
    }
    await push(encrypted);
    return E2eeDeltaSyncResult(
      completed: true,
      syncedAt: DateTime.now().toUtc(),
      overwrittenIds: tookFromServer.toList(),
      pushedIds: [for (final entry in pushLocal) entry.id],
    );
  }
}
