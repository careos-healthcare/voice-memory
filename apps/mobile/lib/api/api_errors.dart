import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:http/http.dart' as http;

class ApiErrorMapper {
  /// Delegates to [ApiFailureMapper] — single source of truth for HTTP errors.
  static ApiException fromResponse(http.Response response) {
    return ApiFailureMapper.fromResponse(response).toApiException();
  }
}

class RateLimitedException extends ApiException {
  RateLimitedException(super.message, {String? code})
    : super(statusCode: 429, code: code ?? 'RATE_LIMIT');
}