/// User-facing copy for the pattern review inbox.
abstract final class PatternReviewInboxCopy {
  PatternReviewInboxCopy._();

  static const cardTitle = 'Review your archive';
  static const cardSubcopy =
      'Confirm what feels right, correct what feels wrong, or mark what changed.';

  static const viewAllCta = 'View all review items';

  static const sheetTitle = 'Archive review inbox';
  static const sheetSubtitle =
      'Things ArchiveMe needs your judgement on.';

  static const emptyTitle = 'Nothing needs review right now';
  static const emptyBody =
      'Keep recording real moments. ArchiveMe will ask for your judgement when something repeats, changes, or needs correcting.';

  static const chipNeedsCheck = 'Needs your check';
  static const chipOptional = 'Optional';
  static const chipQuietSignal = 'Quiet signal';

  static const firstProofTruthTitle = 'Does this feel true?';
  static const firstProofTruthBody =
      'ArchiveMe noticed a repeat. Confirm whether it fits.';

  static const whatChangedTitle = 'What changed since last time?';
  static const whatChangedBody = 'Mark what felt different this time.';

  static const patternCorrectionTitle = 'ArchiveMe got this wrong?';
  static const patternCorrectionBody =
      'Correct the pattern, remove evidence, or send feedback.';

  static const quietSignalTitle = 'This has not shown up recently';
  static const quietSignalBody =
      'ArchiveMe was watching this thread, but your recent moments did not show it.';

  static const helpedTrackingTitle = 'Did something help?';
  static const helpedTrackingBody =
      'Mark what seemed to help so ArchiveMe can remember it.';

  static const patternRenameTitle = 'Name this pattern';
  static const patternRenameBody =
      'Use your own words for what ArchiveMe noticed.';

  static const reviewCorrectionCta = 'Review correction options';
  static const keepWatchingCta = 'Keep watching';
  static const viewPatternDetailsCta = 'View pattern details';
  static const renamePatternCta = 'Rename pattern';
  static const keepSuggestedNameCta = 'Keep suggested name';

  static List<String> allVisibleStrings() => [
        cardTitle,
        cardSubcopy,
        viewAllCta,
        sheetTitle,
        sheetSubtitle,
        emptyTitle,
        emptyBody,
        chipNeedsCheck,
        chipOptional,
        chipQuietSignal,
        firstProofTruthTitle,
        firstProofTruthBody,
        whatChangedTitle,
        whatChangedBody,
        patternCorrectionTitle,
        patternCorrectionBody,
        quietSignalTitle,
        quietSignalBody,
        helpedTrackingTitle,
        helpedTrackingBody,
        patternRenameTitle,
        patternRenameBody,
        reviewCorrectionCta,
        keepWatchingCta,
        viewPatternDetailsCta,
        renamePatternCta,
        keepSuggestedNameCta,
      ];
}
