import 'dart:async';

import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/core/execution/execution_failure.dart';
import 'package:archiveme_mobile/core/execution/execution_result.dart';

/// Retry, timeout, and cancellation policy for a single execution attempt.
class ExecutionPolicy {
  const ExecutionPolicy({
    this.timeout,
    this.cancelToken,
    this.maxAttempts = 1,
    this.initialRetryDelay = Duration.zero,
    this.retryDelayMultiplier = 2,
    this.maxRetryDelay = const Duration(seconds: 8),
    this.shouldRetry,
  });

  final Duration? timeout;
  final ExecutionCancelToken? cancelToken;
  final int maxAttempts;
  final Duration initialRetryDelay;
  final int retryDelayMultiplier;
  final Duration maxRetryDelay;

  /// When null, failures are not retried.
  final bool Function(ExecutionFailureState failure, int attempt)? shouldRetry;

  Duration retryDelayForAttempt(int attempt) {
    if (attempt <= 1) return initialRetryDelay;
    final scaledMs = initialRetryDelay.inMilliseconds *
        _pow(retryDelayMultiplier, attempt - 1);
    final cappedMs = scaledMs > maxRetryDelay.inMilliseconds
        ? maxRetryDelay.inMilliseconds
        : scaledMs;
    return Duration(milliseconds: cappedMs);
  }

  static int _pow(int base, int exponent) {
    var value = 1;
    for (var i = 0; i < exponent; i++) {
      value *= base;
    }
    return value;
  }
}

/// Reusable execution wrapper: timeout, cancellation, retry, and error mapping.
abstract class ExecutionStrategy {
  const ExecutionStrategy();

  Future<ExecutionResult<T>> execute<T>({
    required String operationLabel,
    required Future<T> Function() action,
    ExecutionPolicy policy = const ExecutionPolicy(),
    T? fallbackValue,
    ExecutionFailureState Function(Object error, StackTrace stack)? mapFailure,
  }) async {
    final mapper = mapFailure ?? _defaultMapFailure;
    final maxAttempts = policy.maxAttempts.clamp(1, 32);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      policy.cancelToken?.throwIfCancelled();

      try {
        Future<T> run = action();
        final timeout = policy.timeout;
        if (timeout != null) {
          run = run.timeout(timeout);
        }
        final value = await run;
        return ExecutionSuccess(value);
      } on ExecutionCancelledException {
        return const ExecutionCancelled();
      } on TimeoutException {
        if (fallbackValue != null) {
          return ExecutionSuccess(fallbackValue, degraded: true);
        }
        final failure = mapper(
          TimeoutException('Timeout during $operationLabel'),
          StackTrace.current,
        );
        if (_shouldRetry(policy, failure, attempt, maxAttempts)) {
          await Future<void>.delayed(policy.retryDelayForAttempt(attempt));
          continue;
        }
        return ExecutionFailureResult(failure);
      } on Object catch (error, stack) {
        final failure = mapper(error, stack);
        if (_shouldRetry(policy, failure, attempt, maxAttempts)) {
          await Future<void>.delayed(policy.retryDelayForAttempt(attempt));
          continue;
        }
        return ExecutionFailureResult(failure);
      }
    }

    return ExecutionFailureResult(
      SyncFailureExhausted(attempts: maxAttempts),
    );
  }

  bool _shouldRetry(
    ExecutionPolicy policy,
    ExecutionFailureState failure,
    int attempt,
    int maxAttempts,
  ) {
    if (attempt >= maxAttempts || !failure.isRetryable) return false;
    final predicate = policy.shouldRetry;
    if (predicate == null) return false;
    return predicate(failure, attempt);
  }

  ExecutionFailureState _defaultMapFailure(Object error, StackTrace stack) {
    return SyncFailureRuntime(detail: '$error');
  }
}
