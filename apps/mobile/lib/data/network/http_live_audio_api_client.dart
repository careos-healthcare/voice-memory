import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/data/network/live_audio_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_audio_session_config.dart';
import 'package:archiveme_mobile/core/network/api_headers.dart';

class HttpLiveAudioApiClient implements LiveAudioApiClient {
  HttpLiveAudioApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<LiveAudioSessionConfig>> mintSession({
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    final headers = <String, String>{
      ApiHeaders.captureToken: captureToken,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        ApiHeaders.idempotencyKey: idempotencyKey,
    };

    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.liveAudioSession.path,
      headers: headers,
      body: {},
      cancelToken: cancelToken,
    );

    return responseResult.when(
      success: (response) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeEnvelope<Map<String, dynamic>, LiveAudioSessionConfig>(
          response,
          parseData: (json) => json,
          toDomain: LiveAudioSessionConfig.fromJson,
          missingDataMessage: 'Live audio session mint failed',
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
