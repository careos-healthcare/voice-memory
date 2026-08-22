import 'package:archiveme_mobile/api/api_errors.dart';
import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('maps 401 to AuthRequiredException', () {
    final ex = ApiErrorMapper.fromResponse(
      http.Response(
        '{"error":"Sign in required","code":"CAPTURE_AUTH_REQUIRED"}',
        401,
      ),
    );
    expect(ex, isA<AuthRequiredException>());
    expect(ex.statusCode, 401);
  });

  test('maps 429 to RateLimitedException', () {
    final ex = ApiErrorMapper.fromResponse(
      http.Response(
        '{"error":"Too many requests","code":"RATE_LIMIT_MINUTE"}',
        429,
      ),
    );
    expect(ex, isA<RateLimitedException>());
  });

  test('maps 413 to payload too large', () {
    final ex = ApiErrorMapper.fromResponse(
      http.Response('{"error":"Too big","code":"PAYLOAD_TOO_LARGE"}', 413),
    );
    expect(ex.statusCode, 413);
    expect(ex.code, 'PAYLOAD_TOO_LARGE');
  });
}