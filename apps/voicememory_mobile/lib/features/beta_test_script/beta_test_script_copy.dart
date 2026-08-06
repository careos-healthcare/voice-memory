import '../landing_continuity/landing_app_continuity_copy.dart';

/// User-facing copy for the beta early-archive tester script.
abstract final class BetaTestScriptCopy {
  BetaTestScriptCopy._();

  static const settingsTileTitle = 'Early archive test';
  static const settingsTileBody =
      'Follow the landing promise ArchiveMe needs tested.';

  static const screenTitle = 'ArchiveMe early test';

  static const intro =
      'No daily journal required. Save small moments when something stands out, '
      'come back when another moment matters, and see what returned.';

  static const day1Title = 'Step 1 — Save one small moment';
  static const day1Body = LandingAppContinuityCopy.step1Body;
  static const day1Checklist = [
    'Open ArchiveMe',
    'Save one small moment when something stands out',
    'Check whether you knew what to save',
  ];

  static const day2Title = 'Step 2 — Come back when something stands out';
  static const day2Body = LandingAppContinuityCopy.step2Body;
  static const day2Checklist = [
    'Open ArchiveMe again',
    'Save another moment that stands out',
    'Use the return prompt if it appears',
  ];

  static const day3Title = 'Step 3 — See what returned';
  static const day3Body = LandingAppContinuityCopy.step3Body;
  static const day3Checklist = [
    'Save one more small moment if something stands out',
    'Check whether anything returned',
    'Answer “Does this feel true?” if first proof appears',
    'Send beta feedback',
  ];

  static const successHeading = 'After first proof, ask yourself:';
  static const successQuestions = [
    'Did this feel true?',
    'Would I come back when something stands out?',
    'Would I pay if this kept working?',
  ];

  static const failureHeading =
      'If first proof appears and you do not care, that is useful feedback.';

  static const progressHeading = 'Early test progress';

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

  static const day1Label = 'Step 1';
  static const day2Label = 'Step 2';
  static const day3Label = 'Step 3';
  static const firstProofLabel = 'First proof';
  static const feedbackLabel = 'Feedback';

  static const compactTitle = 'Early archive test';

  static const compactBodyDay1 =
      'Save one small moment when something stands out.';
  static const compactBodyDay2 = 'Come back when something stands out.';
  static const compactBodyDay3 = 'See what returned after a few saves.';
  static const compactBodyFirstProof =
      'First proof reached. Answer whether it felt true.';
  static const compactBodyComplete =
      'Early test complete. Send feedback while it is fresh.';

  static const viewTestStepsCta = 'View test steps';
  static const sendBetaFeedbackCta = 'Send beta feedback';
  static const resetProgressCta = 'Reset test progress';

  static const resetTitle = 'Reset early test progress?';
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
