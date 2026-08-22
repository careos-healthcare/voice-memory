/// Prompt state for confirming or renaming a grounded pattern label.
class PatternNamePrompt {
  const PatternNamePrompt({
    required this.patternKey,
    required this.groundedPhrase,
    required this.displayLabel,
  });

  /// Stable key derived from the grounded evidence phrase.
  final String patternKey;

  /// Original grounded phrase from evidence engines — never mutated.
  final String groundedPhrase;

  /// Label shown in the prompt (custom name if set, else grounded phrase).
  final String displayLabel;
}