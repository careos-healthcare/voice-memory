import 'package:archiveme_mobile/storage/encrypted_json_storage.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Encrypted personal-content blob stored as an opaque string in prefs.
class SensitivePrefsEncryptedBlob {
  const SensitivePrefsEncryptedBlob({
    required this.prefs,
    required this.encryptedStorage,
    required this.securePrefsKey,
    required this.payloadRootKey,
  });

  final MobilePrefsStore prefs;
  final EncryptedJsonStorage encryptedStorage;
  final String securePrefsKey;

  /// Root key inside the encrypted JSON object, e.g. `notes` or `renamed`.
  final String payloadRootKey;

  Future<Map<String, String>> readStringMap() async {
    final encrypted = await prefs.readString(securePrefsKey);
    if (encrypted == null || encrypted.trim().isEmpty) {
      return {};
    }
    final decrypted = await encryptedStorage.decryptData(encrypted);
    if (decrypted == null) return {};
    final raw = decrypted[payloadRootKey];
    if (raw is! Map) return {};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  Future<void> writeStringMap(Map<String, String> values) async {
    final encrypted = await encryptedStorage.encryptData({
      payloadRootKey: values,
    });
    await prefs.writeString(securePrefsKey, encrypted);
    final verified = await _readDecryptedRoot();
    if (!_stringMapsEqual(verified, values)) {
      throw StateError('Encrypted write verification failed for $securePrefsKey');
    }
  }

  Future<void> clear() async {
    await prefs.writeString(securePrefsKey, '');
  }

  /// Idempotent migration: legacy plaintext field → encrypted blob → verify →
  /// remove plaintext. Interruption before verification leaves legacy intact.
  Future<bool> migrateLegacyStringMapField({
    required String legacyPrefsKey,
    required String legacyFieldName,
    void Function()? onAfterEncryptedWriteBeforePlaintextDelete,
  }) async {
    final legacyPrefs = await prefs.readJsonMap(legacyPrefsKey);
    if (legacyPrefs == null) return false;

    final legacyRaw = legacyPrefs[legacyFieldName];
    final legacyValues = _parseStringMap(legacyRaw);
    final existing = await readStringMap();

    if (legacyValues.isEmpty) {
      return false;
    }

    final merged = {...existing, ...legacyValues};
    if (_stringMapsEqual(merged, existing)) {
      final metadataOnly = Map<String, dynamic>.from(legacyPrefs)
        ..remove(legacyFieldName);
      await prefs.writeJsonMap(legacyPrefsKey, metadataOnly);
      return true;
    }

    await writeStringMap(merged);
    onAfterEncryptedWriteBeforePlaintextDelete?.call();

    final readBack = await readStringMap();
    if (!_stringMapsEqual(readBack, merged)) {
      return false;
    }

    final metadataOnly = Map<String, dynamic>.from(legacyPrefs)
      ..remove(legacyFieldName);
    await prefs.writeJsonMap(legacyPrefsKey, metadataOnly);
    return true;
  }

  Future<Map<String, String>> _readDecryptedRoot() async {
    final encrypted = await prefs.readString(securePrefsKey);
    if (encrypted == null || encrypted.trim().isEmpty) return {};
    final decrypted = await encryptedStorage.decryptData(encrypted);
    if (decrypted == null) return {};
    return _parseStringMap(decrypted[payloadRootKey]);
  }

  static Map<String, String> _parseStringMap(Object? raw) {
    if (raw is! Map) return {};
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toString();
      final value = entry.value?.toString().trim();
      if (key == null || key.isEmpty || value == null || value.isEmpty) {
        continue;
      }
      result[key] = value;
    }
    return result;
  }

  static bool _stringMapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
