/// Display-only copy for beta feedback intelligence — no journal content.
abstract final class BetaFeedbackIntelligenceCopy {
  BetaFeedbackIntelligenceCopy._();

  static const cardTitle = 'Help improve ArchiveMe';
  static const cardBody =
      'Tell us whether the archive felt different from chat and whether the longer memory felt worth paying for.';
  static const cardCta = 'Give beta feedback';

  static const sheetTitle = 'Beta feedback';

  static const chatGptDifferenceQuestion =
      'Did ArchiveMe feel different from ChatGPT?';
  static const chatGptDifferenceYes = 'Yes';
  static const chatGptDifferenceNotSure = 'Not sure';
  static const chatGptDifferenceNo = 'No';

  static const differentiatorQuestion = 'What made it feel different?';
  static const differentiatorRepeats = 'It showed repeats';
  static const differentiatorChange = 'It showed change';
  static const differentiatorOlderMoments = 'It remembered older moments';
  static const differentiatorNotDifferent = 'It did not feel different';
  static const differentiatorOther = 'Other';

  static const wouldPayQuestion =
      'Would you pay for longer memory and private reports?';
  static const wouldPayYes = 'Yes';
  static const wouldPayMaybe = 'Maybe';
  static const wouldPayNo = 'No';

  static const mainConfusionQuestion = 'What confused you most?';
  static const confusionFirstRecording = 'First recording';
  static const confusionFirstProof = 'First proof';
  static const confusionPatterns = 'Patterns';
  static const confusionPro = 'Pro';
  static const confusionDifferenceFromChatGpt = 'Difference from ChatGPT';
  static const confusionNothing = 'Nothing';

  static const strongestMomentQuestion = 'What was the strongest moment?';
  static const strongestFirstProof = 'First proof';
  static const strongestWhatChanged = 'What changed';
  static const strongestQuietSignal = 'Quiet signal';
  static const strongestPrivateReport = 'Private report';
  static const strongestProExplanation = 'Pro explanation';
  static const strongestNothingYet = 'Nothing yet';

  static const submitCta = 'Submit feedback';

  static const summaryTitle = 'Beta signal';
  static const summaryFirstProofLabel = 'First proof reached';
  static const summaryChatGptLabel = 'ChatGPT difference understood';
  static const summaryProValueLabel = 'Pro value understood';
  static const summaryMainConfusionLabel = 'Main confusion';
  static const summaryStrongestMomentLabel = 'Strongest moment';
  static const summaryFeedbackSubmittedLabel = 'Feedback submitted';
  static const summaryYes = 'Yes';
  static const summaryNo = 'No';
  static const summaryNotSure = 'Not sure';
  static const summaryMaybe = 'Maybe';
  static const summaryNotYet = 'Not yet';

  static const stillToTestHeading = 'Still to test';
  static const reachedHeading = 'Reached';

  static List<String> allVisibleStrings() => [
    cardTitle,
    cardBody,
    cardCta,
    sheetTitle,
    chatGptDifferenceQuestion,
    chatGptDifferenceYes,
    chatGptDifferenceNotSure,
    chatGptDifferenceNo,
    differentiatorQuestion,
    differentiatorRepeats,
    differentiatorChange,
    differentiatorOlderMoments,
    differentiatorNotDifferent,
    differentiatorOther,
    wouldPayQuestion,
    wouldPayYes,
    wouldPayMaybe,
    wouldPayNo,
    mainConfusionQuestion,
    confusionFirstRecording,
    confusionFirstProof,
    confusionPatterns,
    confusionPro,
    confusionDifferenceFromChatGpt,
    confusionNothing,
    strongestMomentQuestion,
    strongestFirstProof,
    strongestWhatChanged,
    strongestQuietSignal,
    strongestPrivateReport,
    strongestProExplanation,
    strongestNothingYet,
    submitCta,
    summaryTitle,
    summaryFirstProofLabel,
    summaryChatGptLabel,
    summaryProValueLabel,
    summaryMainConfusionLabel,
    summaryStrongestMomentLabel,
    summaryFeedbackSubmittedLabel,
  ];
}