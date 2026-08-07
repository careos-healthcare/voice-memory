import '../../api/api_error_copy.dart';
import '../../api/api_error_message.dart';
import '../../api/api_exceptions.dart';
import '../../api/api_errors.dart';

/// Typed, immutable API failure — normalized at the transport boundary.
sealed class ApiFailure implements Exception {
  const ApiFailure();

  String get code;
  int? get statusCode;
  String get message;

  String toUserMessage({String fallback = ApiErrorCopy.genericFallback}) =>
      userFacingErrorMessage(toApiException(), fallback: fallback);

  ApiException toApiException();
}

final class ApiFailureOffline extends ApiFailure {
  const ApiFailureOffline([this.detail]);

  final String? detail;

  @override
  String get code => 'OFFLINE';

  @override
  int? get statusCode => null;

  @override
  String get message =>
      detail ?? 'You appear to be offline. Your reflection is saved locally.';

  @override
  ApiException toApiException() => NetworkOfflineException(message);
}

final class ApiFailureBackendNotConfigured extends ApiFailure {
  const ApiFailureBackendNotConfigured();

  @override
  String get code => 'BACKEND_NOT_CONFIGURED';

  @override
  int? get statusCode => null;

  @override
  String get message => BackendNotConfiguredException.userMessage;

  @override
  ApiException toApiException() => BackendNotConfiguredException();
}

final class ApiFailureAuthRequired extends ApiFailure {
  const ApiFailureAuthRequired([this.detail]);

  final String? detail;

  @override
  String get code => 'AUTH_REQUIRED';

  @override
  int? get statusCode => 401;

  @override
  String get message => detail ?? 'Sign in required.';

  @override
  ApiException toApiException() => AuthRequiredException(message);
}

final class ApiFailureRateLimited extends ApiFailure {
  const ApiFailureRateLimited({required this.message, this.serverCode});

  @override
  final String message;

  final String? serverCode;

  @override
  String get code => serverCode ?? 'RATE_LIMIT';

  @override
  int? get statusCode => 429;

  @override
  ApiException toApiException() =>
      RateLimitedException(message, code: serverCode);
}

final class ApiFailureBillingUnavailable extends ApiFailure {
  const ApiFailureBillingUnavailable();

  @override
  String get code => 'BILLING_DISABLED';

  @override
  int? get statusCode => 503;

  @override
  String get message => 'Billing is not available right now.';

  @override
  ApiException toApiException() => BillingUnavailableException();
}

final class ApiFailureInvalidResponse extends ApiFailure {
  const ApiFailureInvalidResponse({
    required this.message,
    this.responseCode,
    this.serverCode,
  });

  @override
  final String message;

  final int? responseCode;
  final String? serverCode;

  @override
  String get code => serverCode ?? 'INVALID_RESPONSE';

  @override
  int? get statusCode => responseCode;

  @override
  ApiException toApiException() =>
      ApiException(message, statusCode: responseCode, code: serverCode);
}

final class ApiFailureServer extends ApiFailure {
  const ApiFailureServer({
    required this.message,
    required this.statusCode,
    this.serverCode,
  });

  @override
  final String message;

  @override
  final int statusCode;

  final String? serverCode;

  @override
  String get code => serverCode ?? 'HTTP_$statusCode';

  @override
  ApiException toApiException() =>
      ApiException(message, statusCode: statusCode, code: serverCode);
}

final class ApiFailureUnknown extends ApiFailure {
  const ApiFailureUnknown(this.cause);

  final Object cause;

  @override
  String get code => 'UNKNOWN';

  @override
  int? get statusCode => null;

  @override
  String get message => cause.toString();

  @override
  ApiException toApiException() => ApiException(message, code: code);
}

final class ApiFailureCancelled extends ApiFailure {
  const ApiFailureCancelled();

  @override
  String get code => 'CANCELLED';

  @override
  int? get statusCode => null;

  @override
  String get message => 'Request was cancelled.';

  @override
  ApiException toApiException() => ApiException(message, code: code);
}
