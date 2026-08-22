import 'package:archiveme_mobile/api/models/insights_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_insights_api.g.dart';

@RestApi()
abstract class VoiceMemoryInsightsApi {
  factory VoiceMemoryInsightsApi(Dio dio, {String baseUrl}) =
      _VoiceMemoryInsightsApi;

  @POST('/api/insights/evidence')
  Future<EvidenceInsightResponseDto> generateEvidence(
    @Body() Map<String, dynamic> body,
  );

  @POST('/api/insights/corrections')
  Future<InsightCorrectionResponseDto> submitCorrection(
    @Body() Map<String, dynamic> body,
  );

  @GET('/api/insights/weekly-story')
  Future<WeeklyStoryResponseDto> weeklyStory();

  @GET('/api/insights/comparison')
  Future<ComparisonResponseDto> comparison();
}