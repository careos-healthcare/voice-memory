/// Proof emotional clarity when users reach proof but do not care.
abstract final class ProofEmotionalClarityCopyFix {
  ProofEmotionalClarityCopyFix._();

  static const whatCameBack = 'What came back?';
  static const whatChanged = 'What changed?';
  static const whyMightMatter = 'Why this might matter?';

  static const whyMattersStrongEvidence =
      'This matters because it is no longer just one moment — it has shown up more than once.';

  static const correctionNotQuite = 'Not quite';
  static const correctionFeelsRight = 'This feels right';
  static const correctionItChanged = 'It changed';

  static const cautionFooter =
      'ArchiveMe compares your own words cautiously — not as a diagnosis or guarantee.';

  static Iterable<String> allVisibleStrings() sync* {
    yield whatCameBack;
    yield whatChanged;
    yield whyMightMatter;
    yield whyMattersStrongEvidence;
    yield correctionNotQuite;
    yield correctionFeelsRight;
    yield correctionItChanged;
    yield cautionFooter;
  }
}
