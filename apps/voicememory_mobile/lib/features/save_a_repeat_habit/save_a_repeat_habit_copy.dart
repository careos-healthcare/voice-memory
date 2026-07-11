/// Save-a-repeat habit copy — low-pressure trigger when something repeats.
abstract final class SaveARepeatHabitCopy {
  SaveARepeatHabitCopy._();

  static const headline = 'When it repeats, save it';

  static const body =
      'ArchiveMe works best when you save one small moment as soon as you notice '
      'something coming back.';

  static const triggerLine = 'The trigger is simple: I noticed this again.';

  static const oneSentenceLine = 'One sentence is enough.';

  static const notDailyLine =
      'No daily journal. No streak. No pressure to record more.';

  static const whyItMattersLine =
      'Saving the repeat gives your archive evidence to compare later.';

  static const chatDifferenceLine =
      'ChatGPT helps you think through now. ArchiveMe preserves the repeat so it '
      'can prove whether it returns or changes.';

  static const notesDifferenceLine =
      'Notes store what you write. ArchiveMe watches whether the same thing comes back.';

  static const proLine =
      'Free can show the first useful proof. Pro keeps the longer trail after the '
      'repeat returns.';

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
