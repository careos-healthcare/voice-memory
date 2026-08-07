import '../../../core/network/api_failure.dart';
import '../../../data/repositories/live_audio_repository.dart';
import '../domain/models/live_audio_session_config.dart';

abstract class LiveAudioSessionApiClient {
  Future<LiveAudioSessionConfig> mintSession({
    required String captureToken,
    String? idempotencyKey,
  });
}

class RepositoryLiveAudioSessionClient implements LiveAudioSessionApiClient {
  const RepositoryLiveAudioSessionClient(this._repository);

  final LiveAudioRepository _repository;

  @override
  Future<LiveAudioSessionConfig> mintSession({
    required String captureToken,
    String? idempotencyKey,
  }) async {
    final result = await _repository.mintSession(
      captureToken: captureToken,
      idempotencyKey: idempotencyKey,
    );
    return result.when(
      success: (config) => config,
      onFailure: (failure) => throw failure.toApiException(),
    );
  }
}
