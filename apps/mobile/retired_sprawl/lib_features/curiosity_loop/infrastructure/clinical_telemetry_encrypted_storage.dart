import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/storage/encrypted_json_storage.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';

/// Provisions [EncryptedJsonStorage] for clinical telemetry prefs blobs.
class ClinicalTelemetryEncryptedStorage {
  ClinicalTelemetryEncryptedStorage._();

  static const secureStorageKey = 'clinical_telemetry_encryption_key_v1';
  static const keyByteLength = 32;

  static Future<EncryptedJsonStorage> forSecureStorage(
    SecureStorageService secure,
  ) async {
    final existing = await secure.read(secureStorageKey);
    if (existing != null && existing.isNotEmpty) {
      final keyBytes = base64Decode(existing);
      if (keyBytes.length == keyByteLength) {
        return EncryptedJsonStorage(masterKeyBytes: keyBytes);
      }
    }

    final random = Random.secure();
    final keyBytes = List<int>.generate(
      keyByteLength,
      (_) => random.nextInt(256),
    );
    await secure.write(secureStorageKey, base64Encode(keyBytes));
    return EncryptedJsonStorage(masterKeyBytes: keyBytes);
  }

  static EncryptedJsonStorage forTest({List<int>? masterKeyBytes}) {
    return EncryptedJsonStorage(
      masterKeyBytes: masterKeyBytes ?? List<int>.generate(32, (i) => i),
    );
  }
}