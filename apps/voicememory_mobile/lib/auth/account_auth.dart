import '../api/api_exceptions.dart';

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
    if (error is NetworkOfflineException || error is ConnectivityException) {
      return 'offline';
    }
    if (error is RequestTimeoutException) return 'timeout';
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
    return 'unknown';
  }
}
