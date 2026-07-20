import '../../../api/api_client.dart';
import '../domain/models/live_audio_session_config.dart';

abstract class LiveAudioSessionApiClient {
  Future<LiveAudioSessionConfig> mintSession({
    required String captureToken,
    String? idempotencyKey,
  });
}

class ApiLiveAudioSessionClient implements LiveAudioSessionApiClient {
  const ApiLiveAudioSessionClient(this._api);

  final ApiClient _api;

  @override
  Future<LiveAudioSessionConfig> mintSession({
    required String captureToken,
    String? idempotencyKey,
  }) {
    return _api.postLiveAudioSession(
      captureToken: captureToken,
      idempotencyKey: idempotencyKey,
    );
  }
}
