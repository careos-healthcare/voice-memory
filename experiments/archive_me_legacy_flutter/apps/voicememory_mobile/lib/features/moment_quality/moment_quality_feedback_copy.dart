/// User-facing post-save guidance — never internal scores or quality levels.
abstract final class MomentQualityFeedbackCopy {
  MomentQualityFeedbackCopy._();

  static const specificUsableTitle = 'Good moment for your archive';
  static const specificUsableBody =
      'This gives ArchiveMe something specific to compare later.';

  static const savedTitle = 'Saved';
  static const tooShortBody =
      'This may be too short for patterns, but it still counts.';

  static const quietDayTitle = 'Saved as a quiet day';
  static const quietDayBody =
      'ArchiveMe will keep watching when something stands out.';

  static const genericTestBody = 'Saved, but not used for patterns.';

  static const pendingTranscriptBody =
      'Add what you said so ArchiveMe can use this later.';

  static List<String> allVisibleCopy() => [
    specificUsableTitle,
    specificUsableBody,
    savedTitle,
    tooShortBody,
    quietDayTitle,
    quietDayBody,
    genericTestBody,
    pendingTranscriptBody,
  ];
}
