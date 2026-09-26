import 'dart:convert';

import 'package:archiveme_mobile/core/crypto/passphrase_vault.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// One journal entry sealed on its own. The passphrase never leaves the device.
class EncryptedPayload {
  const EncryptedPayload({
    required this.id,
    required this.version,
    required this.nonce,
    required this.ciphertext,
  });

  final String id;
  final int version;
  final String nonce;
  final String ciphertext;

  Map<String, Object> toJson() => {
    'id': id,
    'version': version,
    'nonce': nonce,
    'ciphertext': ciphertext,
  };
}

/// AES-GCM-256 for a single journal entry or one attachment.
class EntryEncryptionService {
  EntryEncryptionService(this._vault);

  static const version = 1;

  final PassphraseVault _vault;

  Future<EncryptedPayload> encryptSingleEntry(JournalEntry entry) async {
    final sealed = await encryptBytes(utf8.encode(jsonEncode(entry.toJson())));
    return EncryptedPayload(
      id: entry.id,
      version: version,
      nonce: sealed.nonce,
      ciphertext: sealed.ciphertext,
    );
  }

  Future<JournalEntry> decryptSingleEntry(EncryptedPayload payload) async {
    if (payload.version != version) {
      throw FormatException(
        'Unsupported journal seal version ${payload.version}.',
      );
    }
    final clear = await decryptBytes(
      nonce: payload.nonce,
      ciphertext: payload.ciphertext,
    );
    final decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map) {
      throw const FormatException('Sealed journal entry was not an object.');
    }
    final entry = JournalEntry.fromJson(Map<String, dynamic>.from(decoded));
    if (entry.id != payload.id) {
      throw const FormatException('Sealed journal entry id did not match.');
    }
    return entry;
  }

  Future<CiphertextBlob> encryptBytes(List<int> bytes) {
    return _vault.encrypt(bytes);
  }

  Future<List<int>> decryptBytes({
    required String nonce,
    required String ciphertext,
  }) {
    return _vault.decrypt(
      CiphertextBlob(
        ciphertext: ciphertext,
        nonce: nonce,
        salt: base64Encode(_vault.salt),
      ),
    );
  }
}
