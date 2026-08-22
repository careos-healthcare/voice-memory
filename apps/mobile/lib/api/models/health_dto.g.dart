// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$HealthCheckResponseDtoToJson(
  HealthCheckResponseDto instance,
) => <String, dynamic>{'status': instance.status, 'checks': instance.checks};

Map<String, dynamic> _$HealthChecksDtoToJson(HealthChecksDto instance) =>
    <String, dynamic>{
      'databaseConfigured': instance.databaseConfigured,
      'databaseReachable': instance.databaseReachable,
      'migrationsOk': instance.migrationsOk,
      'rateLimiterMode': instance.rateLimiterMode,
      'globalRateLimiterMode': instance.globalRateLimiterMode,
      'stripeConfigured': instance.stripeConfigured,
      'emailMode': instance.emailMode,
      'productionEnvOk': instance.productionEnvOk,
    };

Map<String, dynamic> _$HealthzResponseDtoToJson(HealthzResponseDto instance) =>
    <String, dynamic>{'status': instance.status, 'live': instance.live};
