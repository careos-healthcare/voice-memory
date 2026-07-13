/// Habit-replacement copy for wedge onboarding — teach save-a-repeat, not UI only.
abstract final class AudienceWedgeHabitCopy {
  AudienceWedgeHabitCopy._();

  static const saveLine =
      'When you notice this again, save one real moment here.';

  static const notesLine = 'Notes store it. ArchiveMe compares it.';

  static const chatLine =
      'ChatGPT can help you talk it through. ArchiveMe keeps the trail.';

  static const broadRepeatFallbackPrompt =
      'When you notice something repeating, save one real moment here.';

  static Iterable<String> allVisibleStrings() sync* {
    yield saveLine;
    yield notesLine;
    yield chatLine;
    yield broadRepeatFallbackPrompt;
  }
}
