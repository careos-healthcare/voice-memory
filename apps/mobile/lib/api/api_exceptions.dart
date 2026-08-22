class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class AuthRequiredException extends ApiException {
  AuthRequiredException([super.message = 'Sign in required.'])
    : super(statusCode: 401, code: 'AUTH_REQUIRED');
}

class NotImplementedNativeException extends ApiException {
  NotImplementedNativeException(String feature)
    : super('$feature is not implemented in the native app yet.');
}

class BillingUnavailableException extends ApiException {
  BillingUnavailableException()
    : super(
        'Billing is not available right now.',
        statusCode: 503,
        code: 'BILLING_DISABLED',
      );
}

class NetworkOfflineException extends ApiException {
  NetworkOfflineException([String? detail])
    : super(
        detail ?? 'You appear to be offline. Your reflection is saved locally.',
        code: 'OFFLINE',
      );
}

/// Thrown when a physical device has no API base URL dart-define.
class BackendNotConfiguredException extends ApiException {
  BackendNotConfiguredException()
    : super(
        BackendNotConfiguredException.userMessage,
        code: 'BACKEND_NOT_CONFIGURED',
      );

  static const userMessage =
      'Cloud features are unavailable because a backend connection has not been configured.';
}