/// User-facing copy for voice capture quality and transcription fallback.
abstract class VoiceCaptureCopy {
  VoiceCaptureCopy._();

  static const String notEnoughAudio =
      'We could not hear enough audio. Try again closer to the microphone.';

  static const String transcriptionFailedTitle =
      'ArchiveMe could not turn this recording into text.';

  static const String savedPrivatelySuccess = 'Recording saved privately.';

  static const String transcriptionFailedIssue =
      'ArchiveMe could not turn this recording into text on this device.';

  static const String lowQualityTranscriptIssue =
      'ArchiveMe could not hear enough usable words.';

  static const String silentMicrophoneInputDebugWarning =
      'Recording saved, but the iPad microphone input looked silent. '
      'Try disconnecting Bluetooth/audio accessories, then record again.';

  static const String recordAgainCta = 'Record again';

  /// Legacy combined line — prefer [savedPrivatelySuccess] + [transcriptionFailedIssue].
  static const String transcriptionFailedDegraded =
      'Recording saved, but ArchiveMe could not turn it into text on this device.';

  static const String recordingSavedTitle = 'Recording saved.';

  static const String analysisUnavailableNote =
      'Archive insight will appear when processing is available.';

  static const String typeWhatYouSaid = 'Type what you said';

  static const String degradedRecoveryTitle = 'We recorded your audio.';

  static const String degradedRecoveryBody =
      'The transcript was not clear enough. Add a short note so this moment '
      'is useful in your archive.';

  static const List<String> all = [
    notEnoughAudio,
    transcriptionFailedTitle,
    savedPrivatelySuccess,
    transcriptionFailedIssue,
    lowQualityTranscriptIssue,
    recordAgainCta,
    transcriptionFailedDegraded,
    recordingSavedTitle,
    analysisUnavailableNote,
    typeWhatYouSaid,
    degradedRecoveryTitle,
    degradedRecoveryBody,
  ];
}
