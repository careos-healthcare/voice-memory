/// User-facing copy for voice capture quality and transcription fallback.
abstract class VoiceCaptureCopy {
  VoiceCaptureCopy._();

  static const String recordingFailed =
      'Recording did not start. Try again, or save a short text moment.';

  static const String saveFailed =
      'That moment was not saved. Please try again.';

  static const String transcriptUnavailable =
      'ArchiveMe saved the moment, but the transcript may need another try.';

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

  /// Legacy combined line — prefer [transcriptUnavailable].
  static const String transcriptionFailedDegraded = transcriptUnavailable;

  static const String recordingSavedTitle = 'Recording saved.';

  static const String analysisUnavailableNote =
      'This moment is saved. ArchiveMe will compare it with future entries.';

  /// First-save receipt on Record — progression toward moment two.
  static const String firstSaveReceiptNote =
      'This is the first piece of evidence. One more moment lets ArchiveMe compare what repeats.';

  /// Legacy alias — prefer [analysisUnavailableNote] for deferred analysis copy.
  static const String analysisDeferredFootnote = analysisUnavailableNote;

  static const String typeWhatYouSaid = 'Type what you said';

  static const String degradedRecoveryTitle = recordingSavedTitle;

  static const String degradedRecoveryBody = transcriptUnavailable;

  static const List<String> all = [
    recordingFailed,
    saveFailed,
    transcriptUnavailable,
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
