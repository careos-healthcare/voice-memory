import 'package:archiveme_mobile/api/models/insights_conversation_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/data/network/insights_conversation_api_client.dart';

class HttpInsightsConversationApiClient
    implements InsightsConversationApiClient {
  HttpInsightsConversationApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<InsightsConversationReply>> sendConversationMessage({
    required List<InsightsConversationTurn> conversationHistory,
    required String message,
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri(VoiceMemoryApiRoutes.insightsConversation.path) ==
        null) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }

    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.insightsConversation.path,
      body: {
        'conversationHistory': conversationHistory
            .map((turn) => turn.toJson())
            .toList(),
        'message': message,
      },
      cancelToken: cancelToken,
    );

    return responseResult.when(
      success: (response) {
        if (response.statusCode == 401) {
          return const ApiFailureResult(ApiFailureAuthRequired());
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeEnvelope(
          response,
          parseData: InsightsConversationResponseDto.fromJson,
          toDomain: (dto) => InsightsConversationReply(
            reply: dto.reply,
            citedEntryIds: dto.citedEntryIds,
            groundedness: dto.groundedness,
          ),
          missingDataMessage: 'Insights conversation reply missing',
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
