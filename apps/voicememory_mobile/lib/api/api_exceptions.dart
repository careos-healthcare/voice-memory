class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

class AuthRequiredException extends ApiException {
  AuthRequiredException([super.message = 'Sign in required.'])
      : super(statusCode: 401, code: 'AUTH_REQUIRED');
}

class NotImplementedNativeException extends ApiException {
  NotImplementedNativeException(String feature)
      : super('$feature is not implemented in the native app yet.');
}
