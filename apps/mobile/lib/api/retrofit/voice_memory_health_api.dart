import 'package:archiveme_mobile/api/models/health_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_health_api.g.dart';

@RestApi()
abstract class VoiceMemoryHealthApi {
  factory VoiceMemoryHealthApi(Dio dio, {String baseUrl}) = _VoiceMemoryHealthApi;

  @GET('/api/health')
  Future<HealthCheckResponseDto> health();

  @GET('/api/healthz')
  Future<HealthzResponseDto> healthz();
}
