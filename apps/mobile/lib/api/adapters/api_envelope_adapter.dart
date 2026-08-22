import 'package:archiveme_mobile/api/dio/retrofit_api_executor.dart';
import 'package:archiveme_mobile/api/models/api_response.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';

/// Generic adapter that parses wire JSON into [ApiResponse] payloads and maps
/// them to application/domain types via [ApiResult].
///
/// Network clients (Retrofit/Dio and [HttpTransport]) should route successful
/// JSON bodies through this adapter instead of reading `ok` / `error` / `data`
/// fields directly.
abstract final class ApiEnvelopeAdapter {
  ApiEnvelopeAdapter._();

  /// Parses a wire JSON object into a typed [ApiResponse] envelope.
  static ApiResponse<TData> parse<TData>(
    Map<String, dynamic> json,
    TData Function(Map<String, dynamic> json) parseData,
  ) {
    return ApiResponse.fromJson(json, parseData);
  }

  /// Maps a parsed envelope to a domain value.
  static ApiResult<TDomain> toResult<TData, TDomain>({
    required ApiResponse<TData> envelope,
    required TDomain Function(TData data) toDomain,
    String missingDataMessage = 'Response payload missing',
    int? statusCode,
  }) {
    final failure = RetrofitApiExecutor.failureFromEnvelope(
      ok: envelope.ok,
      error: envelope.error,
      statusCode: statusCode,
    );
    if (failure != null) {
      return ApiFailureResult(failure);
    }
    final data = envelope.data;
    if (data == null) {
      return ApiFailureResult(
        ApiFailureInvalidResponse(
          message: missingDataMessage,
          responseCode: statusCode,
        ),
      );
    }
    try {
      return ApiSuccess(toDomain(data));
    } on Object catch (error) {
      return ApiFailureResult(ApiFailureMapper.fromException(error));
    }
  }

  /// Maps a parsed envelope to a nullable domain value.
  static ApiResult<TDomain?> toNullableResult<TData, TDomain>({
    required ApiResponse<TData> envelope,
    required TDomain? Function(TData data) toDomain,
    int? statusCode,
  }) {
    final failure = RetrofitApiExecutor.failureFromEnvelope(
      ok: envelope.ok,
      error: envelope.error,
      statusCode: statusCode,
    );
    if (failure != null) {
      if (failure is ApiFailureAuthRequired) {
        return const ApiSuccess(null);
      }
      return ApiFailureResult(failure);
    }
    final data = envelope.data;
    if (data == null) {
      return const ApiSuccess(null);
    }
    try {
      return ApiSuccess(toDomain(data));
    } on Object catch (error) {
      return ApiFailureResult(ApiFailureMapper.fromException(error));
    }
  }

  /// Maps an envelope with no payload (`{ ok: true }`).
  static ApiResult<void> toVoidResult({
    required ApiResponse<dynamic> envelope,
    int? statusCode,
  }) {
    return RetrofitApiExecutor.requireOk(
      ok: envelope.ok,
      error: envelope.error,
      statusCode: statusCode,
    );
  }

  /// Parses JSON and maps directly to a domain [ApiResult].
  static ApiResult<TDomain> mapJson<TData, TDomain>({
    required Map<String, dynamic> json,
    required TData Function(Map<String, dynamic> json) parseData,
    required TDomain Function(TData data) toDomain,
    String missingDataMessage = 'Response payload missing',
    int? statusCode,
  }) {
    return toResult(
      envelope: parse(json, parseData),
      toDomain: toDomain,
      missingDataMessage: missingDataMessage,
      statusCode: statusCode,
    );
  }

  /// Parses JSON and maps to a nullable domain [ApiResult].
  static ApiResult<TDomain?> mapNullableJson<TData, TDomain>({
    required Map<String, dynamic> json,
    required TData Function(Map<String, dynamic> json) parseData,
    required TDomain? Function(TData data) toDomain,
    int? statusCode,
  }) {
    return toNullableResult(
      envelope: parse(json, parseData),
      toDomain: toDomain,
      statusCode: statusCode,
    );
  }

  /// Parses JSON for endpoints that only return `{ ok: true }`.
  static ApiResult<void> mapJsonOk({
    required Map<String, dynamic> json,
    int? statusCode,
  }) {
    final okResponse = ApiOkResponse.fromJson(json);
    return toVoidResult(
      envelope: ApiResponse<void>(ok: okResponse.ok, error: okResponse.error),
      statusCode: statusCode,
    );
  }
}

/// Convenience mapping for void-only Retrofit responses.
extension ApiOkResponseMapping on ApiOkResponse {
  ApiResult<void> toVoidDomainResult({int? statusCode}) {
    return ApiEnvelopeAdapter.toVoidResult(
      envelope: ApiResponse<void>(ok: ok, error: error),
      statusCode: statusCode,
    );
  }
}

/// Convenience mapping for Retrofit/Dio envelope wrapper types.
extension ApiResponseEnvelopeMapping<TData> on ApiResponse<TData> {
  ApiResult<TDomain> toDomainResult<TDomain>({
    required TDomain Function(TData data) map,
    String missingDataMessage = 'Response payload missing',
    int? statusCode,
  }) {
    return ApiEnvelopeAdapter.toResult(
      envelope: this,
      toDomain: map,
      missingDataMessage: missingDataMessage,
      statusCode: statusCode,
    );
  }

  ApiResult<TDomain?> toNullableDomainResult<TDomain>({
    required TDomain? Function(TData data) map,
    int? statusCode,
  }) {
    return ApiEnvelopeAdapter.toNullableResult(
      envelope: this,
      toDomain: map,
      statusCode: statusCode,
    );
  }

  ApiResult<void> toVoidDomainResult({int? statusCode}) {
    return ApiEnvelopeAdapter.toVoidResult(
      envelope: this,
      statusCode: statusCode,
    );
  }
}
