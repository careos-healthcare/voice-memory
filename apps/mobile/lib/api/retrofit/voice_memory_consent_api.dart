import 'package:archiveme_mobile/api/models/consent_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_consent_api.g.dart';

@RestApi()
abstract class VoiceMemoryConsentApi {
  factory VoiceMemoryConsentApi(Dio dio, {String baseUrl}) =
      _VoiceMemoryConsentApi;

  @POST('/api/coach/consent/issue')
  Future<ConsentIssueResponseDto> issueToken(@Body() Map<String, dynamic> body);

  @POST('/api/coach/consent/verify')
  Future<ConsentVerifyResponseDto> verifyToken(
    @Body() Map<String, dynamic> body,
  );
}
