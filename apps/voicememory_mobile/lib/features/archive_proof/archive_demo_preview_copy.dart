import '../archive_proof/visible_archive_proof_copy.dart';

/// Cold-start preview copy — watch state, not a conclusion.
abstract final class ArchiveDemoPreviewCopy {
  static const title =
      "Here's what ArchiveMe will track if this keeps appearing.";

  static const twoEntryTitle = VisibleArchiveProofCopy.earlyRepeatTitle;

  static const previewBadge = 'Preview — ArchiveMe is watching, not concluding';

  static const patternFirstSeenLabel = 'Pattern first seen';

  static const repeatWouldBeLabel = 'What would count as a repeat';

  static const softeningWouldBeLabel = 'What would count as softening';

  static const recordNextLabel = 'What to record next';

  static const oneEntryPatternHint =
      'Not enough evidence yet, but this is what ArchiveMe will watch — '
      'words or situations that come back in your recordings.';

  static const oneEntryRepeatHint =
      'The same phrase or situation showing up in a second moment.';

  static const oneEntrySofteningHint =
      'You notice it earlier, pause, or respond differently than before.';

  static const oneEntryRecordNextHint =
      'Record one more moment when something feels familiar — even loosely.';

  static const twoEntryNoRepeatHint =
      VisibleArchiveProofCopy.earlyRepeatBody;

  static const twoEntryRepeatHint =
      VisibleArchiveProofCopy.earlyRepeatEvidenceLine;

  /// When Daily Mirror sees a possible loop in two entries.
  static const twoEntryPossibleLoopRepeatHint =
      'You mentioned this more than once in your own words.';

  static const twoEntrySofteningHint =
      'You catch the thread earlier or your response shifts.';

  static const twoEntryRecordNextHint =
      VisibleArchiveProofCopy.earlyRepeatNextAction;
}
