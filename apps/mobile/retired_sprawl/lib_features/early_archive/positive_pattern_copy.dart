/// Copy for the Positive Pattern card — helpful repeats, not generic positivity.
abstract final class PositivePatternCopy {
  PositivePatternCopy._();

  static const title = 'Helpful evidence';

  static const body =
      'Thoughtprint is watching whether this shows up again when the repeat comes back.';

  static const recordAgainCta = 'Record when this helps again';

  static const guidedRecordPrompt = 'What showed up as helpful in your words?';

  static String bodyWithPhrase(String phrase) =>
      'A helpful action appeared: "$phrase". Thoughtprint is watching whether this '
      'shows up again when the repeat comes back.';
}