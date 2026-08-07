import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/account_auth.dart';
import '../../../core/di/network_providers.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../models/session.dart';
import '../../../services/activation_funnel_analytics.dart';
import 'auth_session_state.dart';

/// Immutable auth session boundary — mirrors [RecordingService] Riverpod patterns.
class AuthSessionNotifier extends Notifier<AuthSessionState> {
  @override
  AuthSessionState build() => const AuthSessionState();

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> Function()? onSignedIn;
  Future<void> Function()? onSignedOut;

  UserSession? get currentSession => state.session;

  Future<void> loadPersistedSession() async {
    state = state.copyWith(phase: AuthPhase.loading, clearLastFailure: true);
    final result = await _repository.hydrateFromStoredCookie();
    result.when(
      success: (session) {
        state = AuthSessionState(
          session: session,
          phase: session == null ? AuthPhase.signedOut : AuthPhase.signedIn,
        );
      },
      onFailure: (failure) {
        _logFailure('loadPersistedSession', failure);
        state = const AuthSessionState(
          phase: AuthPhase.signedOut,
        ).copyWith(lastFailure: failure);
      },
    );
  }

  Future<UserSession?> refreshSession() async {
    state = state.copyWith(phase: AuthPhase.loading, clearLastFailure: true);
    final result = await _repository.refreshSession();
    return result.when(
      success: (session) {
        state = AuthSessionState(
          session: session,
          phase: session == null ? AuthPhase.signedOut : AuthPhase.signedIn,
        );
        return session;
      },
      onFailure: (failure) {
        _logFailure('refreshSession', failure);
        state = const AuthSessionState(
          phase: AuthPhase.signedOut,
        ).copyWith(lastFailure: failure);
        return null;
      },
    );
  }

  Future<void> sendAuthCode(String email) async {
    state = state.copyWith(phase: AuthPhase.loading, clearLastFailure: true);
    final result = await _repository.sendAuthCode(email);
    result.when(
      success: (_) {
        state = state.copyWith(
          phase: state.session == null ? AuthPhase.signedOut : AuthPhase.signedIn,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          phase: state.session == null ? AuthPhase.signedOut : AuthPhase.signedIn,
          lastFailure: failure,
        );
        throw failure.toApiException();
      },
    );
  }

  Future<UserSession> verifyAuthCode({
    required String email,
    required String code,
  }) async {
    state = state.copyWith(phase: AuthPhase.loading, clearLastFailure: true);
    final result = await _repository.verifyAuthCode(email: email, code: code);
    return result.when(
      success: (session) async {
        state = AuthSessionState(session: session, phase: AuthPhase.signedIn);
        await onSignedIn?.call();
        return session;
      },
      onFailure: (failure) {
        state = state.copyWith(
          phase: AuthPhase.signedOut,
          clearSession: true,
          lastFailure: failure,
        );
        throw failure.toApiException();
      },
    );
  }

  Future<void> signOut() async {
    ref.read(networkRequestScopeProvider).cancelAll();
    state = state.copyWith(phase: AuthPhase.loading, clearLastFailure: true);
    final result = await _repository.signOut();
    final serverFailed = result.isFailure;
    if (serverFailed) {
      _logFailure('signOut', result.failureOrNull!);
    }
    state = AuthSessionState(
      phase: AuthPhase.signedOut,
      lastFailure: result.failureOrNull,
      signOutServerFailed: serverFailed,
    );
    await onSignedOut?.call();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.accountSignout,
      method: AccountAuth.method,
    );
  }

  Future<String?> lastEmail() => _repository.lastEmail();

  void _logFailure(String operation, ApiFailure failure) {
    debugPrint('Auth: $operation failed — ${failure.code}: ${failure.message}');
  }
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthSessionState>(
      AuthSessionNotifier.new,
    );

final authSessionNotifierProvider = Provider<AuthSessionNotifier>(
  (ref) => ref.read(authSessionProvider.notifier),
);

final currentUserSessionProvider = Provider<UserSession?>(
  (ref) => ref.watch(authSessionProvider).session,
);

final authPhaseProvider = Provider<AuthPhase>(
  (ref) => ref.watch(authSessionProvider).phase,
);
