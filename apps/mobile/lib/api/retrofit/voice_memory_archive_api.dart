import 'package:archiveme_mobile/api/models/archive_synthesis_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_archive_api.g.dart';

@RestApi()
abstract class VoiceMemoryArchiveApi {
  factory VoiceMemoryArchiveApi(Dio dio, {String baseUrl}) =
      _VoiceMemoryArchiveApi;

  @POST('/api/archive-synthesis')
  Future<ArchiveSynthesisResponseDto> synthesize(
    @Body() Map<String, dynamic> body,
  );
}
