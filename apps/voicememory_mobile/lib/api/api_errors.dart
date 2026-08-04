import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exceptions.dart';

export 'api_exceptions.dart' show RateLimitedException;

class ApiErrorMapper {
  static ApiException fromResponse(http.Response response) {
    String message = 'Request failed (${response.statusCode})';
    String? code;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['error'] as String? ?? message;
      code = body['code'] as String?;
    } catch (_) {}

    switch (response.statusCode) {
      case 401:
        return AuthRequiredException();
      case 413:
        return PayloadTooLargeException();
      case 429:
        return RateLimitedException(
          'Too many requests. Please wait a moment.',
          code: code,
        );
      case 503:
        if (code == 'BILLING_DISABLED') {
          return BillingUnavailableException();
        }
        return ServiceUnavailableException();
      case 422:
        if (code == null ||
            code == 'NO_SPEECH' ||
            code == 'NO_SPEECH_DETECTED') {
          return NoSpeechException();
        }
        return ApiException(
          message,
          statusCode: response.statusCode,
          code: code,
        );
      default:
        return ApiException(
          message,
          statusCode: response.statusCode,
          code: code,
        );
    }
  }
}
