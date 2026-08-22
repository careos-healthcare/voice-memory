import 'package:archiveme_mobile/features/next_action/archive_state_action_copy.dart';

/// Copy for the archive-aware next best action line.
abstract final class NextBestActionCopy {
  NextBestActionCopy._();

  static const noEntriesTitle = 'Next: record one real moment.';
  static const noEntriesHelper = 'Short is fine. Ten seconds is enough.';

  static const oneEntryTitle = 'Next: come back when this shows up again.';
  static const oneEntryHelper = 'You are done for now unless it happens again.';

  static const twoNoClearMatchTitle = 'Next: record the next real moment.';
  static const twoNoClearMatchHelper = 'No need to force a pattern.';

  static const twoRelatedTitle = 'Next: record one more related moment.';
  static const twoRelatedHelper =
      'One more related moment unlocks first proof.';

  static const firstProofTitle = 'Next: record when it returns.';
  static const firstProofHelper = 'ArchiveMe will compare what changed.';

  static const returnCheckUnansweredTitle = 'Next: answer return check.';
  static const returnCheckUnansweredHelper =
      'One tap helps ArchiveMe track stronger, softer, same, or different.';

  static const returnCheckAnsweredTitle = 'Next: view what changed.';
  static const returnCheckAnsweredHelper =
      'See what changed and what ArchiveMe is watching.';

  static const patternChangedTitle = 'Next: record when it returns.';
  static const patternChangedHelper =
      'ArchiveMe is watching whether this shift holds.';

  static const helpfulActionTitle = 'Next: watch whether it appears again.';
  static const helpfulActionHelper = 'This is evidence, not advice.';

  static const privateReportFormingTitle =
      'Next: keep the evidence trail going.';
  static const privateReportFormingHelper =
      'Pro keeps the longer proof trail over time.';

  static List<String> get allVisibleStrings => [
    noEntriesTitle,
    noEntriesHelper,
    oneEntryTitle,
    oneEntryHelper,
    twoNoClearMatchTitle,
    twoNoClearMatchHelper,
    twoRelatedTitle,
    twoRelatedHelper,
    firstProofTitle,
    firstProofHelper,
    returnCheckUnansweredTitle,
    returnCheckUnansweredHelper,
    returnCheckAnsweredTitle,
    returnCheckAnsweredHelper,
    patternChangedTitle,
    patternChangedHelper,
    helpfulActionTitle,
    helpfulActionHelper,
    privateReportFormingTitle,
    privateReportFormingHelper,
    ...ArchiveStateActionCopy.allActionLabels,
  ];
}