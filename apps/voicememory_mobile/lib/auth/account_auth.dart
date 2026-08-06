import 'dart:async';
import 'dart:io';

import '../api/api_exceptions.dart';

/// Account flow copy. ArchiveMe's existing auth provider is the backend
/// email + one-time sign-in code flow (passwordless) — so there are no
/// password fields, nothing password-shaped to store, and "forgot
/// password" is replaced by resending a fresh code. Calm, factual lines:
/// the account prepares restore/access; it does not claim full cloud sync.
abstract class AccountAuthCopy {
  AccountAuthCopy._();

  // Create account.
  static const String createTitle = 'Create your ArchiveMe account';
  static const String createBody =
      'Use this to restore access and keep your archive connected later.';
  static const String createCta = 'Create account';

  // Sign in.
  static const String signInTitle = 'Sign in to ArchiveMe';
  static const String signInCta = 'Sign in';

  // Shared fields and code step (the provider emails a one-time code —
  // resending a code is also the account-recovery path).
  static const String emailLabel = 'Email';
  static const String codeTitle = 'Check your email';
  static const String codeBody = 'Enter the sign-in code we just sent you.';
  static const String codeLabel = 'Code';
  static const String codeCta = 'Continue';
  static const String resendCode = 'Resend code';
  static const String codeSent = 'Code sent — check your email.';

  // Local-only use stays available; an account is never required to record.
  static const String continueWithoutAccount = 'Continue without an account';

  static const String privacyLine =
      'Your archive stays private. We do not include your recordings in analytics.';

  // Errors — useful, never technical internals.
  static const String invalidEmail = 'Enter a valid email address.';
  static const String invalidCode = 'Enter the code from your email.';

  // Sign out.
  static const String signOut = 'Sign out';
  static const String signOutKeepsArchive =
      'Signing out keeps your recordings on this device.';

  /// Shown on account surfaces — local use first; account optional until value.
  static const String accountTimingNote =
      'You can use ArchiveMe locally without an account. Create one when you '
      'want to restore access or connect Pro later.';
}

/// Pure helpers for the account flow: validation and the mapping from
/// thrown errors to stable, non-sensitive analytics ids. No emails,
/// codes, or messages ever leave this mapping — only fixed ids.
abstract class AccountAuth {
  AccountAuth._();

  /// The stable method id for the existing provider.
  static const String method = 'email_code';

  static final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isValidEmail(String email) => _emailShape.hasMatch(email.trim());

  /// A stable, non-sensitive id for an auth error — never the message,
  /// email, or any user input.
  static String errorTypeFor(Object error) {
    if (error is BackendNotConfiguredException) return 'backend_not_configured';
    if (error is NetworkOfflineException) return 'offline';
    if (error is ApiException) {
      if (error.code == 'BACKEND_NOT_CONFIGURED') {
        return 'backend_not_configured';
      }
      final status = error.statusCode ?? 0;
      if (status == 401) return 'invalid_code';
      if (status == 429) return 'rate_limited';
      if (status >= 500) return 'server_error';
      return 'request_failed';
    }
    if (error is SocketException) return 'network';
    if (error is TimeoutException) return 'timeout';
    return 'unknown';
  }
}
