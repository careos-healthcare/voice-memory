import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import '../../features/live_audio/domain/models/live_audio_session_config.dart';
import '../network/live_audio_api_client.dart';

class LiveAudioRepository {
  LiveAudioRepository({
    required LiveAudioApiClient api,
    required NetworkRequestScope requestScope,
  }) : _api = api,
       _requestScope = requestScope;

  final LiveAudioApiClient _api;
  final NetworkRequestScope _requestScope;

  Future<ApiResult<LiveAudioSessionConfig>> mintSession({
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? _requestScope.register();
    final owned = cancelToken == null;
    try {
      return await _api.mintSession(
        captureToken: captureToken,
        idempotencyKey: idempotencyKey,
        cancelToken: token,
      );
    } finally {
      if (owned) {
        _requestScope.release(token);
      }
    }
  }
}
