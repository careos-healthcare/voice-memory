import 'package:archiveme_mobile/core/execution/execution_failure.dart';
import 'package:archiveme_mobile/core/execution/execution_result.dart';
import 'package:archiveme_mobile/core/execution/execution_strategy.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/sync/sync_backoff_policy.dart';

/// How a server push was reconciled against local state.
enum SyncConflictResolution {
  /// Server accepted or already had an equivalent blob — treat as success.
  acknowledged,

  /// Transient failure — schedule another attempt.
  retry,

  /// Non-retryable terminal failure.
  failed,
}

/// Resilience wrapper for offline sync, outbox drains, and background phases.
final class SyncExecutionStrategy extends ExecutionStrategy {
  SyncExecutionStrategy({
    SyncBackoffPolicy backoff = const SyncBackoffPolicy(),
    this.requestTimeout = const Duration(seconds: 30),
  }) : _backoff = backoff;

  static final SyncExecutionStrategy shared = SyncExecutionStrategy();

  final SyncBackoffPolicy _backoff;
  final Duration requestTimeout;

  bool isRetryableFailure(ApiFailure failure) =>
      failure.code == 'OFFLINE' ||
      failure.code == 'NETWORK_ERROR' ||
      failure.code == 'NETWORK_DISCONNECTED' ||
      failure.code == 'TIMEOUT';

  bool isRetryableExecutionFailure(ExecutionFailureState failure) =>
      failure.isRetryable;

  /// Runs [action] with sync-appropriate timeout and optional backoff retries.
  Future<ExecutionResult<T>> runSyncOperation<T>({
    required String operationLabel,
    required Future<T> Function() action,
    bool Function(ExecutionFailureState failure)? shouldRetry,
    int? maxAttempts,
  }) {
    final attempts = maxAttempts ?? _backoff.maxAttempts;
    return execute(
      operationLabel: operationLabel,
      action: action,
      mapFailure: mapErrorToSyncFailure,
      policy: ExecutionPolicy(
        timeout: requestTimeout,
        maxAttempts: attempts,
        initialRetryDelay: _backoff.initialDelay,
        retryDelayMultiplier: _backoff.multiplier,
        maxRetryDelay: _backoff.maxDelay,
        shouldRetry: (failure, attempt) {
          if (!failure.isRetryable) return false;
          if (shouldRetry != null && !shouldRetry(failure)) return false;
          return attempt < attempts;
        },
      ),
    );
  }

  /// Retries a sync API push using [SyncBackoffPolicy] semantics.
  Future<ExecutionResult<T>> pushWithRetry<T>({
    required Future<ApiResult<T>> Function() push,
    bool Function(ApiFailure failure)? shouldRetry,
  }) async {
    final retryable = shouldRetry ?? isRetryableFailure;
    ApiFailure? lastFailure;

    for (var attempt = 1; attempt <= _backoff.maxAttempts; attempt++) {
      final result = await push();
      switch (result) {
        case ApiSuccess(:final value):
          return ExecutionSuccess(value);
        case ApiFailureResult(:final failure):
          lastFailure = failure;
          if (!retryable(failure) || attempt >= _backoff.maxAttempts) {
            return ExecutionFailureResult(mapApiFailureToSyncFailure(failure));
          }
          await Future<void>.delayed(_backoff.delayForAttempt(attempt));
      }
    }

    return ExecutionFailureResult(
      SyncFailureExhausted(
        attempts: _backoff.maxAttempts,
        detail: lastFailure?.message,
      ),
    );
  }

  /// Runs a background sync phase, mapping failures without aborting the flush.
  Future<ExecutionResult<T>> runPhase<T>({
    required String phaseLabel,
    required Future<T> Function() action,
  }) {
    return runSyncOperation(
      operationLabel: phaseLabel,
      action: action,
      maxAttempts: 1,
    );
  }
}
