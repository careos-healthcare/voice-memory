/// Archive prompt assist copy — one safe recording prompt, not chat.
abstract final class ArchivePromptAssistCopy {
  ArchivePromptAssistCopy._();

  static const headline = 'Not sure what to record?';

  static const body =
      'ArchiveMe can suggest a small prompt from what has already repeated. One '
      'sentence is enough.';

  static const safeRepeatPromptPrefix = 'Try one sentence about:';

  static const fallbackPrompt = 'What repeated today?';

  static const oneSentenceReminder = 'Keep it small. One real sentence is enough.';

  static const noChatModeLine =
      'This is not chat. It is a quick way to save proof when something returns.';

  static const archiveBasedLine =
      'Prompts should come from safe archive signals, not private raw journal text.';

  static const lowPressureLine =
      'No daily homework. No mind-map maintenance. Save a moment only when it feels real.';

  static const chatGptDifferenceLine =
      'ChatGPT helps you talk now. ArchiveMe helps your past show what keeps coming back.';

  static const guardrail =
      'Do not turn prompt assist into chat. It should only reduce effort by suggesting '
      'one safe recording prompt.';

  static String safeRepeatPrompt(String safeRepeatPhrase) =>
      '$safeRepeatPromptPrefix $safeRepeatPhrase';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield safeRepeatPromptPrefix;
    yield fallbackPrompt;
    yield oneSentenceReminder;
    yield noChatModeLine;
    yield archiveBasedLine;
    yield lowPressureLine;
    yield chatGptDifferenceLine;
    yield guardrail;
  }
}
