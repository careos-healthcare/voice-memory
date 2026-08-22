/// Habit-replacement copy for wedge onboarding — teach save-a-repeat, not UI only.
abstract final class AudienceWedgeHabitCopy {
  AudienceWedgeHabitCopy._();

  static const saveLine =
      'Save the repeat here because ArchiveMe compares it later.';

  static const notesLine =
      'Notes store what happened. ArchiveMe checks what returns.';

  static const chatLine =
      'ChatGPT can suggest what to do. ArchiveMe shows what you already said before.';

  static const broadRepeatFallbackPrompt =
      'When you notice something repeating, save one real moment here.';

  static Iterable<String> allVisibleStrings() sync* {
    yield saveLine;
    yield notesLine;
    yield chatLine;
    yield broadRepeatFallbackPrompt;
  }
}