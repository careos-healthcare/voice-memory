import 'package:archiveme_mobile/api/models/account_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_account_api.g.dart';

@RestApi()
abstract class VoiceMemoryAccountApi {
  factory VoiceMemoryAccountApi(Dio dio, {String baseUrl}) =
      _VoiceMemoryAccountApi;

  @POST('/api/account/delete')
  Future<AccountDeleteResponseDto> deleteAccount(
    @Body() Map<String, dynamic> body,
  );
}