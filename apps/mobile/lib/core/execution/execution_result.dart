import 'package:archiveme_mobile/core/execution/execution_failure.dart';

/// Outcome of an [ExecutionStrategy] run.
sealed class ExecutionResult<T> {
  const ExecutionResult();

  bool get isSuccess => this is ExecutionSuccess<T>;
  bool get isFailure => this is ExecutionFailureResult<T>;
  bool get isDeferred => this is ExecutionDeferred<T>;
  bool get isCancelled => this is ExecutionCancelled<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(ExecutionFailureState failure) onFailure,
    required R Function(ExecutionFailureState reason) onDeferred,
    required R Function() onCancelled,
  }) {
    return switch (this) {
      ExecutionSuccess(:final value) => success(value),
      ExecutionFailureResult(:final failure) => onFailure(failure),
      ExecutionDeferred(:final reason) => onDeferred(reason),
      ExecutionCancelled() => onCancelled(),
    };
  }

  T? get valueOrNull => switch (this) {
        ExecutionSuccess(:final value) => value,
        _ => null,
      };

  ExecutionFailureState? get failureOrNull => switch (this) {
        ExecutionFailureResult(:final failure) => failure,
        ExecutionDeferred(:final reason) => reason,
        _ => null,
      };
}

final class ExecutionSuccess<T> extends ExecutionResult<T> {
  const ExecutionSuccess(this.value, {this.degraded = false});

  final T value;

  /// True when a configured fallback was returned instead of a full result.
  final bool degraded;
}

final class ExecutionFailureResult<T> extends ExecutionResult<T> {
  const ExecutionFailureResult(this.failure);

  final ExecutionFailureState failure;
}

final class ExecutionDeferred<T> extends ExecutionResult<T> {
  const ExecutionDeferred(this.reason);

  final ExecutionFailureState reason;
}

final class ExecutionCancelled<T> extends ExecutionResult<T> {
  const ExecutionCancelled();
}
