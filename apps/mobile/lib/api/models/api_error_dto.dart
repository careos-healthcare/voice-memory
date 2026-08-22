import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'api_error_dto.g.dart';

/// Standard API error object (`error.code`, `error.message`, …).
@JsonSerializable(createFactory: false)
class ApiErrorDto {
  const ApiErrorDto({
    required this.code,
    required this.message,
    this.retryable = false,
    this.requestId,
  });

  factory ApiErrorDto.fromJson(Map<String, dynamic> json) => ApiErrorDto(
        code: JsonConverters.string(json['code'], field: 'code'),
        message: JsonConverters.string(json['message'], field: 'message'),
        retryable: JsonConverters.boolOrFalse(json['retryable']),
        requestId: JsonConverters.nullableString(json['requestId']),
      );

  final String code;
  final String message;
  final bool retryable;
  final String? requestId;

  Map<String, dynamic> toJson() => _$ApiErrorDtoToJson(this);
}
