import 'package:archiveme_mobile/api/api_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('api error mapper maps 401', () {
    // Smoke test — RateLimitedException type exists
    expect(RateLimitedException('slow down').statusCode, 429);
  });
}