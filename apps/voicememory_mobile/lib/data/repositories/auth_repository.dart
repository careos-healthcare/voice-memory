import '../../core/network/api_result.dart';
import '../../core/network/session_cookie_source.dart';
import '../../models/session.dart';
import '../../storage/secure_storage.dart';
import '../network/auth_api_client.dart';

/// Persists session cookies and coordinates auth API calls.
class AuthRepository {
  AuthRepository({
    required AuthApiClient api,
    required SessionCookieSource sessionCookies,
    required SecureStorageService secure,
  }) : _api = api,
       _sessionCookies = sessionCookies,
       _secure = secure;

  final AuthApiClient _api;
  final SessionCookieSource _sessionCookies;
  final SecureStorageService _secure;

  static const _lastEmailKey = 'last_email';

  Future<ApiResult<UserSession?>> hydrateFromStoredCookie() async {
    await _sessionCookies.hydrateFromStore();
    if (_sessionCookies.current == null || _sessionCookies.current!.isEmpty) {
      return const ApiSuccess(null);
    }
    return refreshSession(persistEmail: false);
  }

  Future<ApiResult<UserSession?>> refreshSession({
    bool persistEmail = true,
  }) async {
    final result = await _api.getSession();
    if (result case ApiSuccess(:final value)) {
      if (value != null && persistEmail) {
        await _secure.write(_lastEmailKey, value.email);
      }
      if (value == null) {
        await _sessionCookies.clear(persist: true);
      }
      return ApiSuccess(value);
    }
    if (result case ApiFailureResult(:final failure)) {
      await _sessionCookies.clear(persist: true);
      return ApiFailureResult(failure);
    }
    throw StateError('Unhandled auth refresh result: $result');
  }

  Future<ApiResult<void>> sendAuthCode(String email) async {
    final result = await _api.sendAuthCode(email);
    if (result case ApiSuccess<void>()) {
      await _secure.write(_lastEmailKey, email.trim());
    }
    return result;
  }

  Future<ApiResult<UserSession>> verifyAuthCode({
    required String email,
    required String code,
  }) async {
    final result = await _api.verifyAuthCode(email: email, code: code);
    if (result case ApiSuccess(:final value)) {
      final cookie = value.sessionCookie;
      if (cookie != null && cookie.isNotEmpty) {
        await _sessionCookies.applyCookie(cookie, persist: true);
      }
      await _secure.write(_lastEmailKey, email.trim());
      return ApiSuccess(value.session);
    }
    if (result case ApiFailureResult(:final failure)) {
      return ApiFailureResult(failure);
    }
    throw StateError('Unhandled auth verify result: $result');
  }

  Future<ApiResult<void>> signOut() async {
    final serverResult = await _api.signOut();
    await _sessionCookies.clear(persist: true);
    return serverResult;
  }

  Future<String?> lastEmail() => _secure.read(_lastEmailKey);
}
