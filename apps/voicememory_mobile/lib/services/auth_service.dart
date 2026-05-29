import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../config/app_config.dart';
import '../models/session.dart';
import '../storage/secure_storage.dart';

/// Auth placeholder — magic link + cookie session lives on web today.
class AuthService {
  AuthService(this._api, this._storage);

  final ApiClient _api;
  final SecureStorageService _storage;

  UserSession? _cached;

  UserSession? get currentSession => _cached;

  Future<UserSession?> refreshSession() async {
    if (!AppConfig.authImplemented) {
      _cached = await _trySessionFromApi();
      return _cached;
    }
    _cached = await _trySessionFromApi();
    if (_cached != null) {
      await _storage.write('last_email', _cached!.email);
    }
    return _cached;
  }

  Future<UserSession?> _trySessionFromApi() async {
    try {
      return await _api.getSession();
    } catch (_) {
      return null;
    }
  }

  Future<void> signOutPlaceholder() async {
    _cached = null;
    await _storage.delete('last_email');
  }

  Future<void> sendMagicLinkPlaceholder(String email) async {
    throw NotImplementedNativeException(
      'Magic link sign-in (use web or wire /api/auth/send-code)',
    );
  }
}
