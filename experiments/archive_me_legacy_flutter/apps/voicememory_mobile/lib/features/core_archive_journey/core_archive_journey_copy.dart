/// Core ArchiveMe journey + anti-voice-assistant positioning copy.
abstract final class CoreArchiveJourneyCopy {
  CoreArchiveJourneyCopy._();

  static const headline = 'ArchiveMe shows what keeps repeating';

  static const subheadline =
      'Not a better voice assistant. A private archive that proves what returns, '
      'changes, fades, or gets corrected over time.';

  static const journeyTitle = 'The ArchiveMe journey';

  static const firstProof =
      'First proof: ArchiveMe shows one clear repeat it can compare safely.';

  static const whyThisProofAppeared =
      'Why this proof appeared: it was the clearest specific repeat, not necessarily '
      'the most important thing.';

  static const confirmOrCorrect =
      'Confirm or correct: mark it accurate, too vague, or not relevant.';

  static const longerEvidenceTrail =
      'Longer evidence trail: keep seeing whether the repeat returns over time.';

  static const returnsChangesFadesCorrected =
      'Returns, changes, fades, or corrected: the trail shows what happens next.';

  static const proKeepsTheTrail =
      'Pro keeps the trail: Free shows the first useful proof. Pro keeps the longer '
      'evidence trail.';

  static const antiVoiceAssistantGuardrail =
      'ArchiveMe must not be positioned as a better ChatGPT Voice. It is not voice '
      'chat, transcription, or a general assistant.';

  static const positioningLine =
      'ChatGPT answers today. ArchiveMe shows what keeps repeating across your life.';

  static const proofOfChangeLine =
      'ArchiveMe remembers repeats and proves change over time.';

  static const doNotBuildBetterVoiceChat = 'Better voice chat';
  static const doNotBuildGenericTranscription = 'Generic transcription';
  static const doNotBuildAiCompanion = 'AI companion';
  static const doNotBuildRankedAdvice = 'Ranked advice';
  static const doNotBuildTherapyOrDiagnosis = 'Therapy or diagnosis';
  static const doNotBuildMoreAiInsteadOfEvidence =
      'More AI instead of more evidence';

  static const doNotBuildList = [
    doNotBuildBetterVoiceChat,
    doNotBuildGenericTranscription,
    doNotBuildAiCompanion,
    doNotBuildRankedAdvice,
    doNotBuildTherapyOrDiagnosis,
    doNotBuildMoreAiInsteadOfEvidence,
  ];

  static const bannedPhrases = [
    'better than chatgpt',
    'better chatgpt voice',
    'voice assistant',
    'ai companion',
    'generic journaling',
    'ranking dashboard',
    'importance score',
    'you should',
    'you need to',
    'coaching',
    'therapy',
    'diagnosis',
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield subheadline;
    yield journeyTitle;
    yield firstProof;
    yield whyThisProofAppeared;
    yield confirmOrCorrect;
    yield longerEvidenceTrail;
    yield returnsChangesFadesCorrected;
    yield proKeepsTheTrail;
    yield antiVoiceAssistantGuardrail;
    yield positioningLine;
    yield proofOfChangeLine;
  }
}
