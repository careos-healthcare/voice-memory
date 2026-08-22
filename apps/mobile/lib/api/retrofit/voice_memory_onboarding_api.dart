import 'dart:io';

import 'package:archiveme_mobile/api/models/onboarding_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_onboarding_api.g.dart';

@RestApi()
abstract class VoiceMemoryOnboardingApi {
  factory VoiceMemoryOnboardingApi(Dio dio, {String baseUrl}) =
      _VoiceMemoryOnboardingApi;

  @POST('/api/onboarding/brain-dump')
  @MultiPart()
  Future<BrainDumpResponseDto> uploadBrainDump({
    @Part(name: 'entryId') required String entryId,
    @Part(name: 'durationSeconds') required String durationSeconds,
    @Part(name: 'encryptedAudio') required File encryptedAudio,
  });
}
