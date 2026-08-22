import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/models/session.dart';
import 'package:flutter/foundation.dart';

enum AuthPhase { unknown, loading, signedIn, signedOut }

@immutable
class AuthSessionState {
  const AuthSessionState({
    this.session,
    this.phase = AuthPhase.unknown,
    this.lastFailure,
    this.signOutServerFailed = false,
  });

  final UserSession? session;
  final AuthPhase phase;
  final ApiFailure? lastFailure;

  /// True when local sign-out succeeded but the server call failed.
  final bool signOutServerFailed;

  bool get isSignedIn => session != null;

  AuthSessionState copyWith({
    UserSession? session,
    bool clearSession = false,
    AuthPhase? phase,
    ApiFailure? lastFailure,
    bool clearLastFailure = false,
    bool? signOutServerFailed,
  }) {
    return AuthSessionState(
      session: clearSession ? null : (session ?? this.session),
      phase: phase ?? this.phase,
      lastFailure: clearLastFailure ? null : (lastFailure ?? this.lastFailure),
      signOutServerFailed: signOutServerFailed ?? this.signOutServerFailed,
    );
  }
}