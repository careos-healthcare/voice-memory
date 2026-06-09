import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/session.dart';
import '../storage/session_cookie_store.dart';
import '../storage/secure_storage.dart';

class AuthService {
  AuthService(this._api, this._secure, this._cookies);

  final ApiClient _api;
  final SecureStorageService _secure;
  final SessionCookieStore _cookies;

  Future<void> Function()? onSignedIn;

  UserSession? _cached;

  UserSession? get currentSession => _cached;

  Future<void> loadPersistedSession() async {
    try {
      final cookie = await _cookies.read();
      if (cookie != null && cookie.isNotEmpty) {
        _api.setSessionCookie(cookie);
        _cached = await _api.getSession();
      }
    } catch (e, st) {
      debugPrint('Auth: persisted session refresh failed — continuing startup: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      _cached = null;
    }
  }

  Future<UserSession?> refreshSession() async {
    try {
      _cached = await _api.getSession();
      if (_cached != null) {
        await _secure.write('last_email', _cached!.email);
      }
    } catch (e, st) {
      debugPrint('Auth: refreshSession failed — continuing: $e');
      if (kDebugMode) debugPrint('$st');
      _cached = null;
    }
    return _cached;
  }

  Future<void> sendAuthCode(String email) async {
    await _api.sendAuthCode(email);
    await _secure.write('last_email', email.trim());
  }

  Future<UserSession> verifyAuthCode({
    required String email,
    required String code,
  }) async {
    final session = await _api.verifyAuthCode(email: email, code: code);
    _cached = session;
    final cookie = _api.sessionCookie;
    if (cookie != null) await _cookies.write(cookie);
    await _secure.write('last_email', email.trim());
    await onSignedIn?.call();
    return session;
  }

  Future<void> signOut() async {
    try {
      await _api.signOut();
    } catch (_) {}
    _cached = null;
    _api.setSessionCookie(null);
    await _cookies.clear();
  }

  Future<String?> lastEmail() => _secure.read('last_email');
}
