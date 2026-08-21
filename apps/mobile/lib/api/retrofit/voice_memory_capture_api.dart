import 'dart:io';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_capture_api.g.dart';

@RestApi()
abstract class VoiceMemoryCaptureApi {
  factory VoiceMemoryCaptureApi(Dio dio, {String baseUrl}) =
      _VoiceMemoryCaptureApi;

  @POST('/api/capture/attest')
  Future<CaptureAttestResponseDto> attest(@Body() Map<String, dynamic> body);

  @POST('/api/analyze')
  Future<AnalyzeResponseDto> analyze(
    @Body() Map<String, dynamic> body, {
    @Header('x-vm-capture-token') required String captureToken,
    @Header('x-vm-idempotency-key') String? idempotencyKey,
  });

  @POST('/api/transcribe')
  @MultiPart()
  Future<TranscribeResponseDto> transcribe({
    @Part(name: 'durationSeconds') required String durationSeconds,
    @Part(name: 'audio') required File audio,
    @Header('x-vm-capture-token') required String captureToken,
    @Header('x-vm-idempotency-key') String? idempotencyKey,
  });
}