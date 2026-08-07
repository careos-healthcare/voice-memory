import '../../api/api_exceptions.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_headers.dart';
import '../../core/network/api_result.dart';
import '../../core/network/http_transport.dart';
import '../../core/network/network_cancel_token.dart';
import '../../features/live_audio/domain/models/live_audio_session_config.dart';
import '../../security/api_response_safety.dart';
import 'live_audio_api_client.dart';

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
      '/api/live-audio/session',
      headers: headers,
      body: {},
      cancelToken: cancelToken,
    );

    return responseResult.when(
      success: (response) {
        try {
          ApiResponseSafety.ensureJsonResponse(response);
        } on ApiException catch (error) {
          return ApiFailureResult(ApiFailureMapper.fromException(error));
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeSuccess(response, (body) {
          if (body['ok'] != true) {
            throw ApiException(
              body['error'] as String? ?? 'Live audio session mint failed',
              statusCode: response.statusCode,
              code: body['code'] as String?,
            );
          }
          return LiveAudioSessionConfig.fromJson(body);
        });
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
