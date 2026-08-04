import 'package:flutter/foundation.dart';

import '../../../storage/encrypted_json_storage.dart';
import '../../../storage/mobile_prefs_store.dart';

/// Reads and writes encrypted JSON payloads in [MobilePrefsStore] string slots.
class EncryptedPrefsJsonBlob {
  const EncryptedPrefsJsonBlob({
    required this.prefs,
    required this.encryptedStorage,
    required this.prefsKey,
    required this.logLabel,
  });

  final MobilePrefsStore prefs;
  final EncryptedJsonStorage encryptedStorage;
  final String prefsKey;
  final String logLabel;

  Future<Map<String, dynamic>?> readMap() async {
    final encrypted = await prefs.readString(prefsKey);
    if (encrypted != null && encrypted.trim().isNotEmpty) {
      final decrypted = await encryptedStorage.decryptData(encrypted);
      if (decrypted != null) {
        return decrypted;
      }
      debugPrint(
        '$logLabel: failed to decrypt "$prefsKey"; '
        'falling back to legacy plaintext or empty state.',
      );
    }

    final legacy = await prefs.readJsonMap(prefsKey);
    if (legacy != null && legacy.isNotEmpty) {
      return legacy;
    }
    return null;
  }

  Future<void> writeMap(Map<String, dynamic> map) async {
    final encrypted = await encryptedStorage.encryptData(map);
    await prefs.writeString(prefsKey, encrypted);
  }

  Future<void> clear() async {
    await prefs.writeString(prefsKey, '');
  }
}
