/// Release-candidate comprehension copy — reinforce product story, no new features.
abstract final class ReleaseCandidateComprehensionCopy {
  ReleaseCandidateComprehensionCopy._();

  static const headline = 'ArchiveMe is the proof trail';

  static const body =
      'ArchiveMe is not voice chat. It shows one clear repeat, explains why it '
      'appeared, lets you confirm or correct it, and keeps the trail as it returns, '
      'changes, fades, or gets corrected.';

  static const notVoiceChatLine =
      'Not a voice assistant. Not transcription. ArchiveMe is the archive that '
      'remembers repeats.';

  static const firstProofLine =
      'First proof: one clear repeat ArchiveMe can compare safely.';

  static const whyAppearedLine =
      'Why it appeared: it was the clearest specific repeat right now, not '
      'necessarily the most important thing.';

  static const confirmCorrectLine =
      'Confirm or correct: mark it accurate, too vague, or not relevant.';

  static const proTrailLine =
      'Pro keeps the trail after the first useful proof.';

  static const changeProofLine =
      'The trail shows whether the repeat returns, changes, fades, or gets corrected.';

  static const paymentQuestion =
      'Would you pay to keep that trail over time?';

  static const guardrail =
      'Do not ship release-candidate messaging unless users understand ArchiveMe is '
      'an evidence trail, not voice chat or more AI.';

  static const bannedPhrases = [
    'better than chatgpt',
    'better chatgpt voice',
    'voice chat',
    'more ai analysis',
    'ranking dashboard',
    'importance score',
    'coaching',
    'therapy',
    'diagnosis',
    'you should',
    'you need to',
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield notVoiceChatLine;
    yield firstProofLine;
    yield whyAppearedLine;
    yield confirmCorrectLine;
    yield proTrailLine;
    yield changeProofLine;
    yield paymentQuestion;
    yield guardrail;
  }
}
