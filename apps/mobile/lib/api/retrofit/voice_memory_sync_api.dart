import 'package:archiveme_mobile/api/models/sync_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_sync_api.g.dart';

@RestApi()
abstract class VoiceMemorySyncApi {
  factory VoiceMemorySyncApi(Dio dio, {String baseUrl}) = _VoiceMemorySyncApi;

  @GET('/api/sync/manifest')
  Future<SyncManifestResponseDto> syncManifest();

  @GET('/api/sync/pull')
  Future<SyncPullResponseDto> syncPull();

  @GET('/api/sync/changes')
  Future<SyncChangesResponseDto> syncChanges(@Query('since') int since);

  @POST('/api/sync/push')
  Future<SyncPushResponseDto> syncPush(@Body() SyncPushRequestDto body);

  @GET('/api/journal')
  Future<dynamic> listJournal({
    @Query('limit') int? limit,
    @Query('cursor') String? cursor,
  });
}