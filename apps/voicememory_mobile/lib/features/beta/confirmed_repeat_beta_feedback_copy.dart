/// Consumer copy for first confirmed-repeat beta feedback.
abstract final class ConfirmedRepeatBetaFeedbackCopy {
  ConfirmedRepeatBetaFeedbackCopy._();

  static const prompt = 'Did this feel true?';
  static const yes = 'Yes';
  static const notReally = 'Not really';
  static const needMore = 'I need to add more';
  static const notePrompt = 'What made it useful or wrong?';
  static const noteHint = 'Optional — a sentence is enough';
  static const saveNote = 'Save feedback';
  static const skipNote = 'Skip';
  static const dismiss = 'Not now';
  static const thanks = 'Thanks — saved locally for beta review.';

  static const List<String> all = [
    prompt,
    yes,
    notReally,
    needMore,
    notePrompt,
    noteHint,
    saveNote,
    skipNote,
    dismiss,
    thanks,
  ];
}
