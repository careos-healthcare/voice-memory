import '../core/errors/domain_exception.dart';

class ApiException extends DomainException {
  ApiException(super.userMessage, {this.statusCode, this.code, super.cause})
    : super(userFacingCode: code ?? 'API_ERROR');

  String get message => userMessage;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class AuthRequiredException extends ApiException {
  AuthRequiredException([super.userMessage = 'Sign in required.'])
    : super(statusCode: 401, code: 'AUTH_REQUIRED');
}

class RemoteDisclosureRequiredException extends ApiException {
  RemoteDisclosureRequiredException()
    : super(
        'Review the online transcription disclosure before uploading audio.',
        statusCode: 428,
        code: 'remoteDisclosureRequired',
      );
}

class NativeFeatureUnavailableException extends ApiException {
  NativeFeatureUnavailableException(String feature, {super.cause})
    : super(
        '$feature is not available in the native app yet.',
        code: 'NATIVE_FEATURE_UNAVAILABLE',
      );
}

class NotImplementedNativeException extends ApiException {
  NotImplementedNativeException(String feature, {super.cause})
    : super(
        '$feature is not implemented in the native app yet.',
        code: 'NATIVE_FEATURE_UNAVAILABLE',
      );
}

class BillingUnavailableException extends ApiException {
  BillingUnavailableException({super.cause})
    : super(
        'Billing is not available right now.',
        statusCode: 503,
        code: 'BILLING_DISABLED',
      );
}

class NetworkOfflineException extends ApiException {
  NetworkOfflineException([String? detail, Object? cause])
    : super(
        detail ?? 'You appear to be offline. Your moment is saved locally.',
        code: 'OFFLINE',
        cause: cause,
      );
}

class ConnectivityException extends ApiException {
  ConnectivityException({super.cause})
    : super(
        'Could not reach the server. Check your connection and try again.',
        code: 'CONNECTIVITY',
      );
}

class RequestTimeoutException extends ApiException {
  RequestTimeoutException({super.cause})
    : super(
        'The request timed out. Please try again.',
        code: 'REQUEST_TIMEOUT',
      );
}

class PayloadTooLargeException extends ApiException {
  PayloadTooLargeException({super.cause})
    : super(
        'This file is too large. Try a shorter recording.',
        statusCode: 413,
        code: 'PAYLOAD_TOO_LARGE',
      );
}

class NoSpeechException extends ApiException {
  NoSpeechException({super.cause})
    : super(
        'No speech detected. Try speaking a little longer.',
        statusCode: 422,
        code: 'NO_SPEECH',
      );
}

class RateLimitedException extends ApiException {
  RateLimitedException(super.userMessage, {String? code, super.cause})
    : super(statusCode: 429, code: code ?? 'RATE_LIMIT');
}

class ServiceUnavailableException extends ApiException {
  ServiceUnavailableException({super.cause})
    : super(
        'Service is temporarily unavailable.',
        statusCode: 503,
        code: 'SERVICE_UNAVAILABLE',
      );
}

/// Thrown when a physical device has no API base URL dart-define.
class BackendNotConfiguredException extends ApiException {
  BackendNotConfiguredException({super.cause})
    : super(
        BackendNotConfiguredException.defaultUserMessage,
        code: 'BACKEND_NOT_CONFIGURED',
      );

  static const defaultUserMessage =
      'Cloud features are unavailable because a backend connection has not been configured.';
}

/// Keeps [FormatException] compatibility for response-safety callers while
/// exposing only calm copy to UI code.
class InvalidApiResponseException extends FormatException
    implements UserFacingException {
  InvalidApiResponseException(super.message, {required this.cause});

  @override
  final Object cause;

  @override
  String get userMessage => 'Service is temporarily unavailable.';

  @override
  String get userFacingCode => 'INVALID_API_RESPONSE';
}
