/// Trust copy for per-entry processing transparency.
abstract final class EntryProcessingCopy {
  EntryProcessingCopy._();

  static const processedOnDevice = 'Processed on your device';
  static const sentForSecureProcessing =
      'Sent securely for higher-accuracy processing';

  /// For an entry whose transcript came from `SFSpeechRecognizer` and which
  /// has not been analysed at all.
  ///
  /// Deliberately not [processedOnDevice]. On that path
  /// (`_saveProvisionalNativeTranscript`) the recogniser ran locally, but the
  /// entry is saved `TranscriptStatus.provisional` with
  /// `analysisSucceeded: false`, an empty placeholder `Reflection`, and
  /// `SyncStatus.pendingUpload` — so no processing has happened yet and the
  /// entry is queued to be uploaded. Saying "Processed on your device" would
  /// claim a step that did not run and imply a durability the sync queue
  /// contradicts. This names the one act that did happen on the device.
  static const transcribedOnDevice = 'Transcribed on this device';
}
