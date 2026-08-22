import 'package:archiveme_mobile/api/models/relationships_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_relationships_api.g.dart';

@RestApi()
abstract class VoiceMemoryRelationshipsApi {
  factory VoiceMemoryRelationshipsApi(Dio dio, {String baseUrl}) =
      _VoiceMemoryRelationshipsApi;

  @GET('/api/user-relationships')
  Future<UserRelationshipsListResponseDto> listRelationships();

  @POST('/api/user-relationships')
  Future<UserRelationshipResponseDto> upsertRelationship(
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/user-relationships/{id}')
  Future<UserRelationshipResponseDto> updateConsentStatus(
    @Path('id') String relationshipId,
    @Body() Map<String, dynamic> body,
  );
}