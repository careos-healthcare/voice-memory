import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/domain/retry_policy.dart';

void main() {
  group('RetryPolicy', () {
    test('calculateDelay returns zero for non-positive attempt numbers', () {
      const policy = RetryPolicy();

      expect(policy.calculateDelay(0), Duration.zero);
      expect(policy.calculateDelay(-1), Duration.zero);
    });

    test('calculateDelay stays within capped exponential ceiling', () {
      const policy = RetryPolicy(
        initialDelay: Duration(seconds: 2),
        maxDelay: Duration(seconds: 10),
        backoffFactor: 2.0,
      );

      for (var attempt = 1; attempt <= 4; attempt++) {
        final ceilingMs = min(2000 * pow(2.0, attempt - 1), 10000.0);
        for (var i = 0; i < 20; i++) {
          final delayMs = policy.calculateDelay(attempt).inMilliseconds;
          expect(delayMs, greaterThanOrEqualTo(0));
          expect(delayMs, lessThanOrEqualTo(ceilingMs));
        }
      }
    });

    test('calculateDelay respects maxDelay cap', () {
      const policy = RetryPolicy(
        initialDelay: Duration(seconds: 2),
        maxDelay: Duration(seconds: 3),
        backoffFactor: 2.0,
      );

      for (var i = 0; i < 20; i++) {
        expect(
          policy.calculateDelay(5).inMilliseconds,
          lessThanOrEqualTo(3000),
        );
      }
    });

    test('shouldRetry stops at maxAttempts', () {
      const policy = RetryPolicy(maxAttempts: 3);

      expect(policy.shouldRetry(0), isTrue);
      expect(policy.shouldRetry(2), isTrue);
      expect(policy.shouldRetry(3), isFalse);
    });
  });
}
