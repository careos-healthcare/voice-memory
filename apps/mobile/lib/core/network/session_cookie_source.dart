import 'package:archiveme_mobile/core/network/http_transport.dart' show HttpTransport;

import 'package:archiveme_mobile/data/repositories/auth_repository.dart' show AuthRepository;

import 'package:archiveme_mobile/storage/session_cookie_store.dart';

/// In-memory session cookie with optional secure-store persistence.
///
/// Shared by [HttpTransport], [AuthRepository], and [ApiClient] so auth state
/// is not duplicated on the monolithic client.
class SessionCookieSource {
  SessionCookieSource(this._store);

  final SessionCookieStore _store;
  String? _current;

  String? get current => _current;

  Future<void> hydrateFromStore() async {
    _current = await _store.read();
  }

  /// Updates memory only — used when tests inject cookies without disk I/O.
  void setInMemory(String? cookie) {
    _current = cookie;
  }

  Future<void> applyCookie(String? cookie, {required bool persist}) async {
    _current = cookie;
    if (!persist) return;
    if (cookie == null || cookie.isEmpty) {
      await _store.clear();
      return;
    }
    await _store.write(cookie);
  }

  Future<void> clear({required bool persist}) =>
      applyCookie(null, persist: persist);

  Map<String, String> headerEntries() {
    final cookie = _current;
    if (cookie == null || cookie.isEmpty) return const {};
    return {'Cookie': cookie};
  }
}