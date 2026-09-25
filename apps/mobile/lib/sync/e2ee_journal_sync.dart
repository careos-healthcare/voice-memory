import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/api/models/sync_dto.dart';
import 'package:archiveme_mobile/core/crypto/e2e_encryption_service.dart' as e2ee;
import 'package:archiveme_mobile/core/crypto/passphrase_vault.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Serializes SQLite journal rows, seals them, and keeps the newer copy.
abstract final class E2eeJournalSync {
  E2eeJournalSync._();

  static const blobId = 'journal-e2ee';
  static const blobType = 'journal_snapshot';

  static String generatePassphrase([Random? random]) {
    final source = random ?? Random.secure();
    final bytes = List<int>.generate(18, (_) => source.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String serializeEntries(List<JournalEntry> entries) {
    return jsonEncode({
      'entries': [for (final entry in entries) entry.toJson()],
    });
  }

  /// Newer [JournalEntry.updatedAt] wins. A tie keeps the copy already on device.
  static JournalEntry lastWriteWins(JournalEntry local, JournalEntry incoming) {
    if (incoming.updatedAt.isAfter(local.updatedAt)) return incoming;
    return local;
  }

  static List<JournalEntry> mergeByUpdatedAt({
    required List<JournalEntry> local,
    required List<JournalEntry> remote,
  }) {
    final byId = {for (final entry in local) entry.id: entry};
    for (final incoming in remote) {
      final current = byId[incoming.id];
      byId[incoming.id] = current == null ? incoming : lastWriteWins(current, incoming);
    }
    return byId.values.toList();
  }

  static Future<SyncBlobPushDto> encryptSnapshot({
    required e2ee.E2EEncryptionService encryption,
    required Future<PassphraseVault> Function(String passphrase) openVault,
    required List<JournalEntry> entries,
    required String passphrase,
  }) async {
    await openVault(passphrase);
    final plain = serializeEntries(entries);
    final sealed = await encryption.encryptText(plain, passphrase);
    final packed = base64Encode(
      utf8.encode(
        jsonEncode({
          'ciphertext': sealed.ciphertext,
          'nonce': sealed.nonce,
          'mac': sealed.mac,
          'salt': sealed.salt,
        }),
      ),
    );
    final newest = entries.fold<DateTime?>(null, (latest, entry) {
      if (latest == null || entry.updatedAt.isAfter(latest)) return entry.updatedAt;
      return latest;
    });
    return SyncBlobPushDto(
      id: blobId,
      type: blobType,
      encrypted: EncryptedPayloadDto(ciphertext: packed, iv: sealed.nonce),
      updatedAt: (newest ?? DateTime.now().toUtc()).toIso8601String(),
      byteLength: packed.length,
    );
  }

  static Future<List<JournalEntry>> decryptSnapshot({
    required e2ee.E2EEncryptionService encryption,
    required EncryptedPayloadDto envelope,
    required String passphrase,
  }) async {
    final packed = jsonDecode(utf8.decode(base64Decode(envelope.ciphertext))) as Map<String, dynamic>;
    final plain = await encryption.decryptText(
      e2ee.EncryptedPayload(
        ciphertext: packed['ciphertext'] as String,
        nonce: packed['nonce'] as String,
        mac: packed['mac'] as String,
        salt: packed['salt'] as String,
      ),
      passphrase,
    );
    final decoded = jsonDecode(plain) as Map<String, dynamic>;
    final rows = decoded['entries'] as List<dynamic>? ?? const [];
    return [
      for (final row in rows)
        if (row is Map) JournalEntry.fromJson(Map<String, dynamic>.from(row)),
    ];
  }
}
