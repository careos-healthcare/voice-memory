/// User-facing copy for the pattern detail sheet.
abstract final class PatternDetailCopy {
  PatternDetailCopy._();

  static const sheetTitle = 'Pattern details';

  static const patternLabelHeading = 'Pattern';

  static const evidenceHeading = 'Evidence from your words';
  static const evidenceIntro =
      'These moments helped ArchiveMe spot the repeat.';

  static const whatChangedHeading = 'What changed';
  static const notEnoughChangeEvidence = 'Not enough change evidence yet.';

  static const whatHelpedHeading = 'What helped';
  static const notEnoughHelpedEvidence = 'Not enough evidence yet.';

  static const savedMomentsHeading = 'Saved moments used as evidence';

  static const whatToWatchHeading = 'What to watch next';

  static const whyThisMattersHeading = 'Why this matters';
  static const whyThisMattersBody =
      'This is not one answer. It is the same thread appearing across saved moments.';

  static const viewPatternDetailsCta = 'View pattern details';

  static List<String> allVisibleCopy() => [
        sheetTitle,
        patternLabelHeading,
        evidenceHeading,
        evidenceIntro,
        whatChangedHeading,
        notEnoughChangeEvidence,
        whatHelpedHeading,
        notEnoughHelpedEvidence,
        savedMomentsHeading,
        whatToWatchHeading,
        whyThisMattersHeading,
        whyThisMattersBody,
        viewPatternDetailsCta,
      ];
}
