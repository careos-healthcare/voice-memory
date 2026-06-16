import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/security/api_usage_guard.dart';

void main() {
  setUp(ApiUsageGuard.resetForTest);

  test('blocks repeated attempts beyond per-scope cap', () {
    final guard = ApiUsageGuard(maxAttemptsPerScope: 2);
    ApiUsageGuard.resetForTest(replacement: guard);

    const scope = 'entry:test-1';
    expect(
      guard.checkAttempt(
        scopeKey: scope,
        operation: ApiUsageOperation.analyze,
      ).allowed,
      isTrue,
    );
    guard.recordAttempt(
      scopeKey: scope,
      operation: ApiUsageOperation.analyze,
      success: false,
    );
    guard.recordAttempt(
      scopeKey: scope,
      operation: ApiUsageOperation.analyze,
      success: false,
    );

    final blocked = guard.checkAttempt(
      scopeKey: scope,
      operation: ApiUsageOperation.analyze,
    );
    expect(blocked.allowed, isFalse);
    expect(blocked.reason, contains('Max'));
  });

  test('enforces cooldown between retry attempts', () {
    final guard = ApiUsageGuard(
      maxAttemptsPerScope: 5,
      cooldownBetweenRetries: const Duration(hours: 1),
      baseBackoff: Duration.zero,
    );
    ApiUsageGuard.resetForTest(replacement: guard);

    const scope = 'audio:/tmp/a.m4a:12';
    guard.recordAttempt(
      scopeKey: scope,
      operation: ApiUsageOperation.transcribe,
      success: false,
    );

    final blocked = guard.checkAttempt(
      scopeKey: scope,
      operation: ApiUsageOperation.transcribe,
    );
    expect(blocked.allowed, isFalse);
    expect(blocked.retryAfter, isNotNull);
  });

  test('exponential backoff grows with attempt count', () {
    final guard = ApiUsageGuard();
    expect(guard.exponentialBackoffDelay(0), Duration.zero);
    expect(
      guard.exponentialBackoffDelay(3).inMilliseconds,
      greaterThan(guard.exponentialBackoffDelay(1).inMilliseconds),
    );
  });

  test('idempotency key is stable per scope and operation', () {
    final guard = ApiUsageGuard();
    final a = guard.idempotencyKey(
      scopeKey: 'entry:1',
      operation: ApiUsageOperation.analyze,
    );
    final b = guard.idempotencyKey(
      scopeKey: 'entry:1',
      operation: ApiUsageOperation.analyze,
    );
    expect(a, b);
    expect(a.length, lessThanOrEqualTo(24));
  });

  test('daily cap blocks expensive operations', () {
    final guard = ApiUsageGuard(
      maxAttemptsPerScope: 100,
      dailyExpensiveOperationCap: 2,
      cooldownBetweenRetries: Duration.zero,
      baseBackoff: Duration.zero,
    );
    ApiUsageGuard.resetForTest(replacement: guard);

    guard.recordAttempt(
      scopeKey: 'a',
      operation: ApiUsageOperation.transcribe,
      success: true,
    );
    guard.recordAttempt(
      scopeKey: 'b',
      operation: ApiUsageOperation.analyze,
      success: true,
    );

    final blocked = guard.checkAttempt(
      scopeKey: 'c',
      operation: ApiUsageOperation.analyze,
    );
    expect(blocked.allowed, isFalse);
    expect(blocked.reason, contains('Daily API cap'));
  });
}
