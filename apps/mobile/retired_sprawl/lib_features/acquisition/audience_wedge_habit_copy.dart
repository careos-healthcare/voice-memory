/// Habit-replacement copy for wedge onboarding — teach save-a-repeat, not UI only.
abstract final class AudienceWedgeHabitCopy {
  AudienceWedgeHabitCopy._();

  static const saveLine =
      'Save the repeat here because Thoughtprint compares it later.';

  static const notesLine =
      'Notes store what happened. Thoughtprint checks what returns.';

  static const chatLine =
      'ChatGPT can suggest what to do. Thoughtprint shows what you already said before.';

  static const broadRepeatFallbackPrompt =
      'When you notice something repeating, save one real moment here.';

  static Iterable<String> allVisibleStrings() sync* {
    yield saveLine;
    yield notesLine;
    yield chatLine;
    yield broadRepeatFallbackPrompt;
  }
}