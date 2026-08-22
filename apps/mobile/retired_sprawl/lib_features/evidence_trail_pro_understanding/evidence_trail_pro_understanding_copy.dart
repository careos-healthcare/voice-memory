/// Evidence trail + Pro understanding copy — trail over time, not ranked advice.
abstract final class EvidenceTrailProUnderstandingCopy {
  EvidenceTrailProUnderstandingCopy._();

  static const title = 'Keep the longer trail';

  static const body =
      'ArchiveMe has found one useful repeat. Pro keeps tracking whether it '
      'returns, changes, softens, strengthens, fades, or gets corrected.';

  static const supportingLine =
      'Free shows the first proof. Pro keeps the evidence trail over time.';

  static const cta = 'See the longer trail';

  static const secondary = 'Keep using free';

  static const clarityQuestion = 'Do you understand what Pro keeps?';

  static const clarityYes = 'Yes';
  static const clarityNotYet = 'Not yet';
  static const clarityNeedMoreProof = 'I need more proof first';

  static const guardrail =
      'Do not sell Pro until users understand that Pro keeps the longer '
      'evidence trail, not ranked advice.';

  static const bannedPhrases = [
    'ranked list',
    'importance score',
    'ranking',
    'more ai',
    'better advice',
    'coaching',
    'therapy',
    'diagnosis',
    'generic journaling',
    'you should',
    'you need to',
  ];

  static const List<String> clarityOptions = [
    clarityYes,
    clarityNotYet,
    clarityNeedMoreProof,
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield supportingLine;
    yield cta;
    yield secondary;
    yield clarityQuestion;
    yield clarityYes;
    yield clarityNotYet;
    yield clarityNeedMoreProof;
    yield guardrail;
  }
}