import 'package:archiveme_mobile/api/models/push_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_push_api.g.dart';

@RestApi()
abstract class VoiceMemoryPushApi {
  factory VoiceMemoryPushApi(Dio dio, {String baseUrl}) = _VoiceMemoryPushApi;

  @POST('/api/push/register')
  Future<PushRegisterResponseDto> registerDevice(
    @Body() Map<String, dynamic> body,
  );

  @POST('/api/internal/send-test-push')
  Future<SendTestPushResponseDto> sendTestPush(
    @Body() Map<String, dynamic> body, {
    @Header('x-vm-debug-token') String? debugToken,
  });
}
