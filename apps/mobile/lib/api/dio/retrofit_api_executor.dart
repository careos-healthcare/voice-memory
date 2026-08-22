import 'package:archiveme_mobile/api/adapters/api_envelope_adapter.dart';
import 'package:archiveme_mobile/api/models/api_error_dto.dart';
import 'package:archiveme_mobile/api/models/api_response.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/features/vision/offline_image_embedding_guard.dart';
import 'package:dio/dio.dart';

/// Maps Retrofit/Dio calls and [ApiResponse] envelopes to [ApiResult].
abstract final class RetrofitApiExecutor {
  RetrofitApiExecutor._();

  static bool get isBackendConfigured =>
      AppConfig.isBackendConfigured && AppConfig.apiBaseUrl.isNotEmpty;

  static ApiResult<T>? cancelGuard<T>(NetworkCancelToken? token) {
    if (token?.isCancelled ?? false) {
      return const ApiFailureResult(ApiFailureCancelled());
    }
    return null;
  }

  static Future<ApiResult<T>> run<T>(
    Future<T> Function() call, {
    NetworkCancelToken? cancelToken,
  }) async {
    final cancelled = cancelGuard<T>(cancelToken);
    if (cancelled != null) {
      return cancelled;
    }
    try {
      OfflineImageEmbeddingGuard.assertOfflineBlocked(
        operation: 'retrofit_api',
      );
      final value = await call();
      if (cancelToken?.isCancelled ?? false) {
        return const ApiFailureResult(ApiFailureCancelled());
      }
      return ApiSuccess(value);
    } on DioException catch (error, stackTrace) {
      return ApiFailureResult(mapDioException(error));
    } on ApiFailure catch (failure, stackTrace) {
      return ApiFailureResult(failure);
    } on Object catch (error, stackTrace) {
      return ApiFailureResult(ApiFailureMapper.fromException(error));
    }
  }

  static ApiFailure mapDioException(DioException error) {
    final response = error.response;
    final data = response?.data;
    if (data is Map) {
      final body = Map<String, dynamic>.from(data);
      final envelopeError = parseApiError(body);
      if (envelopeError != null) {
        return failureFromErrorDto(
          envelopeError,
          statusCode: response?.statusCode,
        );
      }
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiFailureOffline();
    }
    if (error.type == DioExceptionType.connectionError) {
      return ApiFailureOffline(error.message);
    }
    return ApiFailureMapper.fromException(error);
  }

  static ApiFailure failureFromErrorDto(
    ApiErrorDto error, {
    int? statusCode,
  }) {
    switch (error.code) {
      case 'AUTH_REQUIRED':
        return ApiFailureAuthRequired(error.message);
      case 'AUTH_RATE_LIMITED':
      case 'RATE_LIMITED':
        return ApiFailureRateLimited(
          message: error.message,
          serverCode: error.code,
        );
      case 'BILLING_DISABLED':
        return const ApiFailureBillingUnavailable();
      default:
        break;
    }
    if (statusCode == 401) {
      return ApiFailureAuthRequired(error.message);
    }
    if (statusCode == 429) {
      return ApiFailureRateLimited(
        message: error.message,
        serverCode: error.code,
      );
    }
    if (statusCode == 503 && error.code == 'BILLING_DISABLED') {
      return const ApiFailureBillingUnavailable();
    }
    return ApiFailureServer(
      message: error.message,
      statusCode: statusCode ?? 400,
      serverCode: error.code,
    );
  }

  static ApiFailure? failureFromEnvelope({
    required bool ok,
    ApiErrorDto? error,
    int? statusCode,
  }) {
    if (error != null) {
      return failureFromErrorDto(error, statusCode: statusCode);
    }
    if (!ok) {
      return ApiFailureInvalidResponse(
        message: 'Request failed',
        responseCode: statusCode,
      );
    }
    return null;
  }

  static ApiResult<T> requireSuccess<T>({
    required bool ok,
    ApiErrorDto? error,
    required T? data,
    int? statusCode,
    required String missingDataMessage,
  }) {
    return ApiEnvelopeAdapter.toResult<Object?, T>(
      envelope: ApiResponse<Object?>(ok: ok, error: error, data: data),
      toDomain: (value) => value as T,
      missingDataMessage: missingDataMessage,
      statusCode: statusCode,
    );
  }

  static ApiResult<void> requireOk({
    required bool ok,
    ApiErrorDto? error,
    int? statusCode,
  }) {
    return ApiEnvelopeAdapter.toVoidResult(
      envelope: ApiResponse<void>(ok: ok, error: error),
      statusCode: statusCode,
    );
  }
}