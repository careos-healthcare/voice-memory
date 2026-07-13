/// Save-a-repeat habit copy — low-pressure trigger when something repeats.
abstract final class SaveARepeatHabitCopy {
  SaveARepeatHabitCopy._();

  static const headline = 'When it repeats, save it';

  static const body =
      'When something repeats, save one real moment. ArchiveMe compares it later.';

  static const triggerLine = 'The trigger is simple: I noticed this again.';

  static const oneSentenceLine = 'One real sentence is enough.';

  static const notDailyLine =
      'No daily journal. No streak. No dashboard to maintain.';

  static const whyItMattersLine =
      'Saved moments give ArchiveMe evidence to compare later.';

  static const chatDifferenceLine =
      'ChatGPT answers a conversation. ArchiveMe keeps the evidence trail.';

  static const notesDifferenceLine = 'Notes store it. ArchiveMe compares it.';

  static const proLine =
      'Free shows the first useful proof. Pro keeps the longer trail.';

  static const guardrail =
      'Make ArchiveMe a low-pressure place to save a repeat, not a daily habit '
      'tracker, chat app, storage app, or dashboard to maintain.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield triggerLine;
    yield oneSentenceLine;
    yield notDailyLine;
    yield whyItMattersLine;
    yield chatDifferenceLine;
    yield notesDifferenceLine;
    yield proLine;
  }
}
