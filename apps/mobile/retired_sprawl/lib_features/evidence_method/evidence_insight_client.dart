import 'package:archiveme_mobile/api/models/insights_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/features/evidence_method/evidence_insight.dart';

class EvidenceInsightClient {
  EvidenceInsightClient(this._transport);

  final HttpTransport _transport;

  Future<EvidenceInsight> generateEvidenceBackedInsight({
    required String transcript,
    required String entryId,
    String? activeLens,
  }) async {
    final result = await _transport.post(
      VoiceMemoryApiRoutes.insightsEvidence.path,
      body: {
        'transcript': transcript,
        'entryId': entryId,
        if (activeLens != null && activeLens.isNotEmpty)
          'activeLens': activeLens,
      },
    );

    return result.when(
      success: (response) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiFailureMapper.fromResponse(response).toApiException();
        }
        return _transport
            .decodeEnvelope(
              response,
              parseData: EvidenceInsightResponseDto.fromJson,
              toDomain: (dto) => EvidenceInsight.fromJson(dto.insight.toJson()),
              missingDataMessage: 'Insight payload missing from response',
            )
            .when(
              success: (value) => value,
              onFailure: (failure) => throw failure.toApiException(),
            );
      },
      onFailure: (failure) => throw failure.toApiException(),
    );
  }
}
