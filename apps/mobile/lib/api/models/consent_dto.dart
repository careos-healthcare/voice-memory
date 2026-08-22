import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'consent_dto.g.dart';

/// Wire response for `POST /api/coach/consent/issue`.
@JsonSerializable(createFactory: false)
class ConsentIssueResponseDto {
  const ConsentIssueResponseDto({
    required this.token,
    this.ok,
  });

  factory ConsentIssueResponseDto.fromJson(Map<String, dynamic> json) =>
      ConsentIssueResponseDto(
        ok: JsonConverters.nullableBool(json['ok']),
        token: JsonConverters.requiredStringMap(json['token'], field: 'token'),
      );

  final bool? ok;
  final Map<String, dynamic> token;

  Map<String, dynamic> toJson() => _$ConsentIssueResponseDtoToJson(this);
}

/// Wire response for `POST /api/coach/consent/verify`.
@JsonSerializable(createFactory: false)
class ConsentVerifyResponseDto {
  const ConsentVerifyResponseDto({
    required this.valid,
    this.reason,
    this.session,
  });

  factory ConsentVerifyResponseDto.fromJson(Map<String, dynamic> json) =>
      ConsentVerifyResponseDto(
        valid: JsonConverters.boolValue(json['valid'], field: 'valid'),
        reason: JsonConverters.nullableString(json['reason']),
        session: JsonConverters.nullableStringMap(json['session']),
      );

  final bool valid;
  final String? reason;
  final Map<String, dynamic>? session;

  Map<String, dynamic> toJson() => _$ConsentVerifyResponseDtoToJson(this);
}
