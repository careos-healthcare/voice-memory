import 'package:voicememory_mobile/storage/secure_storage.dart';

/// Platform-channel-free secure storage mock for unit and widget tests.
final class MemorySecureStorage extends SecureStorageService {
  final Map<String, String> _values = <String, String>{};

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
  Future<void> clearAll() async {
    _values.clear();
  }
}
