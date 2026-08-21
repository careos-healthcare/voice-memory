import 'package:archiveme_mobile/storage/secure_storage.dart';

/// Persists vm_session cookie for authenticated API calls.
class SessionCookieStore {
  SessionCookieStore(this._secure);

  final SecureStorageService _secure;
  static const _key = 'auth_cookie';

  Future<String?> read() => _secure.read(_key);

  Future<void> write(String cookie) => _secure.write(_key, cookie);

  Future<void> clear() => _secure.delete(_key);
}