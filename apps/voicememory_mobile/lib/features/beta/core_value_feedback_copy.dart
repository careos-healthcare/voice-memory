/// Copy for the beta-only core value feedback prompt.
abstract final class CoreValueFeedbackCopy {
  CoreValueFeedbackCopy._();

  static const title = 'Beta feedback';

  static const question =
      'Did ArchiveMe show something repeating in your own words that was worth tracking?';

  static const helper = 'This is the main thing I’m testing.';

  static const answerYes = 'Yes';

  static const answerNotYet = 'Not yet';

  static const answerGeneric = 'Felt generic';

  static const hideForNow = 'Hide for now';

  static const diagnosticsLabel = 'Core value feedback';

  static const diagnosticsNoAnswer = 'No answer yet';

  static List<String> get all => [
        title,
        question,
        helper,
        answerYes,
        answerNotYet,
        answerGeneric,
        hideForNow,
        diagnosticsLabel,
        diagnosticsNoAnswer,
      ];
}
