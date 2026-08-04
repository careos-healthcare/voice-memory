/// The five latency spans that define whether capture feels instant.
///
/// Nothing in this module ever observes journal content. A span carries a
/// duration and nothing else, and only a coarse band derived from that
/// duration is ever allowed to leave the device.
enum CaptureSpan {
  /// Dart `main()` entry until the Record surface can accept a tap.
  appLaunchToRecordInteractive,

  /// The Record tap until the UI is in the recording state.
  recordTapToRecording,

  /// The Stop tap until the capture is sealed in the encrypted local vault
  /// and committed to the journal.
  stopTapToEncryptedPersistence,

  /// A committed save until its transcript is on screen.
  saveToTranscriptVisible,

  /// A committed save until the first valid observation is on screen.
  saveToFirstValidObservation,
}

extension CaptureSpanId on CaptureSpan {
  /// Stable local identifier, used for the local report only.
  String get id => switch (this) {
    CaptureSpan.appLaunchToRecordInteractive =>
      'app_launch_to_record_interactive',
    CaptureSpan.recordTapToRecording => 'record_tap_to_recording',
    CaptureSpan.stopTapToEncryptedPersistence =>
      'stop_tap_to_encrypted_persistence',
    CaptureSpan.saveToTranscriptVisible => 'save_to_transcript_visible',
    CaptureSpan.saveToFirstValidObservation =>
      'save_to_first_valid_observation',
  };
}
