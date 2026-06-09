import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exceptions.dart';

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
        return AuthRequiredException(message);
      case 413:
        return ApiException(
          message,
          statusCode: 413,
          code: code ?? 'PAYLOAD_TOO_LARGE',
        );
      case 429:
        return RateLimitedException(message, code: code);
      case 503:
        if (code == 'BILLING_DISABLED') {
          return BillingUnavailableException();
        }
        return ApiException(message, statusCode: 503, code: code);
      case 422:
        return ApiException(message, statusCode: 422, code: code ?? 'NO_SPEECH');
      default:
        return ApiException(
          message,
          statusCode: response.statusCode,
          code: code,
        );
    }
  }
}

class RateLimitedException extends ApiException {
  RateLimitedException(super.message, {String? code})
      : super(statusCode: 429, code: code ?? 'RATE_LIMIT');
}

