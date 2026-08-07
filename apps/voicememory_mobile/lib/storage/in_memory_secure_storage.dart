import 'secure_storage.dart';

/// In-memory [SecureStorageService] for widget/unit tests — no platform channels.
class InMemorySecureStorageService extends SecureStorageService {
  InMemorySecureStorageService();

  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _data.clear();
  }
}
