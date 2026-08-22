import 'dart:async';

import 'package:archiveme_mobile/core/execution/execution.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LlmExecutionStrategy', () {
    test('maps timeout to fallback when configured', () async {
      final strategy = LlmExecutionStrategy(
        defaultInferenceTimeout: const Duration(milliseconds: 20),
      );

      final result = await strategy.runInference(
        operationLabel: 'slow_inference',
        action: () async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return 'done';
        },
        fallbackValue: 'fallback',
      );

      expect(result.isSuccess, isTrue);
      final success = result as ExecutionSuccess<String>;
      expect(success.value, 'fallback');
      expect(success.degraded, isTrue);
    });

    test('returns cancelled when token is cancelled', () async {
      final token = ExecutionCancelToken()..cancel();
      final strategy = LlmExecutionStrategy();

      final result = await strategy.runInference(
        operationLabel: 'cancelled',
        cancelToken: token,
        action: () async => 'value',
      );

      expect(result.isCancelled, isTrue);
    });

    test('maps model missing errors to user-facing failure', () {
      final failure = mapErrorToLlmFailure(
        StateError('GEMMA_MODEL_NOT_INSTALLED'),
      );
      expect(failure, isA<LlmFailureModelMissing>());
      expect(failure.userMessage, contains('not installed'));
    });
  });

  group('SyncExecutionStrategy', () {
    test('maps offline API failure to SyncFailureOffline', () {
      final failure = mapApiFailureToSyncFailure(const ApiFailureOffline());
      expect(failure, isA<SyncFailureOffline>());
      expect(failure.isRetryable, isTrue);
      expect(failure.code, 'SYNC_OFFLINE');
    });
  });

  group('ExecutionStrategy', () {
    test('retries when policy allows', () async {
      const strategy = _TestRetryStrategy();
      var attempts = 0;

      final result = await strategy.execute(
        operationLabel: 'retry_me',
        action: () async {
          attempts++;
          if (attempts < 2) {
            throw StateError('transient');
          }
          return 42;
        },
        policy: ExecutionPolicy(
          maxAttempts: 3,
          initialRetryDelay: Duration.zero,
          shouldRetry: (failure, attempt) => failure.isRetryable,
        ),
        mapFailure: (_, __) => const SyncFailureRuntime(detail: 'transient'),
      );

      expect(result.isSuccess, isTrue);
      expect((result as ExecutionSuccess<int>).value, 42);
      expect(attempts, 2);
    });
  });
}

final class _TestRetryStrategy extends ExecutionStrategy {
  const _TestRetryStrategy();
}
