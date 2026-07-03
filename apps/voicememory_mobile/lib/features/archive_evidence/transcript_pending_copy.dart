/// Neutral recovery copy when a moment is saved but transcript is unavailable.
abstract final class TranscriptPendingCopy {
  TranscriptPendingCopy._();

  static const savedLocallyTitle = 'Saved locally';
  static const savedLocallyBody =
      'ArchiveMe will use this once the transcript is available.';

  static const transcriptPendingTitle = 'Transcript pending';
  static const transcriptPendingBody =
      'This moment is saved, but ArchiveMe cannot compare it yet.';

  static const patternsSavedTitle = 'Your moment is saved.';
  static const patternsSavedBody =
      'ArchiveMe will look for patterns once the transcript is available or you add text.';

  static const recordPostSaveTitle = 'Saved locally.';
  static const recordPostSaveBody =
      'Transcript pending. ArchiveMe will compare this when text is available.';

  static const List<String> all = [
    savedLocallyTitle,
    savedLocallyBody,
    transcriptPendingTitle,
    transcriptPendingBody,
    patternsSavedTitle,
    patternsSavedBody,
    recordPostSaveTitle,
    recordPostSaveBody,
  ];
}
