import '../storage/secure_storage.dart';

/// Small-value private storage backed by platform keychain / encrypted prefs.
///
/// Suitable for encryption key material, lock settings, and other secrets —
/// not for bulk journal text (journal remains JSON on disk until a dedicated
/// encryption layer is added).
///
/// TODO(security): add `cryptography` package and envelope-encrypt journal
/// files at rest using a key stored here once bulk encryption is scoped.
abstract class EncryptedPrivateStore {
  Future<void> writePrivateString(String key, String value);
  Future<String?> readPrivateString(String key);
  Future<void> deletePrivateValue(String key);
  Future<void> wipePrivateNamespace(String namespace);
}

/// Production implementation over [SecureStorageService].
class SecureEncryptedPrivateStore implements EncryptedPrivateStore {
  SecureEncryptedPrivateStore({SecureStorageService? secure})
    : _secure = secure ?? SecureStorageService();

  final SecureStorageService _secure;

  String _namespacedKey(String namespace, String key) =>
      'private_${namespace}_$key';

  @override
  Future<void> writePrivateString(String key, String value) async {
    final parts = _splitKey(key);
    await _secure.write(_namespacedKey(parts.namespace, parts.localKey), value);
  }

  @override
  Future<String?> readPrivateString(String key) async {
    final parts = _splitKey(key);
    return _secure.read(_namespacedKey(parts.namespace, parts.localKey));
  }

  @override
  Future<void> deletePrivateValue(String key) async {
    final parts = _splitKey(key);
    await _secure.delete(_namespacedKey(parts.namespace, parts.localKey));
  }

  @override
  Future<void> wipePrivateNamespace(String namespace) async {
    // SecureStorageService has no namespace listing — delete known keys only.
    const knownSuffixes = ['encryption_key_v1', 'settings_blob'];
    for (final suffix in knownSuffixes) {
      await _secure.delete(_namespacedKey(namespace, suffix));
    }
  }

  _KeyParts _splitKey(String key) {
    final slash = key.indexOf('/');
    if (slash <= 0 || slash >= key.length - 1) {
      return _KeyParts(namespace: 'default', localKey: key);
    }
    return _KeyParts(
      namespace: key.substring(0, slash),
      localKey: key.substring(slash + 1),
    );
  }
}

class _KeyParts {
  const _KeyParts({required this.namespace, required this.localKey});
  final String namespace;
  final String localKey;
}
