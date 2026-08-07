import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import '../../features/live_audio/domain/models/live_audio_session_config.dart';

abstract interface class LiveAudioApiClient {
  Future<ApiResult<LiveAudioSessionConfig>> mintSession({
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  });
}
