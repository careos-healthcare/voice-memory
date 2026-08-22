import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'health_dto.g.dart';

/// Wire response for `GET /api/health` (deep readiness).
@JsonSerializable(createFactory: false)
class HealthCheckResponseDto {
  const HealthCheckResponseDto({
    required this.status,
    this.checks,
  });

  factory HealthCheckResponseDto.fromJson(Map<String, dynamic> json) =>
      HealthCheckResponseDto(
        status: JsonConverters.string(json['status'], field: 'status'),
        checks: JsonConverters.nullableObject(
          json['checks'],
          HealthChecksDto.fromJson,
        ),
      );

  final String status;
  final HealthChecksDto? checks;

  Map<String, dynamic> toJson() => _$HealthCheckResponseDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class HealthChecksDto {
  const HealthChecksDto({
    this.databaseConfigured,
    this.databaseReachable,
    this.migrationsOk,
    this.rateLimiterMode,
    this.globalRateLimiterMode,
    this.stripeConfigured,
    this.emailMode,
    this.productionEnvOk,
  });

  factory HealthChecksDto.fromJson(Map<String, dynamic> json) =>
      HealthChecksDto(
        databaseConfigured:
            JsonConverters.nullableBool(json['databaseConfigured']),
        databaseReachable:
            JsonConverters.nullableBool(json['databaseReachable']),
        migrationsOk: JsonConverters.nullableBool(json['migrationsOk']),
        rateLimiterMode: JsonConverters.nullableString(json['rateLimiterMode']),
        globalRateLimiterMode:
            JsonConverters.nullableString(json['globalRateLimiterMode']),
        stripeConfigured: JsonConverters.nullableBool(json['stripeConfigured']),
        emailMode: JsonConverters.nullableString(json['emailMode']),
        productionEnvOk: JsonConverters.nullableBool(json['productionEnvOk']),
      );

  final bool? databaseConfigured;
  final bool? databaseReachable;
  final bool? migrationsOk;
  final String? rateLimiterMode;
  final String? globalRateLimiterMode;
  final bool? stripeConfigured;
  final String? emailMode;
  final bool? productionEnvOk;

  Map<String, dynamic> toJson() => _$HealthChecksDtoToJson(this);
}

/// Wire response for `GET /api/healthz` (shallow liveness).
@JsonSerializable(createFactory: false)
class HealthzResponseDto {
  const HealthzResponseDto({
    required this.status,
    this.live,
  });

  factory HealthzResponseDto.fromJson(Map<String, dynamic> json) =>
      HealthzResponseDto(
        status: JsonConverters.string(json['status'], field: 'status'),
        live: JsonConverters.nullableBool(json['live']),
      );

  final String status;
  final bool? live;

  Map<String, dynamic> toJson() => _$HealthzResponseDtoToJson(this);
}
