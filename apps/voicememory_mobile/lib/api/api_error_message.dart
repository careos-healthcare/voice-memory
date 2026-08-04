import '../core/errors/domain_exception.dart';
import 'api_exceptions.dart';

/// Shown when cloud/API features need a configured backend URL.
const String cloudBackendUnavailableMessage =
    'Cloud features are unavailable because a backend connection has not been configured.';

/// Maps errors to calm, user-facing copy — never stack traces or ApiException(...) formatting.
String userFacingErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is BackendNotConfiguredException) {
    return cloudBackendUnavailableMessage;
  }
  if (error is ApiException) {
    if (error.code == 'BACKEND_NOT_CONFIGURED') {
      return cloudBackendUnavailableMessage;
    }
    if (error.runtimeType != ApiException) {
      return _nonEmptyOrFallback(error.userMessage, fallback);
    }
    return _messageForLegacyApiException(error, fallback);
  }
  if (error is UserFacingException) {
    return _nonEmptyOrFallback(error.userMessage, fallback);
  }
  if (error is String) {
    final msg = error.trim();
    return _isSafeLegacyMessage(msg) ? msg : fallback;
  }
  return fallback;
}

/// Legacy alias — prefer [userFacingErrorMessage] in UI.
String formatApiErrorMessage(Object error) => userFacingErrorMessage(error);

String _nonEmptyOrFallback(String message, String fallback) {
  final trimmed = message.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

bool _isSafeLegacyMessage(String text) {
  if (text.isEmpty || text.length > 160) return false;
  final lower = text.toLowerCase();
  if (lower.contains('exception') ||
      lower.contains('stacktrace') ||
      lower.contains('localhost') ||
      lower.contains('127.0.0.1') ||
      lower.contains('revenuecat')) {
    return false;
  }
  if (RegExp(r'\b\d{3}\b').hasMatch(text) && lower.contains('request failed')) {
    return false;
  }
  return true;
}

String _messageForLegacyApiException(ApiException error, String fallback) {
  switch (error.statusCode) {
    case 401:
      return error.message.trim().isEmpty
          ? 'Sign in to continue.'
          : error.message;
    case 413:
      return 'This file is too large. Try a shorter recording.';
    case 422:
      return 'No speech detected. Try speaking a little longer.';
    case 429:
      return 'Too many requests. Please wait a moment.';
    case 503:
      return 'Service is temporarily unavailable.';
    default:
      return fallback;
  }
}
