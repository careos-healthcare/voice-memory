/// User-facing copy for voice capture quality and transcription fallback.
library;

import '../trust/capture_recovery_copy.dart';
import '../archive_evidence/transcript_pending_copy.dart';

abstract class VoiceCaptureCopy {
  VoiceCaptureCopy._();

  static const String recordingFailed = CaptureRecoveryCopy.recordingFailed;

  static const String saveFailed = CaptureRecoveryCopy.saveFailed;

  static const String transcriptUnavailable =
      CaptureRecoveryCopy.transcriptUnavailable;

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

  static const String transcriptPendingPostSaveTitle =
      TranscriptPendingCopy.recordPostSaveTitle;

  static const String transcriptPendingPostSaveBody =
      TranscriptPendingCopy.recordPostSaveBody;

  /// Post-save when audio saved but transcript is still pending.
  static const String savedLocallyPendingTitle = transcriptPendingPostSaveTitle;
  static const String savedLocallyPendingBody = transcriptPendingPostSaveBody;

  static const String typeWhatYouSaid = 'Type what you said';

  static const String degradedRecoveryTitle = recordingSavedTitle;

  static const String degradedRecoveryBody = transcriptUnavailable;

  /// Shown when a capture is saved locally without remote analysis because
  /// remote processing consent is currently off — a deliberate customer
  /// choice, not a failure, so the wording stays neutral rather than
  /// apologetic.
  static const String remoteProcessingConsentPausedNote =
      'This moment is saved on your device only. Turn on remote analysis in '
      'Privacy settings to get a reflection for it.';

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
    remoteProcessingConsentPausedNote,
  ];
}
