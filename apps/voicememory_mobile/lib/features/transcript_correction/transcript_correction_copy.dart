/// Copy for correcting an existing saved transcript.
abstract final class TranscriptCorrectionCopy {
  TranscriptCorrectionCopy._();

  static const actionLabel = 'Correct transcript';
  static const sheetTitle = 'Correct transcript';
  static const sheetHelper =
      'Fix any words ArchiveMe heard wrong. Your correction will be used for future patterns.';
  static const inputLabel = 'What you meant to say';
  static const saveButton = 'Save correction';
  static const cancelButton = 'Cancel';
  static const savedSuccess = 'Transcript corrected';
  static const saveFailed = 'Could not save your correction. Try again.';

  static const List<String> all = [
    actionLabel,
    sheetTitle,
    sheetHelper,
    inputLabel,
    saveButton,
    cancelButton,
    savedSuccess,
    saveFailed,
  ];
}
