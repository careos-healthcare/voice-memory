import 'proof_emotional_clarity_model.dart';

/// Proof emotional clarity when users reach proof but do not care.
abstract final class ProofEmotionalClarityCopyFix {
  ProofEmotionalClarityCopyFix._();

  static const headline = 'This came back.';

  static const subheadline =
      'It is not just one moment now. ArchiveMe found it more than once.';

  static const whatCameBackLabel = 'What came back';
  static const whatChangedLabel = 'What changed';
  static const whyItMightMatterLabel = 'Why this might matter';

  static const whyLine =
      'This matters because it gives you something real to compare next time.';

  static const whyMattersStrongEvidence =
      'This matters because it is no longer just one moment — it has shown up more than once.';

  static const correctionPrompt = 'Does this feel right?';
  static const correctionNotQuite = 'Not quite';
  static const correctionFeelsRight = 'This feels right';
  static const correctionItChanged = 'It changed';

  static const softenedPayoff = 'It came back, but softer.';
  static const repeatedPayoff = 'This looks like a repeat.';
  static const changedPayoff = 'The pattern changed.';
  static const fadedPayoff = 'It may be fading.';
  static const notSurePayoff = 'ArchiveMe will keep watching.';

  static const watchOnlySubhead =
      'ArchiveMe is watching for whether this comes back.';
  static const watchOnlyEvidence = 'There is not enough proof yet.';

  static const cautionFooter =
      'ArchiveMe compares your own words cautiously — not as certainty or a guarantee.';

  static const List<String> bannedWords = [
    'therapy',
    'diagnosis',
    'treatment',
    'trauma',
    'healing',
    'mental health',
    'ai coach',
    'chatbot',
    'breakthrough',
  ];

  static String evidenceLineForCount(int entryCount) {
    if (entryCount <= 0) return '';
    if (entryCount == 1) return 'Seen across one saved moment.';
    return 'Seen across $entryCount saved moments.';
  }

  static String headlineForVariant(ProofEmotionalClarityVariant variant) =>
      switch (variant) {
        ProofEmotionalClarityVariant.strongRepeat => headline,
        ProofEmotionalClarityVariant.softened => softenedPayoff,
        ProofEmotionalClarityVariant.changed => changedPayoff,
        ProofEmotionalClarityVariant.repeated => repeatedPayoff,
        ProofEmotionalClarityVariant.faded => fadedPayoff,
        ProofEmotionalClarityVariant.watchOnly => notSurePayoff,
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield subheadline;
    yield whatCameBackLabel;
    yield whatChangedLabel;
    yield whyItMightMatterLabel;
    yield whyLine;
    yield whyMattersStrongEvidence;
    yield correctionPrompt;
    yield correctionNotQuite;
    yield correctionFeelsRight;
    yield correctionItChanged;
    yield softenedPayoff;
    yield repeatedPayoff;
    yield changedPayoff;
    yield fadedPayoff;
    yield notSurePayoff;
    yield watchOnlySubhead;
    yield watchOnlyEvidence;
    yield cautionFooter;
  }
}
