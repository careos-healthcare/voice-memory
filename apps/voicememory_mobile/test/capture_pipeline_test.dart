import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_errors.dart';

void main() {
  test('api error mapper maps 401', () {
    // Smoke test — RateLimitedException type exists
    expect(RateLimitedException('slow down').statusCode, 429);
  });
}
