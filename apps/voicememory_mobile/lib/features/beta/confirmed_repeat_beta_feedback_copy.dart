/// Consumer copy for confirmed-repeat beta feedback after third-recording proof.
abstract final class ConfirmedRepeatBetaFeedbackCopy {
  ConfirmedRepeatBetaFeedbackCopy._();

  static const prompt = 'Did this feel true?';
  static const yes = 'Yes';
  static const somewhat = 'Somewhat';
  static const notReally = 'Not really';
  static const followUpPrompt = 'What felt off?';
  static const tooGeneric = 'Too generic';
  static const wrongPattern = 'Wrong pattern';
  static const repeatedTooMuch = 'Repeated too much';
  static const missingContext = 'Missing context';
  static const dismiss = 'Not now';
  static const thanks = 'Thanks — saved locally for beta review.';

  static const List<String> all = [
    prompt,
    yes,
    somewhat,
    notReally,
    followUpPrompt,
    tooGeneric,
    wrongPattern,
    repeatedTooMuch,
    missingContext,
    dismiss,
    thanks,
  ];
}
