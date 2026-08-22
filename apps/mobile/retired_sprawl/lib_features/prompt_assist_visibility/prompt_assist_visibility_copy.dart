/// Prompt assist visibility copy — low-effort recording prompts, not chat.
abstract final class PromptAssistVisibilityCopy {
  PromptAssistVisibilityCopy._();

  static const headline = 'Not sure what to say?';

  static const body =
      'ArchiveMe can suggest one small prompt. Say one real sentence and save it.';

  static const safeRepeatLine = 'Try one sentence about:';

  static const fallbackLine = 'What repeated today?';

  static const whyLine =
      'Prompts help you save the repeat without turning this into chat.';

  static const archiveSignalLine =
      'When possible, prompts come from safe archive signals — not private raw '
      'journal text.';

  static const lowEffortLine =
      'No need to explain everything. One sentence is enough.';

  static const notChatLine =
      'This is not a conversation. It is a quick way to save proof.';

  static const guardrail =
      'Prompt assist must reduce effort without becoming chat, advice, coaching, '
      'or a required daily check-in.';

  static String safeRepeatPrompt(String safeRepeatPhrase) =>
      '$safeRepeatLine $safeRepeatPhrase';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield safeRepeatLine;
    yield fallbackLine;
    yield whyLine;
    yield archiveSignalLine;
    yield lowEffortLine;
    yield notChatLine;
  }
}