import 'package:archiveme_mobile/core/network/api_failure.dart';

/// Success or typed API failure — repositories return this instead of throwing.
sealed class ApiResult<T> {
  const ApiResult();

  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailureResult<T>;

  T? get valueOrNull => switch (this) {
    ApiSuccess<T>(:final value) => value,
    ApiFailureResult<T>() => null,
  };

  ApiFailure? get failureOrNull => switch (this) {
    ApiSuccess<T>() => null,
    ApiFailureResult<T>(:final failure) => failure,
  };

  R when<R>({
    required R Function(T value) success,
    required R Function(ApiFailure failure) onFailure,
  }) => switch (this) {
    ApiSuccess<T>(:final value) => success(value),
    ApiFailureResult<T>(:final failure) => onFailure(failure),
  };
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.value);

  final T value;
}

final class ApiFailureResult<T> extends ApiResult<T> {
  const ApiFailureResult(this.failure);

  final ApiFailure failure;
}