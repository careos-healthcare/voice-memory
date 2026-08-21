import 'dart:io';

import 'package:archiveme_mobile/api/models/live_audio_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_live_audio_api.g.dart';

@RestApi()
abstract class VoiceMemoryLiveAudioApi {
  factory VoiceMemoryLiveAudioApi(Dio dio, {String baseUrl}) =
      _VoiceMemoryLiveAudioApi;

  @POST('/api/live-audio/session')
  Future<LiveAudioSessionResponseDto> mintSession({
    @Header('x-vm-capture-token') required String captureToken,
    @Header('x-vm-idempotency-key') String? idempotencyKey,
    @Body() Map<String, dynamic> body = const {},
  });

  @POST('/api/live-audio/recover')
  @MultiPart()
  Future<LiveAudioRecoverResponseDto> recoverVault({
    @Part(name: 'session_id') required String sessionId,
    @Part(name: 'vault') required File vault,
    @Header('Authorization') required String authorization,
    @Header('x-vm-capture-token') required String captureToken,
    @Header('x-vm-idempotency-key') required String idempotencyKey,
    @Part(name: 'recovery_secret') String? recoverySecret,
  });
}
