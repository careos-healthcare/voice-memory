import 'package:archiveme_mobile/api/models/api_response.dart';
import 'package:archiveme_mobile/api/models/auth_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_auth_api.g.dart';

/// Retrofit client for `/api/auth/*` — see `packages/api_contract/openapi.yaml`.
@RestApi()
abstract class VoiceMemoryAuthApi {
  factory VoiceMemoryAuthApi(Dio dio, {String baseUrl}) = _VoiceMemoryAuthApi;

  @POST('/api/auth/send-code')
  Future<ApiOkResponse> sendCode(@Body() Map<String, dynamic> body);

  @POST('/api/auth/verify')
  Future<AuthVerifyApiResponse> verify(@Body() Map<String, dynamic> body);

  @GET('/api/auth/session')
  Future<AuthSessionApiResponse> getSession();

  @POST('/api/auth/signout')
  Future<ApiOkResponse> signOut();
}