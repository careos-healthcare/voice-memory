/// User-facing copy for the beta-only 3-day tester script.
abstract final class BetaTestScriptCopy {
  BetaTestScriptCopy._();

  static const settingsTileTitle = '3-day beta test';
  static const settingsTileBody =
      'Follow the exact loop ArchiveMe needs tested.';

  static const screenTitle = '3-day ArchiveMe test';

  static const intro =
      'Use ArchiveMe once a day for three days. Record real moments only. '
      'The goal is to see whether ArchiveMe notices something that feels true.';

  static const day1Title = 'Day 1 — Save one real moment';
  static const day1Body =
      'Record something real from today. It can be small.';
  static const day1Checklist = [
    'Open ArchiveMe',
    'Save one real moment',
    'Check whether you knew what to record',
  ];

  static const day2Title = 'Day 2 — Record what came back';
  static const day2Body =
      'Record anything that came back, felt different, or stayed quiet.';
  static const day2Checklist = [
    'Open ArchiveMe again',
    'Record what came back or changed',
    'Use the return prompt if it appears',
  ];

  static const day3Title = 'Day 3 — Check first proof';
  static const day3Body =
      'Record one more real moment. If ArchiveMe shows first proof, answer whether it felt true.';
  static const day3Checklist = [
    'Save one more real moment',
    'Check first proof if it appears',
    'Answer “Does this feel true?”',
    'Send beta feedback',
  ];

  static const successHeading = 'After first proof, ask yourself:';
  static const successQuestions = [
    'Did this feel true?',
    'Would I come back tomorrow?',
    'Would I pay if this kept working?',
  ];

  static const failureHeading = 'If first proof appears and you do not care, that is useful feedback.';

  static const progressHeading = 'Beta test progress';

  static const day1NotStarted = 'Not started';
  static const day1Done = 'Done';
  static const day2Waiting = 'Waiting';
  static const day2Done = 'Done';
  static const day3Waiting = 'Waiting';
  static const day3Done = 'Done';
  static const firstProofNotReached = 'Not reached';
  static const firstProofReached = 'Reached';
  static const feedbackNotSent = 'Not sent';
  static const feedbackSent = 'Sent';

  static const day1Label = 'Day 1';
  static const day2Label = 'Day 2';
  static const day3Label = 'Day 3';
  static const firstProofLabel = 'First proof';
  static const feedbackLabel = 'Feedback';

  static const compactTitle = '3-day beta test';

  static const compactBodyDay1 = 'Day 1: Save one real moment.';
  static const compactBodyDay2 =
      'Day 2: Come back and record what returned, changed, or stayed quiet.';
  static const compactBodyDay3 =
      'Day 3: Save one more real moment and check whether ArchiveMe notices a repeat.';
  static const compactBodyFirstProof =
      'First proof reached. Answer whether it felt true.';
  static const compactBodyComplete =
      'Beta loop complete. Send feedback while it is fresh.';

  static const viewTestStepsCta = 'View test steps';
  static const sendBetaFeedbackCta = 'Send beta feedback';
  static const resetProgressCta = 'Reset beta test progress';

  static const resetTitle = 'Reset beta test progress?';
  static const resetBody =
      'This only resets the beta checklist. It will not delete your archive.';
  static const resetConfirmCta = 'Reset';
  static const resetCancelCta = 'Cancel';

  static List<String> allVisibleStrings() => [
        settingsTileTitle,
        settingsTileBody,
        screenTitle,
        intro,
        day1Title,
        day1Body,
        ...day1Checklist,
        day2Title,
        day2Body,
        ...day2Checklist,
        day3Title,
        day3Body,
        ...day3Checklist,
        successHeading,
        ...successQuestions,
        failureHeading,
        progressHeading,
        day1NotStarted,
        day1Done,
        day2Waiting,
        day2Done,
        day3Waiting,
        day3Done,
        firstProofNotReached,
        firstProofReached,
        feedbackNotSent,
        feedbackSent,
        compactTitle,
        compactBodyDay1,
        compactBodyDay2,
        compactBodyDay3,
        compactBodyFirstProof,
        compactBodyComplete,
        viewTestStepsCta,
        sendBetaFeedbackCta,
        resetProgressCta,
        resetTitle,
        resetBody,
        resetConfirmCta,
        resetCancelCta,
      ];
}
