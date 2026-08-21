import 'package:archiveme_mobile/features/auth/application/auth_session_notifier.dart';
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show AppServices;
import 'package:archiveme_mobile/models/session.dart';
import 'package:archiveme_mobile/services/app_services.dart' show AppServices;
import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../models/session.dart' show UserSession;

/// Facade over [AuthSessionNotifier] — preserves the legacy [AppServices.auth] surface.
class AuthService {
  AuthService(this._notifier);

  final AuthSessionNotifier _notifier;

  Future<void> Function()? get onSignedIn => _notifier.onSignedIn;
  set onSignedIn(Future<void> Function()? callback) =>
      _notifier.onSignedIn = callback;

  Future<void> Function()? get onSignedOut => _notifier.onSignedOut;
  set onSignedOut(Future<void> Function()? callback) =>
      _notifier.onSignedOut = callback;

  UserSession? get currentSession => _notifier.currentSession;

  Future<void> loadPersistedSession() => _notifier.loadPersistedSession();

  Future<UserSession?> refreshSession() => _notifier.refreshSession();

  Future<void> sendAuthCode(String email) => _notifier.sendAuthCode(email);

  Future<UserSession> verifyAuthCode({
    required String email,
    required String code,
  }) => _notifier.verifyAuthCode(email: email, code: code);

  Future<void> signOut() => _notifier.signOut();

  Future<String?> lastEmail() => _notifier.lastEmail();
}

/// Test helper — builds an [AuthService] backed by an overridden repository.
AuthService createAuthServiceForTest({required ProviderContainer container}) {
  return AuthService(container.read(authSessionProvider.notifier));
}