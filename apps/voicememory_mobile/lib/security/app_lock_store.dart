import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key-value contract the app lock needs, so tests can run on an
/// in-memory fake and production runs on the platform keychain/keystore.
abstract class AppLockSecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Production store backed by the platform secure storage (Keychain on
/// iOS, encrypted shared preferences on Android).
class SecureAppLockStore implements AppLockSecureStore {
  SecureAppLockStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory store for tests.
class MemoryAppLockStore implements AppLockSecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

/// Persistence for the app lock: enabled flag, salted PIN hash + salt, and
/// the biometrics opt-in. Only the hash and salt are ever written — there
/// is no API that accepts or returns a raw PIN.
class AppLockStore {
  AppLockStore({required this._store});

  final AppLockSecureStore _store;

  static const String enabledKey = 'vm_app_lock_enabled';
  static const String pinHashKey = 'vm_app_lock_pin_hash';
  static const String pinSaltKey = 'vm_app_lock_pin_salt';
  static const String biometricsKey = 'vm_app_lock_biometrics';

  Future<bool> enabled() async {
    try {
      return await _store.read(enabledKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<bool> biometricsEnabled() async {
    try {
      return await _store.read(biometricsKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometricsEnabled(bool enabled) =>
      _store.write(biometricsKey, enabled ? 'true' : 'false');

  /// Persists the derived credentials and turns the lock on. Hash and
  /// salt only — never a PIN.
  Future<void> saveCredentials({
    required String pinHash,
    required String pinSalt,
  }) async {
    await _store.write(pinHashKey, pinHash);
    await _store.write(pinSaltKey, pinSalt);
    await _store.write(enabledKey, 'true');
  }

  /// The stored (hash, salt) pair, or null when the lock is not set up.
  Future<({String hash, String salt})?> readCredentials() async {
    try {
      final hash = await _store.read(pinHashKey);
      final salt = await _store.read(pinSaltKey);
      if (hash == null || salt == null) return null;
      return (hash: hash, salt: salt);
    } catch (_) {
      return null;
    }
  }

  /// Removes everything the app lock ever stored.
  Future<void> clear() async {
    await _store.delete(pinHashKey);
    await _store.delete(pinSaltKey);
    await _store.delete(enabledKey);
    await _store.delete(biometricsKey);
  }
}
