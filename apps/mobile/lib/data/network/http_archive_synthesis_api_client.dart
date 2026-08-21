import 'package:archiveme_mobile/api/models/archive_synthesis_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/data/network/archive_synthesis_api_client.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_models.dart';

class HttpArchiveSynthesisApiClient implements ArchiveSynthesisApiClient {
  HttpArchiveSynthesisApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<ArchiveSynthesisApiResponse?>> postArchiveSynthesis({
    required ArchiveSynthesisType synthesisType,
    required String monthKey,
    required String userId,
    required Map<String, dynamic> pack,
    int? milestoneThreshold,
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri(VoiceMemoryApiRoutes.archiveSynthesis.path) == null) {
      return const ApiSuccess(null);
    }

    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.archiveSynthesis.path,
      body: {
        'synthesisType': synthesisType.apiValue,
        'monthKey': monthKey,
        'userId': userId,
        'pack': pack,
        'milestoneThreshold': ?milestoneThreshold,
      },
      cancelToken: cancelToken,
    );

    return responseResult.when(
      success: (response) {
        if (response.statusCode == 403) {
          return const ApiSuccess(null);
        }
        if (response.statusCode == 401) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }

        return _transport.decodeEnvelope<
          ArchiveSynthesisResponseDto,
          ArchiveSynthesisApiResponse?
        >(
          response,
          parseData: ArchiveSynthesisResponseDto.fromJson,
          toDomain: (dto) => _mapResponse(dto, synthesisType),
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  ArchiveSynthesisApiResponse? _mapResponse(
    ArchiveSynthesisResponseDto dto,
    ArchiveSynthesisType fallbackType,
  ) {
    final type = dto.synthesisType ?? fallbackType.apiValue;
    final reviewJson = dto.review;
    if (reviewJson == null) return null;

    return ArchiveSynthesisApiResponse(
      synthesisType: type,
      cached: dto.cached == true,
      monthlyReview: type == 'monthly'
          ? ArchiveMonthlyReview.fromJson(reviewJson)
          : null,
      milestoneReview: type == 'milestone'
          ? ArchiveMilestoneReview.fromJson(reviewJson)
          : null,
      deepDiveNarrative: type == 'deep_dive'
          ? ArchiveDeepDiveNarrative.fromJson(reviewJson)
          : null,
      historianReport: type == 'historian'
          ? ArchiveHistorianReport.fromJson(reviewJson)
          : null,
    );
  }
}
