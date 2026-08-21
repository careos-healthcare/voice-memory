import 'package:archiveme_mobile/api/adapters/api_envelope_adapter.dart';
import 'package:archiveme_mobile/api/models/api_error_dto.dart';
import 'package:archiveme_mobile/api/models/api_response.dart';
import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/models/session.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_dto.g.dart';

@JsonSerializable(createFactory: false)
class AuthUserDto {
  const AuthUserDto({required this.id, required this.email});

  factory AuthUserDto.fromJson(Map<String, dynamic> json) => AuthUserDto(
        id: JsonConverters.string(json['id'], field: 'id'),
        email: JsonConverters.string(json['email'], field: 'email'),
      );

  final String id;
  final String email;

  Map<String, dynamic> toJson() => _$AuthUserDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class AuthSessionDto {
  const AuthSessionDto({required this.user, this.signedInAt});

  factory AuthSessionDto.fromJson(Map<String, dynamic> json) => AuthSessionDto(
        user: JsonConverters.requiredObject(
          json['user'],
          AuthUserDto.fromJson,
          field: 'user',
        ),
        signedInAt: JsonConverters.nullableString(json['signedInAt']),
      );

  final AuthUserDto user;
  final String? signedInAt;

  Map<String, dynamic> toJson() => _$AuthSessionDtoToJson(this);

  UserSession toDomain() => UserSession(
        userId: user.id,
        email: user.email,
        signedInAt:
            signedInAt == null ? null : DateTime.tryParse(signedInAt!)?.toUtc(),
      );
}

/// Payload for `POST /api/auth/verify`.
@JsonSerializable(createFactory: false)
class AuthVerifyDataDto {
  const AuthVerifyDataDto({required this.session});

  factory AuthVerifyDataDto.fromJson(Map<String, dynamic> json) =>
      AuthVerifyDataDto(
        session: JsonConverters.requiredObject(
          json['session'],
          AuthSessionDto.fromJson,
          field: 'session',
        ),
      );

  final AuthSessionDto session;

  Map<String, dynamic> toJson() => _$AuthVerifyDataDtoToJson(this);
}

/// Payload for `GET /api/auth/session`.
@JsonSerializable(createFactory: false)
class AuthSessionDataDto {
  const AuthSessionDataDto({this.session});

  factory AuthSessionDataDto.fromJson(Map<String, dynamic> json) =>
      AuthSessionDataDto(
        session: JsonConverters.nullableObject(
          json['session'],
          AuthSessionDto.fromJson,
        ),
      );

  final AuthSessionDto? session;

  Map<String, dynamic> toJson() => _$AuthSessionDataDtoToJson(this);

  UserSession? toDomain() => session?.toDomain();
}

/// Retrofit envelope for `POST /api/auth/verify`.
class AuthVerifyApiResponse {
  const AuthVerifyApiResponse(this.envelope);

  final ApiResponse<AuthVerifyDataDto> envelope;

  bool get ok => envelope.ok;
  ApiErrorDto? get error => envelope.error;
  AuthVerifyDataDto? get data => envelope.data;
  AuthSessionDto? get session => envelope.data?.session;

  factory AuthVerifyApiResponse.fromJson(Map<String, dynamic> json) =>
      AuthVerifyApiResponse(
        ApiResponse.fromJson(json, AuthVerifyDataDto.fromJson),
      );

  UserSession? toDomain() => envelope.data?.session.toDomain();

  ApiResult<UserSession> toSessionResult({
    String missingDataMessage = 'No session in response',
    int? statusCode,
  }) {
    return envelope.toDomainResult(
      map: (data) => data.session.toDomain(),
      missingDataMessage: missingDataMessage,
      statusCode: statusCode,
    );
  }
}

/// Retrofit envelope for `GET /api/auth/session`.
class AuthSessionApiResponse {
  const AuthSessionApiResponse(this.envelope);

  final ApiResponse<AuthSessionDataDto> envelope;

  bool get ok => envelope.ok;
  ApiErrorDto? get error => envelope.error;
  AuthSessionDataDto? get data => envelope.data;
  AuthSessionDto? get session => envelope.data?.session;

  factory AuthSessionApiResponse.fromJson(Map<String, dynamic> json) =>
      AuthSessionApiResponse(
        ApiResponse.fromJson(json, AuthSessionDataDto.fromJson),
      );

  UserSession? toDomain() => envelope.data?.toDomain();

  ApiResult<UserSession?> toSessionResult({int? statusCode}) {
    return envelope.toNullableDomainResult(
      map: (data) => data.toDomain(),
      statusCode: statusCode,
    );
  }
}

// Legacy aliases — prefer *DataDto / *ApiResponse in new code.
typedef AuthVerifyResponseDto = AuthVerifyDataDto;
typedef AuthSessionResponseDto = AuthSessionDataDto;
