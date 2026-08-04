import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted storage for non-secret preferences and future session handles.
/// Do not store API keys, Stripe secrets, or raw passwords here.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;
  static const _prefix = 'vm_flutter_';

  Future<void> write(String key, String value) async {
    _assertSafeKey(key);
    await _storage.write(key: '$_prefix$key', value: value);
  }

  Future<String?> read(String key) async {
    _assertSafeKey(key);
    return _storage.read(key: '$_prefix$key');
  }

  Future<void> delete(String key) => _storage.delete(key: '$_prefix$key');

  Future<void> clearAll() async {
    final all = await _storage.readAll();
    for (final entry in all.entries) {
      if (entry.key.startsWith(_prefix)) {
        await _storage.delete(key: entry.key);
      }
    }
  }

  void _assertSafeKey(String key) {
    final lower = key.toLowerCase();
    const banned = [
      'secret',
      'password',
      'token',
      'api_key',
      'stripe',
      'openai',
    ];
    if (banned.any(lower.contains)) {
      throw StateError('Refusing to store sensitive key: $key');
    }
  }
}

/// Process-local secure-storage substitute for tests.
///
/// Production composition never constructs this class.
class InMemorySecureStorageService extends SecureStorageService {
  InMemorySecureStorageService();

  final Map<String, String> _values = {};

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clearAll() async => _values.clear();
}
