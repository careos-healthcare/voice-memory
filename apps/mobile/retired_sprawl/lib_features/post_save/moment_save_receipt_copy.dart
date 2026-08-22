/// Copy for the focused-beta unified post-save receipt.
abstract final class MomentSaveReceiptCopy {
  MomentSaveReceiptCopy._();

  static const String savedOnDeviceTitle = 'Saved on this device';

  static const String recordAnother = 'Record another';
  static const String viewArchive = 'View Archive';
  static const String correctText = 'Correct text';

  static const String remoteProcessingFailed =
      'Remote processing did not finish. Your moment is still saved here.';
  static const String remoteProcessingRetry = 'Retry remote processing';

  static const String remoteProcessingPending =
      'Transcription or reflection is still running in the background.';

  static const String localOnlyNote =
      'This moment stays on this device until you turn on remote processing.';

  static const List<String> all = [
    savedOnDeviceTitle,
    recordAnother,
    viewArchive,
    correctText,
    remoteProcessingFailed,
    remoteProcessingRetry,
    remoteProcessingPending,
    localOnlyNote,
  ];
}
