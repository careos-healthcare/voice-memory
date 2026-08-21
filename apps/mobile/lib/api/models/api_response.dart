import 'package:archiveme_mobile/api/models/api_error_dto.dart';
import 'package:archiveme_mobile/core/json/json_converters.dart';

/// Standard wire envelope: `{ ok, error?, data? }` with legacy flat-payload support.
class ApiResponse<T> {
  const ApiResponse({
    required this.ok,
    this.error,
    this.data,
  });

  final bool ok;
  final ApiErrorDto? error;
  final T? data;

  bool get isSuccess => ok && error == null;

  /// Parses [json] into an envelope, lifting nested [data] or treating the root
  /// object as the payload when no `data` key is present (auth/billing today).
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) parseData,
  ) {
    final error = parseApiError(json);
    final ok = JsonConverters.nullableBool(json['ok']) ?? error == null;
    if (error != null) {
      return ApiResponse<T>(ok: false, error: error, data: null);
    }
    return ApiResponse<T>(
      ok: ok,
      error: null,
      data: parseData(extractDataMap(json)),
    );
  }

  Map<String, dynamic> toJson(Object? Function(T value) toJsonData) => {
    'ok': ok,
    if (error != null) 'error': error!.toJson(),
    if (data != null) 'data': toJsonData(data as T),
  };
}

/// Empty success envelope for endpoints that only return `{ ok: true }`.
class ApiOkResponse {
  const ApiOkResponse({required this.ok, this.error});

  factory ApiOkResponse.fromJson(Map<String, dynamic> json) {
    final error = parseApiError(json);
    return ApiOkResponse(
      ok: JsonConverters.nullableBool(json['ok']) ?? error == null,
      error: error,
    );
  }

  final bool ok;
  final ApiErrorDto? error;

  bool get isSuccess => ok && error == null;

  Map<String, dynamic> toJson() => {
    'ok': ok,
    if (error != null) 'error': error!.toJson(),
  };
}

ApiErrorDto? parseApiError(Map<String, dynamic> json) {
  final raw = json['error'];
  if (raw == null) {
    return null;
  }
  if (raw is Map<String, dynamic>) {
    return ApiErrorDto.fromJson(raw);
  }
  if (raw is Map) {
    return ApiErrorDto.fromJson(Map<String, dynamic>.from(raw));
  }
  if (raw is String && raw.isNotEmpty) {
    final code = json['code'];
    final codeRaw = JsonConverters.nullableString(code);
    return ApiErrorDto(
      code: codeRaw ?? 'UNKNOWN',
      message: raw,
    );
  }
  return null;
}

Map<String, dynamic> extractDataMap(Map<String, dynamic> json) {
  final nested = json['data'];
  if (nested is Map<String, dynamic>) {
    return nested;
  }
  if (nested is Map) {
    return Map<String, dynamic>.from(nested);
  }
  return json;
}
