part of 'recording_screen.dart';

extension RecordingAudioListener on _RecordScreenState {
  void attachRecordingServiceListener(WidgetRef ref) {
    ref.listen(recordingServiceProvider, (previous, next) {
      if (!mounted) return;
      final seconds = next.currentDuration.inSeconds;
      if (previous?.currentDuration == next.currentDuration) return;
      _recordingState.syncDurationSeconds(seconds);
      if (_ui == RecordUiState.recording &&
          RecordingDurationPolicy.shouldAutoStop(seconds)) {
        unawaited(_stopAndProcess(reachedDurationLimit: true));
      }
    });
  }
}